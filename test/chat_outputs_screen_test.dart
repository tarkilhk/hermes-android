import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/chat_outputs_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/remote_files_client.dart';
import 'package:hermes_android/core/services/android_file_delivery_service.dart';

class _FileDelivery extends AndroidFileDeliveryService {
  final Future<bool> Function(RemoteFileDownload file, String? mimeType) open;
  _FileDelivery(this.open);

  @override
  Future<bool> openInApp(RemoteFileDownload file, {String? mimeType}) =>
      open(file, mimeType);
}

Widget _screen({
  required Future<List<Map<String, dynamic>>> Function() loadHistory,
  required Future<RemoteFileDownload> Function(String path) download,
  required Future<RemoteTextPreview> Function(String path) readText,
  Future<void> Function(RemoteFileDownload)? deliver,
  AndroidFileDeliveryService fileDelivery = const AndroidFileDeliveryService(),
}) => MaterialApp(
  home: ChatOutputsScreen(
    chatTitle: 'Only this chat',
    loadHistory: loadHistory,
    download: download,
    readText: readText,
    deliver: deliver,
    fileDelivery: fileDelivery,
  ),
);

RemoteTextPreview _textPreview(String path) => RemoteTextPreview(
  path: path,
  text: 'void main() {}',
  language: 'dart',
  mimeType: 'text/plain',
  byteSize: 14,
  binary: false,
  truncated: false,
);

void main() {
  testWidgets('PDF open uses original download and keeps save/share fallback', (
    tester,
  ) async {
    RemoteFileDownload? opened;
    String? mime;
    String? path;
    await tester.pumpWidget(
      _screen(
        loadHistory: () async => [
          {'role': 'assistant', 'content': 'Saved /srv/current/report.pdf'},
        ],
        readText: (path) async => RemoteTextPreview(
          path: path,
          text: '',
          language: '',
          mimeType: 'application/pdf',
          byteSize: 4,
          binary: true,
          truncated: false,
        ),
        download: (value) async {
          path = value;
          return RemoteFileDownload(
            filename: 'actual.pdf',
            bytes: [37, 80, 68, 70],
          );
        },
        fileDelivery: _FileDelivery((file, type) async {
          opened = file;
          mime = type;
          return false;
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('report.pdf'));
    await tester.pumpAndSettle();
    expect(opened, isNull);
    await tester.tap(find.text('Open in app'));
    await tester.pumpAndSettle();
    expect(path, '/srv/current/report.pdf');
    expect(opened?.filename, 'actual.pdf');
    expect(opened?.bytes, [37, 80, 68, 70]);
    expect(mime, 'application/pdf');
    expect(
      find.text('No compatible app was found. Use Save or share instead.'),
      findsOneWidget,
    );
    expect(find.text('Save or share'), findsOneWidget);
  });

  testWidgets('closing preview during download prevents a late app launch', (
    tester,
  ) async {
    final pending = Completer<RemoteFileDownload>();
    var opened = false;
    await tester.pumpWidget(
      _screen(
        loadHistory: () async => [
          {'role': 'assistant', 'content': 'Saved /srv/current/report.pdf'},
        ],
        readText: (path) async => RemoteTextPreview(
          path: path,
          text: '',
          language: '',
          mimeType: 'application/pdf',
          byteSize: 4,
          binary: true,
          truncated: false,
        ),
        download: (_) => pending.future,
        fileDelivery: _FileDelivery((_, _) async {
          opened = true;
          return true;
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('report.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open in app'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Open in app'),
          )
          .onPressed,
      isNull,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    pending.complete(
      RemoteFileDownload(filename: 'report.pdf', bytes: [37, 80, 68, 70]),
    );
    await tester.pumpAndSettle();
    expect(opened, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows supplied chat outputs and previews the original path', (
    tester,
  ) async {
    String? readPath;
    await tester.pumpWidget(
      _screen(
        loadHistory: () async => [
          {'role': 'assistant', 'content': 'Saved /srv/current/notes.md'},
          {
            'role': 'user',
            'content': 'Another chat mentioned /srv/other/report.pdf',
          },
        ],
        download: (_) async => throw StateError('Unexpected download'),
        readText: (path) async {
          readPath = path;
          return _textPreview(path);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('notes.md'), findsOneWidget);
    expect(find.text('report.pdf'), findsNothing);

    await tester.tap(find.text('notes.md'));
    await tester.pumpAndSettle();

    expect(readPath, '/srv/current/notes.md');
    expect(
      tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((widget) => widget.data),
      contains('void main() {}'),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Outputs · Only this chat'), findsOneWidget);
    expect(find.text('notes.md'), findsOneWidget);
  });

  testWidgets('delivers the downloaded filename and exact bytes', (
    tester,
  ) async {
    String? downloadPath;
    RemoteFileDownload? delivered;
    await tester.pumpWidget(
      _screen(
        loadHistory: () async => [
          {'role': 'assistant', 'content': 'Saved /srv/current/report.pdf'},
        ],
        download: (path) async {
          downloadPath = path;
          return RemoteFileDownload(
            filename: 'server-report.pdf',
            bytes: [0, 1, 127, 255],
          );
        },
        readText: (_) async => throw StateError('Unexpected preview'),
        deliver: (download) async => delivered = download,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save or share report.pdf'));
    await tester.pumpAndSettle();

    expect(downloadPath, '/srv/current/report.pdf');
    expect(delivered?.filename, 'server-report.pdf');
    expect(delivered?.bytes, orderedEquals([0, 1, 127, 255]));
  });

  testWidgets('shows loading, empty, and failure states', (tester) async {
    final firstLoad = Completer<List<Map<String, dynamic>>>();
    final failedRefresh = Completer<List<Map<String, dynamic>>>();
    var loads = 0;
    await tester.pumpWidget(
      _screen(
        loadHistory: () {
          loads++;
          if (loads == 1) return firstLoad.future;
          if (loads == 2) return failedRefresh.future;
          return Future.value([]);
        },
        download: (_) async => throw StateError('Unexpected download'),
        readText: (_) async => throw StateError('Unexpected preview'),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    firstLoad.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No files or links found in this chat.'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh outputs'));
    await tester.pump();
    failedRefresh.completeError(StateError('Profile unavailable.'));
    await tester.pumpAndSettle();
    expect(find.text('Profile unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No files or links found in this chat.'), findsOneWidget);
    expect(loads, 3);
  });

  testWidgets('reports the 32 MiB limit on a narrow 200 percent layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ChatOutputsScreen(
            chatTitle: 'Only this chat',
            loadHistory: () async => [
              {
                'role': 'assistant',
                'content': 'Saved /srv/current/very-long-report-name.pdf',
              },
            ],
            download: (_) async =>
                throw const DashboardResponseTooLargeException(
                  32 * 1024 * 1024,
                ),
            readText: (_) async => throw StateError('Unexpected preview'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Save or share very-long-report-name.pdf'));
    await tester.pumpAndSettle();

    expect(
      find.text('This file exceeds the 32 MiB download limit.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
