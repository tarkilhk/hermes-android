import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/answer_versions.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/services/profiles_repository.dart';
import 'package:hermes_android/core/services/ws_client.dart';
import 'package:hermes_android/core/widgets/answer_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnswerHost {
  final gateways = <String, ProfileGateway>{};
  final histories = <String, List<Map<String, dynamic>>>{};
  final calls = <(String, Map<String, dynamic>)>[];
  Completer<void>? branchDelay;
  Object? submitError;
  bool omitRowIds = false;
  int next = 0;
  int nextRow = 10000;

  List<Map<String, dynamic>> history(String profile, String id) =>
      histories.putIfAbsent(
        '$profile/$id',
        () => [
          {'role': 'user', 'text': 'Original prompt', 'row_id': 1},
          {'role': 'tool', 'text': 'Tool output', 'row_id': 2},
          {'role': 'assistant', 'text': 'Original answer', 'row_id': 3},
          {'role': 'user', 'text': 'Follow-up', 'row_id': 4},
          {'role': 'assistant', 'text': 'Later answer', 'row_id': 5},
        ],
      );

  ProfileGateway gateway(WorkspaceScope scope) =>
      gateways[scope.profileName] = ProfileGateway(
        scope: scope,
        discover: () async => const ProfileDiscovery(
          profiles: [
            HermesProfile(name: 'a'),
            HermesProfile(name: 'b'),
          ],
          currentName: 'a',
          activeName: 'a',
        ),
        get: (path, query) async => path == 'sessions'
            ? {
                'offset': int.parse(query['offset']!),
                'limit': int.parse(query['limit']!),
                'total': 1,
                'sessions': [
                  {
                    'id': 'original',
                    'title': 'Original chat',
                    'profile': scope.profileName,
                  },
                ],
              }
            : {
                'session_id': Uri.decodeComponent(path.split('/')[1]),
                'pagination': {
                  'limit': 50,
                  'offset': int.parse(query['offset']!),
                  'order': 'latest',
                  'returned': history(
                    scope.profileName,
                    Uri.decodeComponent(path.split('/')[1]),
                  ).length,
                },
                'messages': answerHistoryRows(
                  history(
                    scope.profileName,
                    Uri.decodeComponent(path.split('/')[1]),
                  ),
                ),
              },
        rpc: (method, params) async {
          calls.add((method, params));
          final profile = scope.profileName;
          final id = (params['session_id'] as String? ?? 'original')
              .replaceFirst('runtime-', '');
          Map<String, dynamic> session(String child) => {
            'session_id': 'runtime-$child',
            'stored_session_id': child,
            'messages': history(
              profile,
              child,
            ).map((m) => Map<String, dynamic>.from(m)).toList(),
            'info': {'profile_name': profile},
            'title': 'Branched chat',
          };
          switch (method) {
            case 'projects.tree':
              return {'projects': <Map<String, dynamic>>[]};
            case 'session.resume':
              return session(id);
            case 'session.history':
              return {
                'messages': history(profile, id)
                    .map(
                      (m) => {
                        ...m,
                        if (omitRowIds && m['role'] == 'user') 'row_id': null,
                      },
                    )
                    .toList(),
              };
            case 'session.branch':
              await branchDelay?.future;
              final child = 'child-${++next}';
              histories['$profile/$child'] = history(profile, id)
                  .where(isBranchMessage)
                  .take(params['count'] as int)
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList();
              for (var i = 0; i < histories['$profile/$child']!.length; i++) {
                histories['$profile/$child']![i]['row_id'] =
                    next * 1000 + i + 1;
              }
              return session(child);
            case 'prompt.submit':
              if (submitError != null) throw submitError!;
              final rows = history(profile, id);
              final cut = params['truncate_before_row_id'];
              if (cut != null) {
                final index = rows.indexWhere((m) => m['row_id'] == cut);
                rows.removeRange(index, rows.length);
              }
              rows.add({
                'role': 'user',
                'text': params['text'],
                'row_id': nextRow++,
              });
              rows.add({
                'role': 'assistant',
                'text': 'New answer $next',
                'row_id': nextRow++,
              });
              return {'status': 'streaming'};
          }
          return {};
        },
      );

  Future<void> complete(ProfileChat chat) async {
    gateways[chat.key.workspace.profileName]!.onEvent!(
      StreamEvent(
        type: 'message.complete',
        sessionId: chat.runtimeId,
        data: const {},
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late AnswerHost host;
  late SharedPreferences preferences;
  late ProfileWorkspaceController controller;
  late ProfileChat original;

  ProfileWorkspaceController makeController() => ProfileWorkspaceController(
    connectionIdentity: 'host-settings',
    connection: SavedConnection(
      id: 'host',
      label: 'Host',
      host: 'localhost',
      port: 1,
      apiKey: '',
    ),
    preferences: preferences,
    gatewayFactory: host.gateway,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    host = AnswerHost();
    controller = makeController();
    await controller.initialize();
    await controller.openSession(
      ProfileSessionKey(controller.current!.scope, 'original'),
    );
    original = controller.current!.chat!;
  });
  tearDown(() => controller.dispose());

  test(
    'branches at the selected answer, ignoring tools and later turns',
    () async {
      final child = (await controller.branchAnswer(original, 2))!;
      expect(child.messages.map(answerMessageText), [
        'Original prompt',
        'Original answer',
      ]);
      expect(original.messages.length, 5);
      expect(controller.current!.chat, same(child));
      expect(host.calls.lastWhere((c) => c.$1 == 'session.branch').$2, {
        'session_id': 'runtime-original',
        'count': 2,
        'profile': 'a',
      });
      expect(host.calls.where((c) => c.$1 == 'prompt.submit'), isEmpty);
    },
  );

  test(
    'regenerates in a saved child; switches context and restores links after restart',
    () async {
      original.draft = 'Unsent draft';
      final before = jsonEncode(host.history('a', 'original'));
      final child = (await controller.branchAnswer(
        original,
        2,
        regenerate: true,
      ))!;
      await host.complete(child);
      final submit = host.calls.lastWhere((c) => c.$1 == 'prompt.submit').$2;
      expect(submit, {
        'session_id': child.runtimeId,
        'profile': 'a',
        'text': 'Original prompt',
        'truncate_before_row_id': 1001,
        'confirm_truncate': true,
        'confirm_empty_truncate': true,
      });
      expect(jsonEncode(host.history('a', 'original')), before);
      expect(child.messages.map(answerMessageText), [
        'Original prompt',
        'New answer 1',
      ]);
      var group = controller.answerVersions(child, 0)!;
      expect(group.sessions, ['original', child.key.sessionId]);
      await controller.selectAnswer(child, group, 0);
      expect(controller.current!.chat, same(original));
      expect(original.draft, 'Unsent draft');
      original.draft = 'Continue original';
      await controller.send(original);
      expect(host.calls.last.$2['session_id'], original.runtimeId);
      await host.complete(original);
      final third = (await controller.branchAnswer(
        child,
        1,
        regenerate: true,
      ))!;
      await host.complete(third);
      expect(group.sessions.length, 3);
      controller.dispose();
      controller = makeController();
      await controller.initialize();
      await controller.openSession(third.key);
      group = controller.answerVersions(controller.current!.chat!, 0)!;
      expect(group.sessions.length, 3);
      await controller.selectAnswer(controller.current!.chat!, group, 0);
      expect(controller.current!.chat!.messages.last['text'], 'New answer 1');
      expect(controller.current!.chat!.key, original.key);
      expect(
        preferences
            .getKeys()
            .where((k) => k.startsWith('answer_versions'))
            .length,
        1,
      );
      final saved = preferences.getString(
        preferences.getKeys().singleWhere(
          (k) => k.startsWith('answer_versions'),
        ),
      )!;
      expect(saved, isNot(contains('Original prompt')));
    },
  );

  test(
    'duplicate taps and sending during a branch do not submit twice',
    () async {
      host.branchDelay = Completer<void>();
      final pending = controller.branchAnswer(original, 2, regenerate: true);
      await Future<void>.delayed(Duration.zero);
      expect(
        await controller.branchAnswer(original, 2, regenerate: true),
        isNull,
      );
      original.draft = 'Do not send yet';
      await controller.send(original);
      expect(host.calls.where((c) => c.$1 == 'prompt.submit'), isEmpty);
      host.branchDelay!.complete();
      final child = (await pending)!;
      await host.complete(child);
      expect(host.calls.where((c) => c.$1 == 'session.branch').length, 1);
      expect(host.calls.where((c) => c.$1 == 'prompt.submit').length, 1);
    },
  );

  test(
    'profile switch during branching keeps navigation and owners isolated',
    () async {
      host.branchDelay = Completer<void>();
      final pending = controller.branchAnswer(original, 2, regenerate: true);
      await Future<void>.delayed(Duration.zero);
      await controller.switchProfile('b');
      await controller.openSession(
        ProfileSessionKey(controller.current!.scope, 'original'),
      );
      host.branchDelay!.complete();
      final child = (await pending)!;
      await host.complete(child);
      expect(controller.current!.scope.profileName, 'b');
      expect(controller.answerVersions(controller.current!.chat!, 0), isNull);
      expect(
        host.calls.lastWhere((c) => c.$1 == 'prompt.submit').$2['profile'],
        'a',
      );
    },
  );

  test('leaving the chat during a branch does not reopen it', () async {
    host.branchDelay = Completer<void>();
    final pending = controller.branchAnswer(original, 2);
    await Future<void>.delayed(Duration.zero);
    controller.showList();
    host.branchDelay!.complete();
    await pending;
    expect(controller.current!.chat, isNull);
  });

  test('stale history refuses the branch before mutation', () async {
    original.messages[2]['content'] = 'Stale answer';
    await expectLater(controller.branchAnswer(original, 2), throwsStateError);
    expect(host.calls.where((c) => c.$1 == 'session.branch'), isEmpty);
    expect(original.changingAnswer, isFalse);
  });

  test(
    'a paged transcript uses the saved row rather than its local position',
    () async {
      original.messages = original.messages.sublist(3);
      final child = (await controller.branchAnswer(
        original,
        1,
        regenerate: true,
      ))!;
      await host.complete(child);
      expect(
        host.calls.lastWhere((c) => c.$1 == 'session.branch').$2['count'],
        4,
      );
      expect(
        host.calls.lastWhere((c) => c.$1 == 'prompt.submit').$2['text'],
        'Follow-up',
      );
      expect(child.messages.map(answerMessageText), [
        'Original prompt',
        'Original answer',
        'Follow-up',
        'New answer 1',
      ]);
      final group = controller.answerVersionsForMessage(
        child,
        child.messages.last,
      )!;
      expect(group.userOrdinal, 1);
      await controller.selectAnswer(child, group, 0);
      expect(
        controller.answerVersionsForMessage(original, original.messages.last),
        same(group),
      );
    },
  );

  test(
    'regenerating a later turn retains navigation for earlier answer versions',
    () async {
      final second = (await controller.branchAnswer(
        original,
        2,
        regenerate: true,
      ))!;
      await host.complete(second);
      second.draft = 'Follow-up on second answer';
      await controller.send(second);
      await host.complete(second);
      final later = (await controller.branchAnswer(
        second,
        3,
        regenerate: true,
      ))!;
      await host.complete(later);
      final earlier = controller.answerVersions(later, 0)!;
      expect(earlier.selections[later.key.sessionId], 1);
      expect(controller.answerVersions(later, 1)!.sessions, [
        second.key.sessionId,
        later.key.sessionId,
      ]);
      await controller.selectAnswer(later, earlier, 0);
      expect(controller.current!.chat, same(original));
      expect(original.messages.last['text'], 'Later answer');
    },
  );

  test('rejected regeneration removes only its failed version link', () async {
    final second = (await controller.branchAnswer(
      original,
      2,
      regenerate: true,
    ))!;
    await host.complete(second);
    host.submitError = JsonRpcError('prompt.submit', 'Session busy');
    await expectLater(
      controller.branchAnswer(second, 1, regenerate: true),
      throwsStateError,
    );
    expect(controller.current!.chat, same(second));
    final group = controller.answerVersions(second, 0)!;
    expect(group.sessions, [original.key.sessionId, second.key.sessionId]);
    expect(group.selections.containsKey('child-2'), isFalse);
    expect(
      controller.current!.chats['child-2']!.status,
      ProfileTurnStatus.failed,
    );
  });

  test(
    'missing durable row IDs refuses regeneration without counting a copy as an answer',
    () async {
      host.omitRowIds = true;
      await expectLater(
        controller.branchAnswer(original, 2, regenerate: true),
        throwsStateError,
      );
      final child = controller.current!.chats['child-1']!;
      expect(child.status, ProfileTurnStatus.failed);
      expect(child.error, contains('saved prompt address'));
      expect(child.messages.last['text'], 'Original answer');
      expect(host.calls.where((c) => c.$1 == 'prompt.submit'), isEmpty);
      expect(controller.answerVersions(child, 0), isNull);
      expect(controller.current!.chat, same(original));
    },
  );

  test(
    'uncertain submit retains links and does not automatically resubmit',
    () async {
      host.submitError = TimeoutException('connection lost');
      final child = (await controller.branchAnswer(
        original,
        2,
        regenerate: true,
      ))!;
      expect(child.status, ProfileTurnStatus.reconnecting);
      expect(controller.answerVersions(child, 0)!.sessions.length, 2);
      await controller.reconnect(child.key.workspace);
      expect(host.calls.where((c) => c.$1 == 'prompt.submit').length, 1);
      expect(original.messages.last['text'], 'Later answer');
    },
  );

  testWidgets(
    'workspace refresh action generates and navigates answer versions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ProfileWorkspaceScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      final originalActions = find.byKey(const ValueKey('answer-actions-3'));
      await tester.ensureVisible(originalActions);
      await tester.tap(
        find.descendant(
          of: originalActions,
          matching: find.byTooltip('Regenerate response'),
        ),
      );
      // The controller's preferences write queue is created in setUp, outside
      // the widget clock. Let those real futures settle before emitting done.
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          if (controller.current!.chat!.status == ProfileTurnStatus.running) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      });
      await tester.pump();
      final child = controller.current!.chat!;
      expect(child.key.sessionId, 'child-1');
      expect(child.status, ProfileTurnStatus.running);
      await tester.runAsync(() => host.complete(child));
      await tester.pumpAndSettle();
      expect(child.status, ProfileTurnStatus.completed);
      expect(child.messages.map(answerMessageText), [
        'Original prompt',
        'New answer 1',
      ]);
      expect(controller.answerVersions(child, 0)?.sessions.length, 2);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('New answer 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous answer'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Original answer'), findsOneWidget);
      expect(find.text('Later answer'), findsOneWidget);
      await tester.tap(find.byTooltip('Next answer'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Later answer'), findsNothing);
    },
  );

  testWidgets('answer controls fit a narrow phone and disable at the ends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnswerActions(
            count: 2,
            version: 1,
            onNext: () {},
            onPrevious: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNotNull,
    );
  });
}
