/// Disposable emulator entry point for native camera, share and process checks.
/// Uses real Android plugins and preferences, with synthetic Hermes transport.
/// Build only as debug; never install this entry point in Hermes Personal.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hermes_android/core/services/android_launch_intent_service.dart';
import 'package:hermes_android/core/services/android_share_intent_service.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_connection_identity.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/services/profile_workspace_registry.dart';
import 'package:hermes_android/main.dart';

import 'support/roadmap_emulator_fixture.dart';

Future<void> main() async {
  if (!kDebugMode) throw StateError('Emulator preview requires a debug build.');
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final manager = await ConnectionManager.create(preferences);
  final connection = SavedConnection(
    id: 'roadmap-native-emulator',
    label: 'Emulator fixture',
    host: 'unused.invalid',
    port: 1,
    apiKey: '',
  );
  await manager.importConnections([connection], replaceExisting: true);
  await preferences.setString('last_connection_id', connection.id);
  final fixture = RoadmapEmulatorFixture();
  final registry = ProfileWorkspaceRegistry(
    identities: ProfileConnectionIdentity(),
    create: (saved, identity) => ProfileWorkspaceController(
      connection: saved,
      connectionIdentity: identity,
      preferences: preferences,
      gatewayFactory: fixture.gateway,
    ),
  );
  final shareIntents = AndroidShareIntentService();
  final launchIntents = AndroidLaunchIntentService();
  await Future.wait([shareIntents.initialize(), launchIntents.initialize()]);
  runApp(
    HermesApp(
      connManager: manager,
      profileControllers: registry,
      shareIntents: shareIntents,
      launchIntents: launchIntents,
    ),
  );
}
