import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_connection_identity.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/services/profile_workspace_registry.dart';
import 'package:hermes_android/core/services/text_size_preference.dart';
import 'package:hermes_android/core/widgets/app_drawer.dart';
import 'package:hermes_android/main.dart';

import 'support/roadmap_emulator_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _RoadmapHarness harness;

  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Hermes Personal',
      packageName: 'com.tarkilhk.hermes.android',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
    harness = await _RoadmapHarness.create();
  });

  tearDown(() => harness.dispose());

  testWidgets(
    'drawer settings profiles chats and projects work at large text',
    (tester) async {
      await harness.launch(tester);

      expect(find.byType(ProfileWorkspaceScreen), findsOneWidget);
      expect(find.text('personal chat 0'), findsOneWidget);
      expect(find.text('personal project'), findsOneWidget);

      await _navigate(tester, AppDestination.settings);
      await tester.scrollUntilVisible(
        find.text('Theme'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Theme'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Text size'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Text size'));
      await _settle(tester);
      await tester.tap(find.text('Extra large'));
      await _settle(tester);
      expect(
        harness.preferences.getString(TextSizePreference.preferenceKey),
        TextSizePreference.extraLarge.storageValue,
      );

      await _navigate(tester, AppDestination.chats);
      await tester.tap(find.byKey(const ValueKey('profile-work')));
      await _pumpUntil(
        tester,
        () => harness.controller.current?.scope.profileName == 'work',
      );
      expect(find.text('work project'), findsOneWidget);
      expect(find.text('work chat 0'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('project-shared-project')));
      await _settle(tester);
      expect(find.text('work project'), findsWidgets);
      expect(find.text('work chat 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'draft model slash find outputs and context use the production chat',
    (tester) async {
      await harness.launch(tester);
      await tester.tap(find.byKey(const ValueKey('chat-chat-0')));
      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('profile-message-composer'))
            .evaluate()
            .isNotEmpty,
      );
      final chat = harness.controller.current!.chat!;

      expect(find.text('personal message 620'), findsOneWidget);
      expect(
        find.bySemanticsLabel('32768 of 131072 tokens, 25 percent used'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('profile-message-composer')),
        'Draft survives chat navigation',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Back to sessions'));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('chat-chat-0')));
      await _settle(tester);
      expect(find.text('Draft survives chat navigation'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-intelligence-button')));
      await _settle(tester);
      await tester.ensureVisible(find.byKey(const Key('choose-chat-model')));
      await tester.tap(find.byKey(const Key('choose-chat-model')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('model-search')), 'sol');
      await _settle(tester);
      await tester.tap(find.byKey(const Key('model-openai-codex-gpt-5.6-sol')));
      await _settle(tester);
      await tester.ensureVisible(find.byKey(const Key('reasoning-xhigh')));
      await tester.tap(find.byKey(const Key('reasoning-xhigh')));
      await tester.tap(find.text('Apply'));
      await _settle(tester);
      expect(find.text('5.6 Sol Extra High'), findsOneWidget);
      expect(harness.fixture.configWrites, hasLength(2));

      await tester.enterText(
        find.byKey(const Key('profile-message-composer')),
        '/road',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);
      await tester.tap(find.text('/roadmap-check'));
      await tester.tap(find.byTooltip('Send'));
      await _pumpUntil(
        tester,
        () =>
            find.text('Roadmap fixture command complete').evaluate().isNotEmpty,
      );
      expect(harness.fixture.commandDispatches.single['name'], 'roadmap-check');

      await tester.tap(find.byTooltip('Chat actions'));
      await _settle(tester);
      await tester.tap(find.text('Find in chat'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, 'roadmap needle');
      await tester.pump();
      expect(
        find.text('1 matching message in loaded messages'),
        findsOneWidget,
      );
      await tester.tap(
        find.text('Roadmap needle: the emulator found this saved answer.').last,
      );
      await _settle(tester);
      await tester.tap(find.text('View in chat'));
      await _settle(tester);
      expect(
        find.text('Roadmap needle: the emulator found this saved answer.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Chat actions'));
      await _settle(tester);
      await tester.tap(find.text('Outputs'));
      await _settle(tester);
      expect(find.text('roadmap-notes.md'), findsOneWidget);
      expect(find.textContaining('Outputs ·'), findsOneWidget);
      expect(chat.key.sessionId, 'chat-0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('activity approvals and queued work keep their chat owner', (
    tester,
  ) async {
    await harness.launch(tester);
    await tester.tap(find.byKey(const ValueKey('chat-chat-1')));
    await _settle(tester);
    final chat = harness.controller.current!.chat!;

    chat.status = ProfileTurnStatus.running;
    harness.controller.clearSearch();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('profile-message-composer')),
      'Queue this after the synthetic turn',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Message actions'));
    await _settle(tester);
    await tester.tap(find.text('Queue for the next turn'));
    await _settle(tester);
    expect(
      chat.queuedPrompts.single.text,
      'Queue this after the synthetic turn',
    );
    expect(find.byTooltip('Message actions'), findsOneWidget);

    harness.fixture.requestApproval('personal', chat.runtimeId);
    await tester.pump();
    expect(find.text('Approval needed'), findsWidgets);
    expect(find.text('echo isolated-roadmap-check'), findsOneWidget);
    await tester.tap(find.text('Allow once'));
    await _settle(tester);
    expect(
      harness.fixture.approvalResponses.single,
      containsPair('choice', 'once'),
    );
    expect(find.text('Approval needed'), findsNothing);

    harness.fixture.liveSessions['personal'] = [
      {
        'id': 'runtime-running',
        'session_key': 'chat-0',
        'status': 'working',
        'last_active': 2,
      },
      {
        'id': 'runtime-input',
        'session_key': 'chat-1',
        'status': 'waiting',
        'last_active': 1,
      },
    ];
    await _navigate(tester, AppDestination.activity);
    await _pumpUntil(
      tester,
      () => find.text('personal chat 0').evaluate().isNotEmpty,
    );
    expect(find.text('personal chat 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Needs input'));
    await tester.pump();
    expect(find.text('personal chat 0'), findsNothing);
    expect(find.text('personal chat 1'), findsOneWidget);
    await tester.tap(find.text('personal chat 1'));
    await _settle(tester);
    expect(harness.controller.current!.chat, same(chat));
    expect(chat.queuedPrompts, isEmpty);
    final queuedSubmit = harness.fixture.calls.singleWhere(
      (call) => call.$2 == 'prompt.submit',
    );
    expect(queuedSubmit.$1, 'personal');
    expect(queuedSubmit.$3['text'], 'Queue this after the synthetic turn');
    expect(tester.takeException(), isNull);
  });
}

class _RoadmapHarness {
  final SharedPreferences preferences;
  final ConnectionManager connectionManager;
  final RoadmapEmulatorFixture fixture;
  final ProfileWorkspaceRegistry registry;
  late ProfileWorkspaceController controller;

  _RoadmapHarness({
    required this.preferences,
    required this.connectionManager,
    required this.fixture,
    required this.registry,
  });

  static Future<_RoadmapHarness> create() async {
    final preferences = await SharedPreferences.getInstance();
    final credentialStore = RoadmapMemoryCredentialStore();
    final connectionManager = await ConnectionManager.create(
      preferences,
      credentialStore: credentialStore,
    );
    final connection = SavedConnection(
      id: 'roadmap-emulator',
      label: 'Roadmap fixture',
      host: 'unused.invalid',
      port: 1,
      apiKey: '',
    );
    await connectionManager.importConnections([
      connection,
    ], replaceExisting: true);
    await preferences.setString('last_connection_id', connection.id);
    final fixture = RoadmapEmulatorFixture();
    final registry = ProfileWorkspaceRegistry(
      identities: ProfileConnectionIdentity(credentialStore: credentialStore),
      create: (saved, identity) => ProfileWorkspaceController(
        connection: saved,
        connectionIdentity: identity,
        preferences: preferences,
        gatewayFactory: fixture.gateway,
      ),
    );
    final harness = _RoadmapHarness(
      preferences: preferences,
      connectionManager: connectionManager,
      fixture: fixture,
      registry: registry,
    );
    harness.controller = await registry.forConnection(connection);
    return harness;
  }

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(
      HermesApp(connManager: connectionManager, profileControllers: registry),
    );
    await _pumpUntil(
      tester,
      () => find.byType(ProfileWorkspaceScreen).evaluate().isNotEmpty,
    );
    await _pumpUntil(
      tester,
      () => controller.current != null && !controller.switching,
    );
    await _settle(tester);
  }

  void dispose() => registry.dispose();
}

Future<void> _navigate(WidgetTester tester, AppDestination destination) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await _settle(tester);
  final item = find.byKey(ValueKey('nav-${destination.name}'));
  await tester.ensureVisible(item);
  await tester.tap(item);
  await _settle(tester);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
