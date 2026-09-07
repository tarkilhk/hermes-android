// Keep the factory's named argument public without exposing mutable state.
// ignore_for_file: prefer_initializing_formals

import 'connection_manager.dart';
import 'profile_connection_identity.dart';
import 'profile_workspace_controller.dart';

typedef ProfileControllerFactory =
    ProfileWorkspaceController Function(
      SavedConnection connection,
      String identity,
    );

/// Retained turns keep their original clients. Editing a connection creates a
/// separate owner; it never retargets sockets, drafts, or pending recovery.
class ProfileWorkspaceRegistry {
  final ProfileConnectionIdentity identities;
  final ProfileControllerFactory _create;
  final _controllers = <String, ProfileWorkspaceController>{};
  bool _closed = false;

  ProfileWorkspaceRegistry({
    required this.identities,
    required ProfileControllerFactory create,
  }) : _create = create;

  Future<ProfileWorkspaceController> forConnection(
    SavedConnection connection,
  ) async {
    final identity = await identities.resolve(connection);
    if (_closed) throw StateError('Workspace registry is closed');
    return _controllers.putIfAbsent(
      identity,
      () => _create(connection, identity),
    );
  }

  Future<ProfileWorkspaceController> forSession(
    SavedConnection connection,
    ProfileSessionKey target,
  ) async {
    final controller = await forConnection(connection);
    if (!controller.owns(target)) {
      throw StateError('The original connection settings have changed');
    }
    return controller;
  }

  void dispose() {
    _closed = true;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
}
