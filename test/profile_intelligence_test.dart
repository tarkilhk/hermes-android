import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/widgets/chat_intelligence_picker.dart';
import 'profile_connection_identity_test.dart' show identityTestConnection;
import 'support/profile_intelligence_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileIntelligenceFixture host;
  late ProfileWorkspaceController controller;
  late SharedPreferences prefs;
  Future<ProfileWorkspaceController> open() async {
    final c = ProfileWorkspaceController(
      connection: identityTestConnection(),
      connectionIdentity: 'picker-test',
      preferences: prefs,
      gatewayFactory: host.gateway,
    );
    await c.initialize();
    await c.createChat();
    return c;
  }

  const selection = ChatIntelligenceSelection(
    choice: ChatModelChoice(provider: 'openai-codex', model: 'gpt-5.6-sol'),
    reasoningEffort: 'xhigh',
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    host = ProfileIntelligenceFixture();
    controller = await open();
  });
  tearDown(() => controller.dispose());

  test(
    'selection is session scoped, persisted and restored before sending',
    () async {
      final chat = controller.current!.chat!;
      await controller.loadIntelligence(chat);
      await controller.setIntelligence(chat, selection);
      expect(host.writes, hasLength(2));
      expect(
        host.writes.first['value'],
        'gpt-5.6-sol --provider openai-codex --session',
      );
      expect(
        host.writes.every(
          (p) => p['profile'] == 'personal' && p['session_id'] == 'runtime',
        ),
        isTrue,
      );
      final reopened = await open();
      addTearDown(reopened.dispose);
      final restored = reopened.current!.chat!;
      expect(restored.model, 'gpt-5.6-sol');
      expect(restored.reasoningEffort, 'xhigh');
      restored.draft = 'Verify settings';
      await reopened.send(restored);
      expect(host.writes, hasLength(4));
      await reopened.switchProfile('work');
      final other = await reopened.createChat();
      expect(other.model, 'gpt-6-astra');
      expect(other.reasoningEffort, 'high');
    },
  );

  test(
    'confirmation and partial failure never report the requested effort as applied',
    () async {
      final chat = controller.current!.chat!;
      host.confirmModel = true;
      await expectLater(
        controller.setIntelligence(chat, selection),
        throwsStateError,
      );
      expect(chat.model, 'gpt-6-astra');
      expect(chat.changingIntelligence, isFalse);
      host.confirmModel = false;
      host.failReasoning = true;
      await expectLater(
        controller.setIntelligence(chat, selection),
        throwsStateError,
      );
      expect(chat.model, 'gpt-5.6-sol');
      expect(chat.reasoningEffort, 'high');
      expect(chat.changingIntelligence, isFalse);
    },
  );

  testWidgets(
    'the shipped profile composer opens picker and applies both choices',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: ProfileWorkspaceScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-intelligence-button')));
      await tester.pumpAndSettle();
      expect(find.text('Intelligence'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('choose-chat-model')));
      await tester.tap(find.byKey(const Key('choose-chat-model')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('model-search')), 'sol');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('model-openai-codex-gpt-5.6-sol')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('reasoning-xhigh')));
      await tester.tap(find.byKey(const Key('reasoning-xhigh')));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('5.6 Sol Extra High'), findsOneWidget);
      expect(host.writes, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
