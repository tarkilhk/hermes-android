import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/widgets/profile_goal_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_connection_identity_test.dart' show identityTestConnection;
import 'support/profile_actions_fixture.dart';

class _GoalFixture extends ProfileActionsFixture {
  final requests = <(String, Map<String, dynamic>)>[];
  bool hasGoal = true;

  Map<String, dynamic> get control => {
    'goal': hasGoal
        ? {
            'title': 'Ship the release',
            'status': 'active',
            'turns_used': 2,
            'max_turns': 8,
            'contract': {
              'outcome': 'A useful release',
              'verification': 'Run checks',
              'constraints': 'Keep scope small',
              'boundaries': 'No unrelated edits',
              'stop_when': 'Checks pass',
            },
            'subgoals': ['Implement', 'Verify'],
            'gates': const [],
          }
        : null,
    'revision': 'goal-revision',
    'updated_at': 1,
  };

  @override
  ProfileGateway gateway(WorkspaceScope scope) {
    final base = super.gateway(scope);
    return ProfileGateway(
      scope: scope,
      discover: base.discover,
      get: base.read,
      rpc: (method, params) async {
        requests.add((method, params));
        if (method == 'session.control.read') return {'control': control};
        if (method == 'session.control') {
          return {
            'control': control,
            'dispatch': {
              'type': 'exec',
              'output': '✓ Goal updated.',
              'notice': null,
              'message': null,
              'display': null,
            },
          };
        }
        return base.call(method, params);
      },
    );
  }
}

void main() {
  late _GoalFixture fixture;
  late ProfileWorkspaceController controller;
  late ProfileChat chat;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = _GoalFixture();
    controller = ProfileWorkspaceController(
      connection: identityTestConnection(),
      connectionIdentity: 'goal-panel',
      preferences: await SharedPreferences.getInstance(),
      gatewayFactory: fixture.gateway,
    );
    await controller.initialize();
    chat = await controller.createChat();
  });

  tearDown(() => controller.dispose());

  Future<void> showPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ProfileGoalPanel(
                controller: controller,
                chat: chat,
                initiallyExpanded: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders server goal details and sends pause action', (
    tester,
  ) async {
    await showPanel(tester);

    expect(find.text('Ship the release'), findsOneWidget);
    expect(find.text('Verification: Run checks'), findsOneWidget);
    expect(find.text('1. Implement'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(
      fixture.requests.any(
        (request) =>
            request.$1 == 'session.control' &&
            request.$2['action'] == 'goal.pause',
      ),
      isTrue,
    );
  });

  testWidgets('renders an explicit empty server goal state', (tester) async {
    fixture.hasGoal = false;
    await showPanel(tester);
    expect(
      find.text('Hermes has no active goal for this chat.'),
      findsOneWidget,
    );
  });

  testWidgets('chat menu opens server goal details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfileWorkspaceScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goal').last);
    await tester.pumpAndSettle();
    expect(find.text('Ship the release'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('keeps goal actions usable on a narrow large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            children: [
              ProfileGoalPanel(
                controller: controller,
                chat: chat,
                initiallyExpanded: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Refresh'));
    await tester.pumpAndSettle();
    final reads = fixture.requests
        .where((r) => r.$1 == 'session.control.read')
        .length;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(
      fixture.requests.where((r) => r.$1 == 'session.control.read').length,
      reads + 1,
    );
    expect(tester.takeException(), isNull);
  });
}
