import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/screens/profile_transcript.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'profile_connection_identity_test.dart' show identityTestConnection;
import 'support/profile_history_fixture.dart';

void main() {
  late ProfileWorkspaceController controller;
  late ProfileHistoryFixture host;
  late ProfileChat chat;
  var tailHeight = 0.0;
  var reducedMotion = false;
  final list = find.byKey(const ValueKey('profile-transcript'));
  final jump = find.byKey(const ValueKey('jump-to-latest'));

  Map<String, dynamic> row(int id) => {
    'id': id,
    'role': 'assistant',
    'content': 'Message $id',
  };
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    host = ProfileHistoryFixture();
    controller = ProfileWorkspaceController(
      connection: identityTestConnection(),
      connectionIdentity: 'transcript-test',
      preferences: await SharedPreferences.getInstance(),
      gatewayFactory: host.gateway,
    );
    await controller.initialize();
    chat = ProfileChat(
      key: ProfileSessionKey(controller.current!.scope, 'chat-0'),
      runtimeId: '',
      title: 'Read-only test',
    );
    controller.current!.chats['chat-0'] = chat;
    controller.current!.selectedSession = 'chat-0';
    await controller.refreshHistory(chat);
    tailHeight = 0;
    reducedMotion = false;
  });
  tearDown(() => controller.dispose());

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, _) => ProfileTranscript(
              key: ValueKey(chat.key),
              chat: chat,
              controller: controller,
              messageBuilder: (m) => SizedBox(
                key: ValueKey('body-${m['id']}'),
                height: 60 + (m['id'] as int) % 3 * 20,
                child: Text(m['content'].toString()),
              ),
              tail: [if (tailHeight > 0) SizedBox(height: tailHeight)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> publish(WidgetTester tester) async {
    controller.clearSearch();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Finder visibleRow(WidgetTester tester) {
    return find.byWidgetPredicate((w) {
      if (w.key is! ValueKey<String> ||
          !(w.key as ValueKey<String>).value.startsWith('body-')) {
        return false;
      }
      final y = tester.getTopLeft(find.byWidget(w)).dy;
      return y > 150 && y < 400;
    }).first;
  }

  testWidgets(
    '2500 variable-height rows stay lazy; older pages do not signal new activity',
    (tester) async {
      chat.messages = List.generate(2500, (i) => row(i + 100));
      chat.nextHistoryOffset = null;
      await show(tester);
      expect(find.byType(Text).evaluate().length, lessThan(35));
      await tester.drag(list, const Offset(0, 440));
      await tester.pumpAndSettle();
      final anchor = tester.widget(visibleRow(tester)).key!;
      final before = tester.getTopLeft(find.byKey(anchor)).dy;
      chat.messages = [...List.generate(100, row), ...chat.messages];
      await publish(tester);
      expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(before, 1));
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('New activity'), findsNothing);
      expect(find.byType(Text).evaluate().length, lessThan(35));
    },
  );

  testWidgets(
    'a tall new streaming tail preserves the reader and marks new activity',
    (tester) async {
      await show(tester);
      await tester.drag(list, const Offset(0, 480));
      await tester.pumpAndSettle();
      final anchor = tester.widget(visibleRow(tester)).key!;
      final before = tester.getTopLeft(find.byKey(anchor)).dy;
      tailHeight = 1800;
      chat.streaming = 'New streaming output';
      await publish(tester);
      expect(find.byKey(anchor), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(before, 2));
      expect(find.text('New activity'), findsOneWidget);
      await tester.tap(jump);
      await tester.pumpAndSettle();
      expect(chat.historyScrollOffset, closeTo(0, 1));
      expect(jump, findsNothing);
      chat.streaming = 'More streaming output';
      tailHeight = 2000;
      await publish(tester);
      expect(chat.historyScrollOffset, closeTo(0, 1));
      expect(jump, findsNothing);
    },
  );

  testWidgets(
    'new durable messages keep reading position, and reduced-motion Latest clears the badge',
    (tester) async {
      reducedMotion = true;
      await show(tester);
      await tester.drag(list, const Offset(0, 450));
      await tester.pumpAndSettle();
      final anchor = tester.widget(visibleRow(tester)).key!;
      final before = tester.getTopLeft(find.byKey(anchor)).dy;
      chat.messages.add(row(621));
      await publish(tester);
      expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(before, 2));
      expect(find.text('New activity'), findsOneWidget);
      await tester.tap(jump);
      await tester.pumpAndSettle();
      expect(chat.historyScrollOffset, 0);
      expect(jump, findsNothing);
      expect(chat.messages.last['id'], 621);
    },
  );

  testWidgets('an expanded tool group survives older and newer additions', (
    tester,
  ) async {
    Map<String, dynamic> tool(int id) => {
      'id': id,
      'role': 'tool',
      'tool_name': 'Tool $id',
      'content': 'Output $id',
    };
    chat.messages = [tool(1), tool(2), row(3)];
    chat.nextHistoryOffset = null;
    await show(tester);
    await tester.tap(find.text('2 tool results'));
    await tester.pumpAndSettle();
    expect(find.text('Output 1'), findsOneWidget);
    chat.messages.insert(0, tool(0));
    await publish(tester);
    expect(find.text('Output 1'), findsOneWidget);
    chat.messages.insert(3, tool(4));
    await publish(tester);
    expect(find.text('Output 1'), findsOneWidget);
    expect(find.text('Output 4'), findsOneWidget);
  });

  testWidgets(
    'input requests are discoverable while reading without automatically approving',
    (tester) async {
      await show(tester);
      await tester.drag(list, const Offset(0, 450));
      await tester.pumpAndSettle();
      chat.approval = {'command': 'test command'};
      await publish(tester);
      expect(find.text('Input needed'), findsOneWidget);
      final before = host.calls.length;
      await tester.tap(jump);
      await tester.pumpAndSettle();
      expect(chat.historyScrollOffset, 0);
      expect(chat.approval, isNotNull);
      expect(host.calls.length, before);
    },
  );

  testWidgets(
    'an older-page failure retains messages and only retries on request',
    (tester) async {
      await show(tester);
      host.failHistory = true;
      final scroll = tester.widget<ListView>(list).controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(chat.historyError, isNotNull);
      expect(chat.messages.length, 50);
      final reads = host.reads.length;
      await tester.pump(const Duration(seconds: 2));
      expect(host.reads.length, reads);
      host.failHistory = false;
      await tester.ensureVisible(find.text('Retry older messages'));
      await tester.tap(find.text('Retry older messages'));
      await tester.pumpAndSettle();
      expect(chat.historyError, isNull);
      expect(chat.messages.length, greaterThanOrEqualTo(100));
      expect(tester.takeException(), isNull);
    },
  );
}
