import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profiles_repository.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/services/attachment_draft_service.dart';
import 'package:hermes_android/core/models/attachment_draft.dart';
import 'package:hermes_android/core/services/android_launch_intent_service.dart';
import 'package:hermes_android/core/services/android_share_intent_service.dart';
import 'package:hermes_android/core/services/config_backup_service.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryCredentialStore implements CredentialStore {
  final Map<String, String> values = <String, String>{};
  final Map<String, String> _cache = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
    _cache.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    final value = values[key];
    if (value == null) {
      _cache.remove(key);
    } else {
      _cache[key] = value;
    }
    return value;
  }

  @override
  String? readCached(String key) => _cache[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _MissingFileService extends AttachmentDraftService {
  @override
  Future<AttachmentDraft> prepareGenericFile({
    required String sourcePath,
    required String displayName,
    String mediaType = 'application/octet-stream',
    required Iterable<AttachmentDraft> existingDrafts,
  }) async {
    throw const AttachmentDraftException(
      'The selected file is empty or unreadable.',
    );
  }
}

Future<ConnectionManager> buildManager() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ConnectionManager.create(
    prefs,
    credentialStore: _MemoryCredentialStore(),
  );
}

ProfileWorkspaceController profileController(
  SavedConnection connection,
  SharedPreferences prefs,
) {
  final controller = ProfileWorkspaceController(
    connectionIdentity: 'test-settings-${connection.id}',
    attachmentService: _MissingFileService(),
    connection: connection,
    preferences: prefs,
    gatewayFactory: (scope) => ProfileGateway(
      scope: scope,
      discover: () async => const ProfileDiscovery(
        profiles: [HermesProfile(name: 'default')],
        currentName: 'default',
        activeName: 'default',
      ),
      get: (_, query) async => {
        'sessions': <Map<String, dynamic>>[],
        'offset': int.parse(query['offset']!),
        'limit': int.parse(query['limit']!),
        'total': 0,
      },
      rpc: (method, _) async => method == 'session.create'
          ? {
              'session_id': 'runtime',
              'stored_session_id': 'stored',
              'info': {'profile_name': 'default'},
            }
          : {'projects': <Map<String, dynamic>>[]},
    ),
  );
  addTearDown(controller.dispose);
  return controller;
}

