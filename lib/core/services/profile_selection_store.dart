import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hermes_profile.dart';
import 'profiles_repository.dart';

/// Persists the selected canonical profile independently for each connection.
class ProfileSelectionStore {
  static const String _prefix = 'workspace_profile_selection_v1_';

  final SharedPreferences _preferences;

  const ProfileSelectionStore(this._preferences);

  String? read(String connectionId) {
    final value = _preferences.getString(_key(connectionId));
    if (value == null) return null;
    if (!HermesProfile.isCanonicalName(value)) {
      _preferences.remove(_key(connectionId));
      return null;
    }
    return value;
  }

  Future<void> write(String connectionId, String profileName) async {
    if (!HermesProfile.isCanonicalName(profileName)) {
      throw ArgumentError.value(
        profileName,
        'profileName',
        'must be a canonical Hermes profile name',
      );
    }
    await _preferences.setString(_key(connectionId), profileName);
  }

  Future<void> clear(String connectionId) =>
      _preferences.remove(_key(connectionId));

  /// Restored valid selection, then running server profile, sticky active
  /// profile, then the first profile — matching the implementation spec.
  HermesProfile resolveInitial(
    String connectionId,
    ProfileDiscovery discovery,
  ) {
    final restored = discovery.named(read(connectionId));
    return restored ?? discovery.serverPreferred;
  }

  static String _key(String connectionId) {
    final encoded = sha256.convert(utf8.encode(connectionId)).toString();
    return '$_prefix$encoded';
  }
}
