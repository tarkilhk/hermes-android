import 'dart:async';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'profile_browser_fixture.dart';

class ProfileActionsFixture extends ProfileBrowserFixture {
  final updates = <(String, String, Map<String, dynamic>)>[];
  final deletes = <(String, Map<String, String>)>[];
  final changes = <String, Map<String, Map<String, dynamic>>>{};
  final removed = <String, Set<String>>{};
  bool failMutation = false;
  bool active = false;
  Completer<void>? mutationDelay;
  @override
  List<Map<String, dynamic>> sessions(String profile) => [
    for (final row in super.sessions(profile))
      if (!(removed[profile]?.contains(row['id']) ?? false))
        {...row, ...?changes[profile]?[row['id']]},
  ];
  @override
  ProfileGateway gateway(WorkspaceScope scope) {
    final base = super.gateway(scope);
    return ProfileGateway(
      scope: scope,
      discover: base.discover,
      get: base.read,
      rpc: (method, params) async {
        if (method == 'session.active_list') {
          return {
            'sessions': [
              if (active) {'session_key': 'newest'},
            ],
          };
        }
        return base.call(method, params);
      },
      patch: (endpoint, body) async {
        updates.add((scope.profileName, endpoint, body));
        await mutationDelay?.future;
        if (failMutation) throw StateError('Write rejected');
        final id = Uri.decodeComponent(endpoint.split('/').last);
        final update = {...body}..remove('profile');
        final profile = changes.putIfAbsent(scope.profileName, () => {});
        profile[id] = {...?profile[id], ...update};
        return {'ok': true, 'title': update['title'] ?? 'Chat', ...update};
      },
      delete: (endpoint, query) async {
        if (failMutation) throw StateError('Delete rejected');
        deletes.add((endpoint, query));
        removed
            .putIfAbsent(scope.profileName, () => {})
            .add(Uri.decodeComponent(endpoint.split('/').last));
      },
    );
  }
}