Future<void> pumpHome(
  WidgetTester tester,
  ConnectionManager manager, {
  Future<String?> Function()? pickBackupFile,
  Future<ConfigImportResult> Function(String, String, ConfigImportMode)?
  importBackup,
  AndroidShareIntentService? shareIntents,
  AndroidLaunchIntentService? launchIntents,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(
        profileController: (conn) => profileController(conn, manager.prefs),
        connManager: manager,
        shareIntents: shareIntents,
        launchIntents: launchIntents,
        pickBackupFile: pickBackupFile,
        importBackup: importBackup,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a device with no connections can still reach restore', (
    tester,
  ) async {
    final manager = await buildManager();
    await pumpHome(tester, manager);

    // The whole point of a config backup is the fresh install, where Settings
    // is unreachable because no connection exists yet.
    expect(manager.getConnections(), isEmpty);
    expect(find.byKey(const Key('home_restore_config_button')), findsOneWidget);
  });

  testWidgets('a saved connection opens Workspace as the primary surface', (
    tester,
  ) async {
    final manager = await buildManager();
    await manager.saveConnection('Miniserver', 'host', 8642, 'key');
    await pumpHome(tester, manager);

    await tester.tap(find.text('Miniserver'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProfileWorkspaceScreen), findsOneWidget);
    for (final destination in ['Recents', 'Projects', 'New chat']) {
      expect(find.text(destination), findsWidgets);
    }
  });

  testWidgets('a cold-start launcher shortcut opens a Quick Chat directly', (
    tester,
  ) async {
    const channel = MethodChannel(AndroidLaunchIntentService.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'quickChat');
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final launchIntents = AndroidLaunchIntentService();
    await launchIntents.initialize();
    addTearDown(launchIntents.dispose);
    final manager = await buildManager();
    await manager.saveConnection('Miniserver', 'host', 8642, 'key');

    await pumpHome(tester, manager, launchIntents: launchIntents);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ProfileWorkspaceScreen), findsOneWidget);
    expect(find.byKey(const Key('profile-message-composer')), findsOneWidget);
    expect(launchIntents.pendingQuickChat.value, isFalse);
  });

  testWidgets('a cold-start share uses the saved connection exactly once', (
    tester,
  ) async {
    const channel = MethodChannel(AndroidShareIntentService.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => 'Summarize https://example.com/shared',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final shareIntents = AndroidShareIntentService();
    await shareIntents.initialize();
    addTearDown(shareIntents.dispose);
    final manager = await buildManager();
    await manager.saveConnection('Miniserver', 'host', 8642, 'key');

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          profileController: (conn) => profileController(conn, manager.prefs),
          connManager: manager,
          shareIntents: shareIntents,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ProfileWorkspaceScreen), findsOneWidget);
    expect(find.byKey(const Key('profile-message-composer')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('profile-message-composer')))
          .controller!
          .text,
      'Summarize https://example.com/shared',
    );
    expect(shareIntents.pendingShare.value, isNull);
  });

  testWidgets(
    'a file-only share opens scoped composer and reports missing source',
    (tester) async {
      const channel = MethodChannel(AndroidShareIntentService.channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => {
              'files': [
                {
                  'path': '/cache/shared/report.pdf',
                  'name': 'report.pdf',
                  'mediaType': 'application/pdf',
                  'byteLength': 42,
                },
              ],
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final shareIntents = AndroidShareIntentService();
      await shareIntents.initialize();
      addTearDown(shareIntents.dispose);
      final manager = await buildManager();
      await manager.saveConnection('Miniserver', 'host', 8642, 'key');

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            profileController: (conn) => profileController(conn, manager.prefs),
            connManager: manager,
            shareIntents: shareIntents,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ProfileWorkspaceScreen), findsOneWidget);
      expect(find.byKey(const Key('profile-message-composer')), findsOneWidget);
      expect(find.textContaining('empty or unreadable'), findsOneWidget);
      expect(shareIntents.pendingShare.value, isNull);
    },
  );

  testWidgets('restore stays reachable once connections exist', (tester) async {
    final manager = await buildManager();
    await manager.saveConnection('Miniserver', 'host', 8642, 'key');
    await pumpHome(tester, manager);

    expect(find.byKey(const Key('home_restore_config_menu')), findsOneWidget);
  });

  testWidgets('tapping restore on an empty device opens the import sheet', (
    tester,
  ) async {
    final manager = await buildManager();
    await pumpHome(
      tester,
      manager,
      pickBackupFile: () async => 'encrypted-backup',
    );

    await tester.tap(find.byKey(const Key('home_restore_config_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import_passphrase_field')), findsOneWidget);
    expect(find.byKey(const Key('import_mode_merge')), findsOneWidget);
  });

  testWidgets('a restored connection appears without restarting the app', (
    tester,
  ) async {
    final manager = await buildManager();
    await pumpHome(tester, manager);

    expect(find.text('Connect to Hermes'), findsOneWidget);

    // Simulate what a successful import does to storage, then let the screen
    // refresh the way the import flow asks it to.
    await manager.importConnections([
      SavedConnection(
        id: 'restored-1',
        label: 'Miniserver',
        host: 'carlos-miniserver.ts.net',
        port: 8642,
        apiKey: 'sk-restored',
        useHttps: true,
      ),
    ], replaceExisting: false);

    final state = tester.state<HomeScreenState>(find.byType(HomeScreen));
    state.refreshConnections();
    await tester.pumpAndSettle();

    expect(find.text('Connect to Hermes'), findsNothing);
    expect(find.text('Miniserver'), findsOneWidget);
  });

  testWidgets('the import sheet offers merge and replace', (tester) async {
    final manager = await buildManager();
    await pumpHome(
      tester,
      manager,
      pickBackupFile: () async => 'encrypted-backup',
    );

    await tester.tap(find.byKey(const Key('home_restore_config_button')));
    await tester.pumpAndSettle();

    expect(find.text('Merge'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(ConfigImportMode.values, hasLength(2));
  });

  testWidgets('a new connection never pre-fills a Desktop Gateway URL', (
    tester,
  ) async {
    // Regression: the form used to pre-fill a hardcoded example
    // (`http://192.168.1.193/desktop`). Saving it silently pointed the app at
    // a dead Desktop Gateway, which wedged Project/session loading.
    final manager = await buildManager();
    await pumpHome(tester, manager);

    await tester.tap(find.text('Add connection'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom proxy and dashboard details'));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(
      TextField,
      'Desktop Gateway URL (optional)',
    );
    expect(field, findsOneWidget);
    final textField = tester.widget<TextField>(field);
    expect(textField.controller?.text, isEmpty);
  });
}
