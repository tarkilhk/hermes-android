/// Authored UI preview only. This target never connects to Hermes and is never
/// imported by lib/main.dart. Restore the normal APK after visual inspection.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import '../test/support/profile_browser_fixture.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = ProfileBrowserFixture();
  final controller = ProfileWorkspaceController(
    connection: SavedConnection(
      id: 'ui-preview',
      label: 'UI preview · Prestige',
      host: 'unused',
      port: 1,
      apiKey: '',
    ),
    connectionIdentity: 'authored-ui-preview',
    preferences: await SharedPreferences.getInstance(),
    gatewayFactory: fixture.gateway,
  );
  await controller.initialize();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: hermesTheme(Brightness.light),
      darkTheme: hermesTheme(Brightness.dark),
      home: ProfileWorkspaceScreen(controller: controller),
    ),
  );
}
