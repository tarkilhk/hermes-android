import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/chat_outputs_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/remote_files_client.dart';

Widget _screen({
  required Future<List<Map<String, dynamic>>> Function() loadHistory,
  required Future<RemoteFileDownload> Function(String path) download,
  required Future<RemoteTextPreview> Function(String path) readText,
  Future<void> Function(RemoteFileDownload)? deliver,
}) => MaterialApp(
  home: ChatOutputsScreen(
    chatTitle: 'Only this chat',
    loadHistory: loadHistory,
    download: download,
    readText: readText,
    deliver: deliver,
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
