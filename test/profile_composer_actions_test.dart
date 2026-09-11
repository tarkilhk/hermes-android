import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'profile_connection_identity_test.dart' show identityTestConnection;
import 'support/profile_actions_fixture.dart';

class _ComposerActionsFixture extends ProfileActionsFixture {
  Map<String, dynamic> steerResult = {'status': 'queued'};

  @override
  ProfileGateway gateway(WorkspaceScope scope) {
    final base = super.gateway(scope);
    return ProfileGateway(
      scope: scope,
      discover: base.discover,
      get: base.read,
      rpc: (method, params) => method == 'session.steer'
          ? Future.value(steerResult)
          : base.call(method, params),
    );
  }
}

void main() {
  late _ComposerActionsFixture fixture;
  late ProfileWorkspaceController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = _ComposerActionsFixture();
    controller = ProfileWorkspaceController(
      connection: identityTestConnection(),
      connectionIdentity: 'composer-actions',
      preferences: await SharedPreferences.getInstance(),
      gatewayFactory: fixture.gateway,
    );
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  Future<void> pumpFrames(WidgetTester tester, {int count = 8}) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProfileChat> show(
    WidgetTester tester, {
    double scale = 1,
    ProfileTurnStatus status = ProfileTurnStatus.idle,
    String draft = '',
    List<String> queued = const [],
    bool paused = false,
  }) async {
    final chat = await controller.createChat();
    chat.status = status;
    chat.draft = draft;
    chat.queuedPrompts.addAll(queued);
    chat.queuePaused = paused;
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ProfileWorkspaceScreen(controller: controller),
      ),
    );
    await pumpFrames(tester);
    return chat;
  }

  testWidgets('normal tap remains Stop when the turn is busy', (tester) async {
    await show(tester, status: ProfileTurnStatus.running);
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(fixture.calls.any((call) => call.$2 == 'session.interrupt'), isTrue);
    expect(find.text('Queue for the next turn'), findsNothing);
  });

  testWidgets('Message actions queues the draft and clears the composer', (
    tester,
  ) async {
    final chat = await show(
      tester,
      status: ProfileTurnStatus.running,
      draft: 'follow up after this turn',
    );
    await tester.tap(find.byTooltip('Message actions'));
    await pumpFrames(tester, count: 4);
    await tester.tap(find.text('Queue for the next turn'));
    await pumpFrames(tester, count: 4);
    expect(chat.queuedPrompts, ['follow up after this turn']);
    expect(chat.draft, isEmpty);
  });

  testWidgets(
    'queue count opens while idle with an empty composer and removes',
    (tester) async {
      final chat = await show(
        tester,
        queued: ['review this queued item'],
        paused: true,
      );
      await tester.tap(find.byTooltip('Message actions'));
      await pumpFrames(tester, count: 4);
      expect(find.text('Queued messages are paused'), findsOneWidget);
      expect(
        find.text('Remove queued: review this queued item'),
        findsOneWidget,
      );
      await tester.tap(find.text('Remove queued: review this queued item'));
      await tester.pumpAndSettle();
      expect(chat.queuedPrompts, isEmpty);
    },
  );

  testWidgets('rejected steer leaves the typed draft intact', (tester) async {
    fixture.steerResult = {'status': 'rejected'};
    final chat = await show(
      tester,
      status: ProfileTurnStatus.running,
      draft: 'keep this if Hermes rejects it',
    );
    await tester.tap(find.byTooltip('Message actions'));
    await pumpFrames(tester, count: 4);
    await tester.tap(find.text('Steer this turn'));
    await pumpFrames(tester, count: 4);
    expect(chat.draft, 'keep this if Hermes rejects it');
  });

  testWidgets('large text scale keeps the actions sheet bounded', (
    tester,
  ) async {
    await show(tester, scale: 2.4, queued: ['first', 'second', 'third']);
    await tester.tap(find.byTooltip('Message actions'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Remove queued: first'), findsOneWidget);
  });
}
