import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profiles_repository.dart';

void main() {
  ProfileGateway gateway({
    required Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> params,
    )
    rpc,
  }) => ProfileGateway(
    scope: WorkspaceScope(
      connectionId: 'host',
      connectionIdentity: 'identity',
      profileName: 'work',
    ),
    discover: () async => const ProfileDiscovery(
      profiles: [HermesProfile(name: 'work')],
      currentName: 'work',
      activeName: 'work',
    ),
    get: (_, _) async => const {},
    rpc: rpc,
  );

  test('discovers repository roots through the selected profile', () async {
    String? method;
    Map<String, dynamic>? params;
    final client = gateway(
      rpc: (calledMethod, calledParams) async {
        method = calledMethod;
        params = calledParams;
        return {
          'repos': [
            {
              'root': '/srv/hermes-android',
              'label': 'Hermes Android',
              'sessions': 3,
              'last_active': 42,
              'future_metadata': true,
            },
            {
              'root': '/srv/hermes-android',
              'label': 'Duplicate root',
              'sessions': 1,
              'last_active': 12,
            },
            {
              'root': '/srv/docs',
              'label': 'Docs',
              'sessions': 0,
              'last_active': 0,
            },
          ],
          'discovery_policy': {'enabled': true},
        };
      },
    );

    final folders = await client.discoverProjectFolders();

    expect(method, 'projects.discover_repos');
    expect(params, {'scan': true, 'profile': 'work'});
    expect(folders, hasLength(2));
    expect(folders.first.path, '/srv/hermes-android');
    expect(folders.first.label, 'Hermes Android');
    expect(folders.last.path, '/srv/docs');
  });

  test('rejects a malformed repository list', () async {
    final client = gateway(
      rpc: (_, _) async => {
        'repos': [
          {'root': '/srv/repo', 'label': 42},
        ],
      },
    );

    await expectLater(
      client.discoverProjectFolders(),
      throwsA(isA<FormatException>()),
    );
  });
}
