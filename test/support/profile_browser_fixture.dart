import 'dart:async';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profiles_repository.dart';

/// Authored UI data, never used by the production application or a live server.
class ProfileBrowserFixture {
  final now = DateTime.now().millisecondsSinceEpoch / 1000;
  final delays = <String, Completer<void>>{};
  final calls = <(String, String, Map<String, dynamic>)>[];
  bool failWork = false;
  bool failProjects = false;
  List<Map<String, dynamic>> projects(String profile) => profile == 'work'
      ? [
          {
            'id': 'work-project',
            'label': 'Work project',
            'path': '/work',
            'lastActive': now,
          },
        ]
      : [
          {
            'id': 'home',
            'label': 'Home',
            'isNoProject': true,
            'lastActive': now,
          },
          for (final entry in [
            (1, 'Archive', 6),
            (2, 'Mobile app', 1),
            (3, 'Home lab', 4),
            (4, 'Website', 2),
            (5, 'Utilities', 5),
            (6, 'Notes', 3),
          ])
            {
              'id': 'p${entry.$1}',
              'label': entry.$2,
              'path': '/${entry.$2}',
              'lastActive': now - entry.$3 * 3600,
            },
        ];

  List<Map<String, dynamic>> sessions(String profile) => profile == 'work'
      ? [
          {
            'id': 'newest',
            'title': 'Work chat',
            'profile': 'work',
            'last_active': now - 60,
          },
        ]
      : [
          {
            'id': 'old',
            'title': 'Update the setup guide',
            'profile': profile,
            'last_active': now - 86400,
          },
          {
            'id': 'pinned',
            'title': 'Plan the Android workspace',
            'profile': profile,
            'pinned': true,
            'last_active': now - 1209600,
          },
          {
            'id': 'newest',
            'title': 'Improve the conversation list',
            'profile': profile,
            'last_active': now - 7200,
          },
          {
            'id': 'project-only',
            'title': 'Project-only chat',
            'profile': profile,
            'last_active': now - 10800,
            'cwd': '/not-the-project-path',
          },
          {
            'id': 'pin-two',
            'title': 'Ideas to return to',
            'profile': profile,
            'pinned': true,
            'last_active': now - 1814400,
          },
          {
            'id': 'test',
            'title': 'Verify gateway reconnects',
            'profile': profile,
            'last_active': now - 18000,
          },
          {
            'id': 'docs',
            'title': 'Review documentation changes',
            'profile': profile,
            'last_active': now - 21600,
          },
        ];

  ProfileGateway gateway(WorkspaceScope scope) => ProfileGateway(
    scope: scope,
    discover: () async => const ProfileDiscovery(
      profiles: [
        HermesProfile(name: 'personal'),
        HermesProfile(name: 'work'),
      ],
      currentName: 'personal',
      activeName: 'personal',
    ),
    get: (path, query) async {
      await delays[scope.profileName]?.future;
      if (failWork && scope.profileName == 'work') throw StateError('Offline');
      return path == 'sessions'
          ? {'sessions': sessions(scope.profileName)}
          : {'messages': []};
    },
    rpc: (method, params) async {
      calls.add((scope.profileName, method, params));
      if (method == 'projects.tree') {
        if (failProjects) throw StateError('Projects unavailable');
        return {'projects': projects(scope.profileName)};
      }
      if (method == 'projects.project_sessions') {
        return {
          'project': {
            'id': params['project_id'],
            'repos': [
              {
                'groups': [
                  {
                    'sessions': [
                      sessions(scope.profileName).firstWhere(
                        (r) =>
                            r['id'] ==
                            (scope.profileName == 'work'
                                ? 'newest'
                                : 'project-only'),
                      ),
                    ],
                  },
                ],
              },
            ],
          },
        };
      }
      if (method == 'session.resume' || method == 'session.create') {
        return {
          'session_id': 'runtime',
          'stored_session_id': 'new-chat',
          'messages': [],
          'info': {'profile_name': scope.profileName},
        };
      }
      return {};
    },
  );
}
