import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/models/profile_live_activity.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/services/profiles_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityHost {
  final calls = <(String, String, Map<String, dynamic>)>[];
  final reads = <(String, String)>[];
  final live = <String, List<Map<String, dynamic>>>{};
  final failedProfiles = <String>{};
  final profiles = ['a', 'b'];

  Future<ProfileDiscovery> discover() async => ProfileDiscovery(
    profiles: profiles.map((name) => HermesProfile(name: name)).toList(),
    currentName: 'a',
    activeName: 'a',
  );

  ProfileGateway gateway(WorkspaceScope scope) => ProfileGateway(
    scope: scope,
    discover: discover,
    get: (path, query) async {
      reads.add((scope.profileName, path));
      if (path == 'sessions') {
        final rows = scope.profileName == 'a'
            ? [
                {'id': 'same', 'title': 'Known phone chat', 'profile': 'a'},
              ]
            : <Map<String, dynamic>>[];
        return {
          'sessions': rows,
          'offset': int.parse(query['offset']!),
          'limit': int.parse(query['limit']!),
          'total': rows.length,
        };
      }
      return {
        'session_id': path.split('/')[1],
        'messages': <Map<String, dynamic>>[],
        'pagination': {
          'offset': 0,
          'limit': 50,
          'returned': 0,
          'order': 'latest',
        },
      };
    },
    rpc: (method, params) async {
      calls.add((scope.profileName, method, params));
      if (method == 'projects.tree') return {'projects': []};
      if (method == 'session.active_list') {
        if (failedProfiles.contains(scope.profileName)) {
          throw StateError('Profile offline');
        }
        return {'sessions': live[scope.profileName] ?? []};
      }
      if (method == 'session.create' || method == 'session.resume') {
        return {
          'session_id': '${scope.profileName}-runtime',
          'stored_session_id': 'same',
          'session_key': 'same',
          'running': false,
          'info': {'profile_name': scope.profileName},
        };
      }
      return {};
    },
  );
}

void main() {
  late ActivityHost host;
  late ProfileWorkspaceController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    host = ActivityHost();
    controller = ProfileWorkspaceController(
      connection: SavedConnection(
        id: 'host',
        label: 'Host',
        host: 'localhost',
        port: 1,
        apiKey: '',
      ),
      connectionIdentity: 'activity-test',
      preferences: await SharedPreferences.getInstance(),
      gatewayFactory: host.gateway,
    );
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  test('discovers unopened live sessions without changing selection', () async {
    final selected = await controller.createChat();
    final selectedScope = controller.current!.scope;
    host.reads.clear();
    host.live['a'] = [
      {
        'id': 'a-live',
        'session_key': 'same',
        'status': 'working',
        'last_active': 2,
      },
    ];
    host.live['b'] = [
      {
        'id': 'b-live',
        'session_key': 'same',
        'status': 'waiting',
        'last_active': 3,
      },
      {
        'id': 'b-unknown',
        'session_key': 'never-opened',
        'status': 'working',
        'last_active': 1,
      },
    ];
    host.profiles.add('c');
    host.live['c'] = [
      {
        'id': 'c-starting',
        'session_key': 'new-profile-session',
        'status': 'starting',
        'last_active': 4,
      },
    ];

    await controller.refreshActivity();

    expect(controller.liveActivity, hasLength(4));
    expect(
      controller.liveActivity
          .where((item) => item.sessionId == 'same')
          .map((item) => item.workspace.profileName)
          .toSet(),
      {'a', 'b'},
    );
    final unknown = controller.liveActivity.singleWhere(
      (item) => item.runtimeId == 'b-unknown',
    );
    expect(unknown.title, 'Hermes session · never-op');
    expect(unknown.state, ProfileLiveActivityState.running);
    expect(
      controller.liveActivity
          .singleWhere((item) => item.runtimeId == 'b-live')
          .state,
      ProfileLiveActivityState.needsInput,
    );
    expect(
      controller.liveActivity
          .singleWhere((item) => item.runtimeId == 'c-starting')
          .state,
      ProfileLiveActivityState.running,
    );
    expect(
      host.reads
          .where((read) => read.$2 == 'sessions')
          .map((read) => read.$1)
          .toSet(),
      {'b', 'c'},
    );
    expect(controller.current!.scope, selectedScope);
    expect(controller.current!.chat, same(selected));
    expect(host.calls.where((call) => call.$2 == 'session.resume'), isEmpty);
  });

  test(
    'removes ended entries and reports failed profiles separately',
    () async {
      final completed = await controller.createChat();
      completed.status = ProfileTurnStatus.completed;
      host.live['a'] = [
        {'id': 'old-a', 'session_key': 'same', 'status': 'working'},
      ];
      host.live['b'] = [
        {'id': 'old-b', 'session_key': 'same', 'status': 'working'},
      ];
      await controller.refreshActivity();
      expect(controller.liveActivity, hasLength(2));

      host.live['a'] = [];
      host.failedProfiles.add('b');
      await controller.refreshActivity();

      expect(controller.liveActivity, isEmpty);
      expect(controller.activity, contains(completed));
      expect(controller.activityProfileErrors.keys, ['b']);
      expect(controller.activityLoading, isFalse);
    },
  );
}
