import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/widgets/profile_chat_indicator.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'profile_connection_identity_test.dart' show identityTestConnection;
import 'support/profile_actions_fixture.dart';

void main() {
  late ProfileActionsFixture host;
  late ProfileWorkspaceController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    host = ProfileActionsFixture();
    controller = ProfileWorkspaceController(
      connection: identityTestConnection(),
      connectionIdentity: 'actions',
      preferences: await SharedPreferences.getInstance(),
      gatewayFactory: host.gateway,
    );
    await controller.initialize();
  });
  tearDown(() => controller.dispose());
  ProfileSessionKey key([String id = 'newest']) =>
      ProfileSessionKey(controller.current!.scope, id);
  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: hermesTheme(Brightness.light),
        home: ProfileWorkspaceScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String id) async {
    final row = find.byKey(ValueKey('chat-$id'));
    await tester.scrollUntilVisible(
      row,
      240,
      scrollable: find
          .descendant(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget is ListView && widget.scrollDirection == Axis.vertical,
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.45);
    await tester.pumpAndSettle();
    await tester.longPress(row);
    await tester.pumpAndSettle();
  }

  test(
    'pin rename unread use body profile and update only owner rows',
    () async {
      final owner = key();
      await controller.mutateSession(owner, changes: {'pinned': true});
      await controller.mutateSession(
        owner,
        changes: {'title': 'Renamed', 'unread': true},
      );
      expect(host.updates.last.$3['profile'], 'personal');
      expect(
        controller.current!.sessions.firstWhere(
          (r) => r['id'] == 'newest',
        )['title'],
        'Renamed',
      );
      await controller.navigateProfile('work');
      expect(controller.current!.sessions.single['title'], 'Work chat');
      await expectLater(
        controller.mutateSession(owner, changes: {'pinned': false}),
        throwsStateError,
      );
    },
  );
  test('failed writes preserve visible data and allow retry', () async {
    host.failMutation = true;
    await expectLater(
      controller.mutateSession(key(), changes: {'pinned': true}),
      throwsStateError,
    );
    expect(
      controller.current!.sessions.firstWhere(
        (r) => r['id'] == 'newest',
      )['pinned'],
      isNot(true),
    );
    expect(controller.current!.mutatingSessions, isEmpty);
    host.failMutation = false;
    await controller.mutateSession(key(), changes: {'pinned': true});
    expect(
      controller.current!.sessions.firstWhere(
        (r) => r['id'] == 'newest',
      )['pinned'],
      true,
    );
  });
  test('archive and unarchive are discoverable and survive refresh', () async {
    await controller.mutateSession(key(), changes: {'archived': true});
    expect(controller.current!.sessions.any((r) => r['id'] == 'newest'), false);
    await controller.showArchived(true);
    expect(controller.current!.sessions.single['id'], 'newest');
    await controller.mutateSession(key(), changes: {'archived': false});
    expect(controller.current!.sessions, isEmpty);
    await controller.showArchived(false);
    expect(controller.current!.sessions.any((r) => r['id'] == 'newest'), true);
  });
  test('refresh started during a write cannot restore stale flags', () async {
    host.mutationDelay = Completer<void>();
    final write = controller.mutateSession(key(), changes: {'pinned': true});
    final delay = host.pageDelays[('personal', 0)] = Completer<void>();
    final readCount = host.reads.length;
    final refresh = controller.refresh();
    while (host.reads.length == readCount) {
      await Future<void>.delayed(Duration.zero);
    }
    host.mutationDelay!.complete();
    await write;
    delay.complete();
    await refresh;
    expect(
      controller.current!.sessions.firstWhere(
        (r) => r['id'] == 'newest',
      )['pinned'],
      true,
    );
  });
  test('delete uses profile query and refuses an active durable ID', () async {
    host.active = true;
    await expectLater(
      controller.mutateSession(key(), delete: true),
      throwsStateError,
    );
    expect(host.deletes, isEmpty);
    host.active = false;
    await controller.mutateSession(key(), delete: true);
    expect(host.deletes.single.$2, {'profile': 'personal'});
    expect(controller.current!.sessions.any((r) => r['id'] == 'newest'), false);
    await controller.refresh();
    expect(controller.current!.sessions.any((r) => r['id'] == 'newest'), false);
  });
  test(
    'late write and duplicate taps stay bound to the original profile',
    () async {
      host.mutationDelay = Completer<void>();
      final personal = controller.current!;
      final owner = key();
      final pending = controller.mutateSession(
        owner,
        changes: {'pinned': true},
      );
      await controller.mutateSession(owner, changes: {'pinned': true});
      await controller.navigateProfile('work');
      host.mutationDelay!.complete();
      await pending;
      expect(host.updates.length, 1);
      expect(
        personal.sessions.firstWhere((r) => r['id'] == 'newest')['pinned'],
        true,
      );
      expect(controller.current!.sessions.single['pinned'], isNot(true));
    },
  );
  test(
    'project new chat captures its folder and rejects a stale owner',
    () async {
      final owner = controller.current!.scope;
      final project = controller.current!.projects.first;
      final chat = await controller.createChat(
        inProject: project,
        owner: owner,
      );
      expect(chat.projectId, project['id']);
      expect(host.calls.last.$3['cwd'], project['primary_path']);
      await controller.navigateProfile('work');
      await expectLater(
        controller.createChat(inProject: project, owner: owner),
        throwsStateError,
      );
    },
  );
  testWidgets('long press offers pin and moves the chat to pinned', (
    tester,
  ) async {
    await show(tester);
    await menu(tester, 'newest');
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(host.updates.single.$3['pinned'], true);
    await menu(tester, 'newest');
    expect(find.text('Unpin'), findsOneWidget);
    await tester.tap(find.text('Unpin'));
    await tester.pumpAndSettle();
    expect(host.updates.last.$3['pinned'], false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('delete confirmation cancel sends no request', (tester) async {
    await show(tester);
    await menu(tester, 'newest');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete chat?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(host.deletes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('project long press opens a new chat in that project', (
    tester,
  ) async {
    await show(tester);
    await tester.longPress(find.byKey(const ValueKey('project-p2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New chat in project'));
    await tester.pumpAndSettle();
    expect(controller.current!.chat!.projectId, 'p2');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'status indicators distinguish runtime, unread and heuristic activity',
    (tester) async {
      final chat = await controller.createChat();
      for (final (status, label) in [
        (ProfileTurnStatus.running, 'Working'),
        (ProfileTurnStatus.attention, 'Input needed'),
        (ProfileTurnStatus.completed, 'Completed'),
        (ProfileTurnStatus.failed, 'Failed'),
      ]) {
        chat.status = status;
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileChatIndicator(chat: chat, row: const {}),
          ),
        );
        await tester.pump();
        expect(find.byTooltip(label), findsOneWidget);
      }
      await tester.pumpWidget(
        const MaterialApp(home: ProfileChatIndicator(row: {'unread': true})),
      );
      expect(find.byTooltip('Unread'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(home: ProfileChatIndicator(row: {'is_active': true})),
      );
      expect(find.byTooltip('Recent activity'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
