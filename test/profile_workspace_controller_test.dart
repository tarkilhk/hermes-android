import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/services/profile_selection_store.dart';
import 'package:hermes_android/core/services/profiles_repository.dart';
import 'package:hermes_android/core/services/ws_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Host {
  final gateways = <String, ProfileGateway>{};
  final calls = <(String, String, Map<String, dynamic>)>[];
  final reads = <(String, Map<String, String>)>[];
  final delays = <String, Completer<void>>{};
  final failures = <String>{};
  final closed = <String>[];
  List<String> profiles = ['a', 'b'];
  bool running = true;
  Map<String, dynamic>? inflight;
  Completer<void>? projectDelay;
  bool wrongProjectOwner = false;
  Map<String, dynamic> clarifyResult = {'status': 'ok'};
  Future<ProfileDiscovery> discover() async => ProfileDiscovery(
    profiles: profiles.map((p) => HermesProfile(name: p)).toList(),
    currentName: 'a',
    activeName: 'a',
  );
  ProfileGateway gateway(WorkspaceScope scope) {
    final name = scope.profileName;
    return gateways[name] = ProfileGateway(
      scope: scope,
      discover: discover,
      close: () => closed.add(name),
      get: (path, query) async {
        reads.add((path, query));
        await delays[name]?.future;
        if (failures.contains(name)) throw Exception('offline');
        if (path == 'sessions') {
          return {
            'offset': int.parse(query['offset']!),
            'limit': int.parse(query['limit']!),
            'total': 1,
            'sessions': [
              {'id': 'same', 'title': '$name chat', 'profile': name},
            ],
          };
        }
        return {
          'messages': [
            {'role': 'assistant', 'content': '$name completed'},
          ],
        };
      },
      rpc: (method, params) async {
        calls.add((name, method, params));
        if (method == 'clarify.respond') return clarifyResult;
        if (method == 'projects.tree') {
          return {
            'projects': [
              {
                'id': 'same',
                'label': '$name project',
                'path': '/$name',
                'lastActive': 1,
              },
            ],
          };
        }
        if (method == 'projects.project_sessions') {
          await projectDelay?.future;
          return {
            'project': {
              'id': params['project_id'],
              'repos': [
                {
                  'groups': [
                    {
                      'sessions': [
                        {
                          'id': 'project-chat',
                          'title': 'Project chat',
                          'profile': wrongProjectOwner ? 'other' : name,
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          };
        }
        if (method == 'session.create' || method == 'session.resume') {
          return {
            'session_id': '$name-runtime',
            'stored_session_id': 'same',
            'session_key': 'same',
            'messages': <Map<String, dynamic>>[],
            'running': method == 'session.resume' && running,
            'inflight': inflight,
            'info': {'profile_name': name},
          };
        }
        if (method == 'projects.create') {
          return {
            'project': {'id': 'new'},
          };
        }
        return {};
      },
    );
  }

  void event(
    String profile,
    String type, [
    Map<String, dynamic> data = const {},
  ]) {
    gateways[profile]!.onEvent!(
      StreamEvent(type: type, data: data, sessionId: '$profile-runtime'),
    );
  }
}

void main() {
  late Host host;
  late ProfileWorkspaceController controller;
  late SharedPreferences preferences;
  late List<ProfileSessionKey> notifications;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    host = Host();
    notifications = [];
    controller = ProfileWorkspaceController(
      connectionIdentity: 'original-settings',
      connection: SavedConnection(
        id: 'host',
        label: 'Host',
        host: 'localhost',
        port: 1,
        apiKey: '',
      ),
      preferences: preferences,
      gatewayFactory: host.gateway,
      onAttention: (chat, _) async => notifications.add(chat.key),
    );
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  test(
    'failed profile navigation preserves the previous project load',
    () async {
      final data = controller.current!;
      host.projectDelay = Completer<void>();
      final pending = controller.selectProject(data.projects.first);
      host.failures.add('b');
      await controller.navigateProfile('b');
      expect(controller.current, same(data));
      expect(data.projectSessionsLoading, isTrue);
      host.projectDelay!.complete();
      await pending;
      expect(data.projectSessions.single['id'], 'project-chat');
      expect(data.projectSessionsError, isNull);
    },
  );

  test('all reads and RPCs carry immutable canonical profile', () async {
    await controller.createProject('Test', '/a');
    final chat = await controller.createChat();
    chat.draft = 'hello';
    await controller.send(chat);
    await controller.approve(chat, 'once');
    await controller.stop(chat);
    expect(host.calls.every((c) => c.$3['profile'] == c.$1), isTrue);
    expect(host.reads.every((r) => r.$2['profile'] == 'a'), isTrue);
    expect(
      host.calls.map((c) => c.$2),
      containsAll([
        'projects.create',
        'session.create',
        'prompt.submit',
        'approval.respond',
        'session.interrupt',
      ]),
    );
  });

  test(
    'completion refresh keeps the entered project bound to refreshed rows',
    () async {
      await controller.selectProject(controller.current!.projects.single);
      final chat = await controller.createChat();
      chat.draft = 'Project work';
      await controller.send(chat);
      host.event('a', 'message.complete');
      await Future<void>.delayed(Duration.zero);
      expect(chat.status, ProfileTurnStatus.completed);
      expect(
        controller.current!.selectedProject,
        same(controller.current!.projects.single),
      );
      await controller.selectProject(controller.current!.selectedProject);
      expect(controller.current!.projectSessionsError, isNull);
    },
  );

  test('A continues while B is visible; duplicate IDs stay separate', () async {
    final a = await controller.createChat();
    a.draft = 'A work';
    await controller.send(a);
    controller.visible = true;
    await controller.switchProfile('b');
    final b = await controller.createChat();
    b.draft = 'B draft';
    host.event('a', 'message.delta', {'text': 'A result'});
    expect(a.streaming, 'A result');
    expect(b.streaming, isEmpty);
    expect(a.key, isNot(b.key));
    expect(host.closed, isEmpty);
    expect(host.calls.where((c) => c.$2 == 'session.interrupt'), isEmpty);
    host.event('a', 'message.complete');
    await Future<void>.delayed(Duration.zero);
    expect(a.status, ProfileTurnStatus.completed);
    expect(controller.current!.chat, same(b));
    expect(b.draft, 'B draft');
    expect(notifications, [a.key]);
    await controller.openSession(a.key);
    expect(controller.current!.scope.profileName, 'a');
    expect(controller.current!.chat!.messages.single['content'], 'a completed');
  });

  test('rapid A B A ignores a late B load and persists A', () async {
    host.delays['b'] = Completer<void>();
    final b = controller.switchProfile('b');
    await Future<void>.delayed(Duration.zero);
    expect(await controller.switchProfile('a'), isTrue);
    host.delays['b']!.complete();
    expect(await b, isFalse);
    expect(controller.current!.scope.profileName, 'a');
    expect(ProfileSelectionStore(preferences).read('original-settings'), 'a');
  });

  test(
    'project entry uses authoritative scoped membership and owns drafts',
    () async {
      final project = controller.current!.projects.single;
      await controller.selectProject(project);
      expect(controller.current!.visibleSessions.single['id'], 'project-chat');
      expect(host.calls.last.$3, {
        'project_id': 'same',
        'session_limit': 5000,
        'profile': 'a',
      });
      final draft = await controller.createChat();
      expect(draft.projectId, project['id']);
      expect(host.calls.last.$3['cwd'], '/a');
      await controller.selectProject(null);
      expect(controller.current!.visibleSessions.single['id'], 'same');
    },
  );

  test('late project load cannot undo leaving the project', () async {
    host.projectDelay = Completer<void>();
    final loading = controller.selectProject(
      controller.current!.projects.single,
    );
    await Future<void>.delayed(Duration.zero);
    await controller.selectProject(null);
    host.projectDelay!.complete();
    await loading;
    expect(controller.current!.selectedProject, isNull);
    expect(controller.current!.projectSessions, isEmpty);
    expect(controller.current!.projectSessionsLoading, isFalse);
  });

  test('project response with another profile fails closed', () async {
    host.wrongProjectOwner = true;
    await controller.selectProject(controller.current!.projects.single);
    expect(controller.current!.visibleSessions, isEmpty);
    expect(controller.current!.projectSessionsError, contains('owner'));
  });

  test('stock error completion is not reported as success', () async {
    final chat = await controller.createChat();
    chat.draft = 'test';
    await controller.send(chat);
    host.event('a', 'message.complete', {
      'status': 'error',
      'text': 'Provider unavailable',
      'error': 'Provider unavailable',
    });
    await Future<void>.delayed(Duration.zero);
    expect(chat.status, ProfileTurnStatus.failed);
    expect(chat.error, contains('Provider unavailable'));
  });

  test('final text survives a failed history refresh', () async {
    final chat = await controller.createChat();
    chat.draft = 'test';
    await controller.send(chat);
    host.failures.add('a');
    host.event('a', 'message.complete', {
      'status': 'completed',
      'text': 'The final response',
    });
    await Future<void>.delayed(Duration.zero);
    expect(chat.messages.last['content'], 'The final response');
    expect(chat.status, ProfileTurnStatus.completed);
    expect(chat.error, contains('History refresh failed'));
  });

  test('failed switch retains committed profile and data', () async {
    host.failures.add('b');
    expect(await controller.switchProfile('b'), isFalse);
    expect(controller.current!.scope.profileName, 'a');
    expect(controller.error, contains('offline'));
  });

  test('deleted profile blocks write, never retries unscoped', () async {
    await controller.switchProfile('b');
    host.profiles = ['a'];
    final before = host.calls.length;
    await expectLater(controller.createChat(), throwsStateError);
    expect(host.calls.length, before);
    expect(controller.current!.scope.profileName, 'b');
  });

  test(
    'notification target for missing profile does not open default',
    () async {
      await controller.openSession(
        ProfileSessionKey(
          WorkspaceScope(
            connectionId: 'host',
            profileName: 'missing',
            connectionIdentity: 'original-settings',
          ),
          'same',
        ),
      );
      expect(controller.current!.scope.profileName, 'a');
      expect(controller.current!.chat, isNull);
      expect(controller.error, contains('no longer available'));
    },
  );

  test(
    'cross-profile project object is rejected even with identical ID',
    () async {
      final aProject = controller.current!.projects.single;
      await controller.switchProfile('b');
      expect(() => controller.selectProject(aProject), throwsArgumentError);
    },
  );

  test('reconnect uses original durable owner without resubmitting', () async {
    final a = await controller.createChat();
    a.draft = 'once';
    await controller.send(a);
    await controller.switchProfile('b');
    await controller.reconnect(a.key.workspace);
    expect(host.calls.where((c) => c.$2 == 'prompt.submit').length, 1);
    final resume = host.calls.lastWhere((c) => c.$2 == 'session.resume');
    expect(resume.$3, {'session_id': 'same', 'profile': 'a'});
    expect(a.status, ProfileTurnStatus.running);
  });

  test(
    'reconnect restores stock inflight assistant text and failure',
    () async {
      final chat = await controller.createChat();
      chat.draft = 'once';
      await controller.send(chat);
      host.inflight = {'assistant': 'Partial response', 'streaming': true};
      await controller.reconnect(chat.key.workspace);
      expect(chat.streaming, 'Partial response');
      host.running = false;
      host.inflight = {
        'assistant': 'Partial response',
        'status': 'error',
        'error': 'Provider stopped',
      };
      await controller.reconnect(chat.key.workspace);
      expect(chat.status, ProfileTurnStatus.failed);
      expect(chat.error, 'Provider stopped');
      expect(host.calls.where((c) => c.$2 == 'prompt.submit').length, 1);
    },
  );

  test('background approval stays with its owning profile', () async {
    final a = await controller.createChat();
    a.draft = 'test';
    await controller.send(a);
    await controller.switchProfile('b');
    host.event('a', 'approval.request', {'command': 'dummy'});
    expect(a.status, ProfileTurnStatus.attention);
    expect(notifications, [a.key]);
    await controller.approve(a, 'deny');
    expect(host.calls.last.$3, {
      'session_id': 'a-runtime',
      'choice': 'deny',
      'profile': 'a',
    });
  });

  test(
    'persistent targets include connection profile and durable ID only',
    () async {
      final a = await controller.createChat();
      a.draft = 'secret draft';
      await controller.send(a);
      final key = preferences.getKeys().singleWhere(
        (k) => k.startsWith('profile_pending'),
      );
      final value = preferences.getStringList(key)!.single;
      expect(value, contains('"profile":"a"'));
      expect(value, contains('"session":"same"'));
      expect(value, isNot(contains('secret draft')));
    },
  );

  test('unavailable pending owner survives unrelated journal writes', () async {
    final chat = await controller.createChat();
    chat.draft = 'A turn';
    await controller.send(chat);
    final connection = controller.connection;
    controller.dispose();
    host.profiles = ['b'];
    controller = ProfileWorkspaceController(
      connectionIdentity: 'original-settings',
      connection: connection,
      preferences: preferences,
      gatewayFactory: host.gateway,
    );
    await controller.initialize();
    final b = await controller.createChat();
    b.draft = 'B turn';
    await controller.send(b);
    final journalKey = preferences.getKeys().singleWhere(
      (k) => k.startsWith('profile_pending'),
    );
    final saved = preferences.getStringList(journalKey)!;
    expect(saved.any((value) => value.contains('"profile":"a"')), isTrue);
    expect(saved.any((value) => value.contains('"profile":"b"')), isTrue);
  });

  test(
    'stock batched clarification routes the unanswered question ID',
    () async {
      final chat = await controller.createChat();
      chat.clarification = {
        'request_id': 'request',
        'questions': [
          {'qid': 'q0', 'question': 'First question'},
          {'qid': 'q1', 'question': 'What is the recovery marker?'},
        ],
        'answers': {'q0': 'already answered'},
      };
      expect(chat.pendingQuestion!['question'], 'What is the recovery marker?');
      await controller.clarify(chat, 'PROCESS_RECOVERY_QA');
      expect(host.calls.last.$3['question_id'], 'q1');
      expect(host.calls.last.$3['request_id'], 'request');
    },
  );

  test(
    'batch answers keep remaining questions attached to their owner',
    () async {
      final chat = await controller.createChat();
      chat.status = ProfileTurnStatus.attention;
      chat.clarification = {
        'request_id': 'batch',
        'questions': [
          {'qid': 'q0', 'question': 'First'},
          {'qid': 'q1', 'question': 'Second'},
        ],
      };
      await controller.switchProfile('b');
      host.clarifyResult = {
        'status': 'ok',
        'remaining': ['q1'],
      };
      await controller.clarify(chat, 'one');
      expect(chat.pendingQuestion!['question'], 'Second');
      expect(chat.status, ProfileTurnStatus.attention);
      expect(host.calls.last.$1, 'a');
      expect(host.calls.last.$3['question_id'], 'q0');
      host.clarifyResult = {'status': 'ok', 'remaining': []};
      await controller.clarify(chat, 'two');
      expect(host.calls.last.$3['question_id'], 'q1');
      expect(chat.clarification, isNull);
      expect(chat.status, ProfileTurnStatus.running);
      expect(controller.current!.scope.profileName, 'b');
    },
  );

  test(
    'single clarification sends its request ID without a batch ID',
    () async {
      final chat = await controller.createChat();
      chat.status = ProfileTurnStatus.attention;
      chat.clarification = {
        'request_id': 'single',
        'question': 'Which marker?',
      };
      expect(chat.pendingQuestion!['question'], 'Which marker?');
      await controller.clarify(chat, 'marker');
      expect(host.calls.last.$3['request_id'], 'single');
      expect(host.calls.last.$3.containsKey('question_id'), isFalse);
      expect(chat.clarification, isNull);
    },
  );

  test(
    'expired input refreshes its owner without retrying the answer',
    () async {
      final chat = await controller.createChat();
      chat.status = ProfileTurnStatus.attention;
      chat.clarification = {'request_id': 'expired', 'question': 'Marker?'};
      host.running = false;
      host.clarifyResult = {'status': 'expired'};
      await controller.clarify(chat, 'marker');
      expect(chat.clarification, isNull);
      expect(chat.status, ProfileTurnStatus.completed);
      expect(chat.error, contains('expired'));
      expect(host.calls.where((c) => c.$2 == 'clarify.respond'), hasLength(1));
      expect(host.calls.where((c) => c.$2 == 'prompt.submit'), isEmpty);
    },
  );
}
