import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/android_launch_intent_service.dart';
import 'core/services/android_share_intent_service.dart';
import 'core/services/config_backup.dart';
import 'core/services/config_backup_io.dart';
import 'core/services/config_backup_service.dart';
import 'core/services/connection_manager.dart';
import 'core/services/gateway_turn_application_controller.dart';
import 'core/services/text_size_preference.dart';
import 'core/screens/profile_workspace_screen.dart';
import 'core/services/profile_workspace_controller.dart';
import 'core/services/profile_connection_identity.dart';
import 'core/services/profile_workspace_registry.dart';
import 'core/services/profile_gateway.dart';
import 'core/services/profiles_repository.dart';
import 'core/models/hermes_profile.dart';
import 'core/services/turn_notification_service.dart';
import 'core/theme/hermes_theme.dart';
import 'core/utils/responsive.dart';
import 'core/widgets/config_backup_card.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final connManager = await ConnectionManager.create(prefs);
  final shareIntents = AndroidShareIntentService();
  final launchIntents = AndroidLaunchIntentService();
  await Future.wait([shareIntents.initialize(), launchIntents.initialize()]);
  runApp(
    HermesApp(
      connManager: connManager,
      shareIntents: shareIntents,
      launchIntents: launchIntents,
    ),
  );
}

class HermesApp extends StatefulWidget {
  final ConnectionManager connManager;
  final AndroidShareIntentService? shareIntents;
  final AndroidLaunchIntentService? launchIntents;
  const HermesApp({
    required this.connManager,
    this.shareIntents,
    this.launchIntents,
    super.key,
  });

  @override
  State<HermesApp> createState() => HermesAppState();

  static ThemeMode getThemeMode(SharedPreferences prefs) {
    final stored = prefs.getString('theme_mode') ?? 'system';
    switch (stored) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(
    SharedPreferences prefs,
    ThemeMode mode,
  ) async {
    final value = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
        ? 'light'
        : 'system';
    await prefs.setString('theme_mode', value);
  }

  static TextSizePreference getTextSizePreference(SharedPreferences prefs) {
    return TextSizePreferenceStore(prefs).read();
  }
}

class HermesAppState extends State<HermesApp> {
  late final GatewayTurnApplicationController _turnApplicationController;
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final ProfileWorkspaceRegistry _profileControllers;
  late final PluginTurnNotificationSink _profileNotifications;
  late final Future<void> _notificationsReady;

  Future<ProfileWorkspaceController> profileController(
    SavedConnection connection,
  ) async {
    // Home and incoming share routes can hold an older metadata snapshot after
    // settings edits or config restore. Resolve the current secure credentials.
    final current = (await widget.connManager.loadConnectionsWithSecrets())
        .where((c) => c.id == connection.id)
        .firstOrNull;
    if (current == null) throw StateError('The connection is unavailable');
    return _profileControllers.forConnection(current);
  }

  Future<void> enableProfileNotifications() async {
    await _notificationsReady;
    await _profileNotifications.requestPermission();
  }

  Future<void> _openProfileNotification(String payload) async {
    try {
      final key = ProfileSessionKey.fromJson(
        jsonDecode(payload) as Map<String, dynamic>,
      );
      final connection = (await widget.connManager.loadConnectionsWithSecrets())
          .where((c) => c.id == key.workspace.connectionId)
          .firstOrNull;
      if (!mounted) return;
      if (connection == null) {
        throw StateError('The original connection is unavailable');
      }
      final controller = await _profileControllers.forSession(connection, key);
      if (controller.discovery == null) await controller.initialize();
      await controller.openSession(key);
      if (!mounted) return;
      if (controller.current?.scope != key.workspace ||
          controller.current?.chat?.key != key) {
        throw StateError('The notification target is unavailable');
      }
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ProfileWorkspaceScreen(
            controller: controller,
            enableNotifications: enableProfileNotifications,
          ),
        ),
      );
    } catch (_) {
      // Malformed or removed targets cannot be rerouted to a default profile.
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This chat is unavailable on its original host or profile.',
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _turnApplicationController = GatewayTurnApplicationController();
    _profileNotifications = PluginTurnNotificationSink(
      onOpen: (payload) {
        unawaited(
          WidgetsBinding.instance.endOfFrame.then(
            (_) => _openProfileNotification(payload),
          ),
        );
      },
    );
    _notificationsReady = _profileNotifications.initialize().catchError(
      (Object _) {},
    );
    _profileControllers = ProfileWorkspaceRegistry(
      identities: ProfileConnectionIdentity(),
      create: (connection, identity) => ProfileWorkspaceController(
        connection: connection,
        connectionIdentity: identity,
        preferences: widget.connManager.prefs,
        onAttention: (chat, needsInput) async {
          await _notificationsReady;
          await _profileNotifications.show(
            TurnNotification(
              id: chat.key.hashCode & 0x7fffffff,
              title:
                  '${chat.key.workspace.profileName}: ${needsInput ? 'Needs attention' : 'Chat finished'}',
              body: chat.title,
              payload: jsonEncode(chat.key.toJson()),
              channel: TurnNotificationService.turnChannel,
            ),
          );
        },
      ),
    );
  }

  Future<void> setTextSizePreference(TextSizePreference preference) async {
    await TextSizePreferenceStore(widget.connManager.prefs).save(preference);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Hermes Agent',
      themeMode: HermesApp.getThemeMode(widget.connManager.prefs),
      theme: hermesTheme(Brightness.light),
      darkTheme: hermesTheme(Brightness.dark),
      builder: (context, child) {
        final systemMediaQuery = MediaQuery.of(context);
        final preference = HermesApp.getTextSizePreference(
          widget.connManager.prefs,
        );
        return MediaQuery(
          data: systemMediaQuery.copyWith(
            textScaler: preference.applyTo(systemMediaQuery.textScaler),
          ),
          child: child!,
        );
      },
      home: HomeScreen(
        profileController: profileController,
        enableProfileNotifications: enableProfileNotifications,
        connManager: widget.connManager,
        turnApplicationController: _turnApplicationController,
        shareIntents: widget.shareIntents,
        launchIntents: widget.launchIntents,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_turnApplicationController.close());
    _profileControllers.dispose();
    super.dispose();
  }
}

/// Brand header used across screens.
class HermesHeader extends StatelessWidget {
  final String? subtitle;
  const HermesHeader({super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: Color(0xFFD4AF37), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'HERMES',
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD4AF37),
              letterSpacing: 6,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final FutureOr<ProfileWorkspaceController> Function(SavedConnection)?
  profileController;
  final Future<void> Function()? enableProfileNotifications;
  final ConnectionManager connManager;
  final GatewayTurnApplicationController turnApplicationController;
  final AndroidShareIntentService? shareIntents;
  final AndroidLaunchIntentService? launchIntents;
  final Future<String?> Function()? pickBackupFile;
  final Future<ConfigImportResult> Function(
    String contents,
    String passphrase,
    ConfigImportMode mode,
  )?
  importBackup;

  const HomeScreen({
    this.profileController,
    this.enableProfileNotifications,
    required this.connManager,
    required this.turnApplicationController,
    this.shareIntents,
    this.launchIntents,
    this.pickBackupFile,
    this.importBackup,
    super.key,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<SavedConnection> _connections = [];
  bool _autoNavigated = false;
  static const String _lastConnectionKey = 'last_connection_id';

  void _refresh() {
    setState(() => _connections = widget.connManager.getConnections());
  }

  /// Public only so the import flow and its widget test can refresh Home after
  /// restoring connections without restarting the process.
  void refreshConnections() => _refresh();

  ConfigBackupIo get _backupIo =>
      ConfigBackupIo(connectionManager: widget.connManager);

  Future<void> _showRestoreConfig() async {
    String? contents;
    try {
      contents =
          await (widget.pickBackupFile?.call() ?? _backupIo.pickBackupFile());
    } catch (error) {
      if (!mounted) return;
      _showRestoreError(error);
      return;
    }
    if (contents == null || !mounted) return;

    final choice = await showModalBottomSheet<ImportChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ImportOptionsSheet(),
    );
    if (choice == null || !mounted) return;

    try {
      final importer = widget.importBackup ?? _backupIo.importEncrypted;
      final result = await importer(contents, choice.passphrase, choice.mode);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.summary)));
    } catch (error) {
      if (!mounted) return;
      _showRestoreError(error);
    }
  }

  void _showRestoreError(Object error) {
    final message = error is ConfigBackupException
        ? error.message
        : 'The backup could not be restored.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.shareIntents?.pendingShare.addListener(_onSharedText);
    widget.launchIntents?.pendingQuickChat.addListener(_onQuickChat);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onSharedText();
      _onQuickChat();
    });
  }

  SavedConnection? _connectionForExternalAction() {
    final lastId = widget.connManager.prefs.getString(_lastConnectionKey);
    final preferred = _connections
        .where((connection) => connection.id == lastId)
        .firstOrNull;
    return preferred ?? (_connections.length == 1 ? _connections.single : null);
  }

  void _onSharedText() {
    if (!mounted || widget.shareIntents?.pendingShare.value == null) return;
    final connection = _connectionForExternalAction();
    if (connection == null) return;
    _autoNavigated = true;
    _navigateToWorkspace(connection);
  }

  void _onQuickChat() {
    if (!mounted || widget.launchIntents?.pendingQuickChat.value != true) {
      return;
    }
    final connection = _connectionForExternalAction();
    if (connection == null) return;
    _autoNavigated = true;
    _navigateToWorkspace(connection);
  }

  @override
  void dispose() {
    widget.shareIntents?.pendingShare.removeListener(_onSharedText);
    widget.launchIntents?.pendingQuickChat.removeListener(_onQuickChat);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_autoNavigated && _connections.isNotEmpty) {
      _autoNavigated = true;
      _maybeAutoNavigate();
    }
  }

  void _maybeAutoNavigate() {
    // The share listener owns this route so the regular last-connection
    // auto-navigation cannot stack a second Workspace above the shared draft.
    if (widget.shareIntents?.pendingShare.value != null ||
        widget.launchIntents?.pendingQuickChat.value == true) {
      return;
    }
    final lastId = widget.connManager.prefs.getString(_lastConnectionKey);
    if (lastId == null) return;
    final conn = _connections.where((c) => c.id == lastId).firstOrNull;
    if (conn == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigateToWorkspace(conn);
    });
  }

  Future<void> _navigateToWorkspace(SavedConnection conn) async {
    final ProfileWorkspaceController controller;
    try {
      controller = await widget.profileController!(conn);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connection ownership could not be verified securely.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    widget.connManager.prefs.setString(_lastConnectionKey, conn.id);
    final sharedPayload = widget.shareIntents?.takePendingShare();
    final initialQuickChat =
        widget.launchIntents?.takePendingQuickChat() == true &&
        sharedPayload == null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileWorkspaceScreen(
          controller: controller,
          enableNotifications: widget.enableProfileNotifications,
          initialSharedPayload: sharedPayload,
          initialQuickChat: initialQuickChat,
        ),
      ),
    );
  }

  void _showAddDialog() => _showConnectionDialog();

  void _showEditConnectionDialog(SavedConnection conn) {
    _showConnectionDialog(existing: conn);
  }

  void _showConnectionDialog({SavedConnection? existing}) {
    showDialog(
      context: context,
      builder: (_) => _AddDialog(
        initialConnection: existing,
        onSave:
            (
              label,
              host,
              port,
              apiKey, {
              gatewayPrefix,
              dashboardPrefix,
              dashboardProxied = false,
              desktopGatewayUrl,
              dashboardPort,
              dashboardUsername,
              dashboardPassword,
            }) async {
              if (existing == null) {
                await widget.connManager.saveConnection(
                  label,
                  host,
                  port,
                  apiKey,
                  gatewayPrefix: gatewayPrefix,
                  dashboardPrefix: dashboardPrefix,
                  dashboardProxied: dashboardProxied,
                  desktopGatewayUrl: desktopGatewayUrl,
                  dashboardPort: dashboardPort,
                  dashboardUsername: dashboardUsername,
                  dashboardPassword: dashboardPassword,
                );
              } else {
                await widget.connManager.updateConnection(
                  existing.id,
                  label,
                  host,
                  port,
                  apiKey,
                  gatewayPrefix: gatewayPrefix,
                  dashboardPrefix: dashboardPrefix,
                  dashboardProxied: dashboardProxied,
                  desktopGatewayUrl: desktopGatewayUrl,
                  dashboardPort: dashboardPort,
                  dashboardUsername: dashboardUsername,
                  dashboardPassword: dashboardPassword,
                );
              }
              _refresh();
            },
      ),
    );
  }

  Widget _buildConnectionCard(SavedConnection conn) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.router, color: Color(0xFFD4AF37)),
        title: Text(conn.label),
        subtitle: Text(
          '${conn.host}:${conn.dashboardPort}${conn.dashboardPrefix ?? ''}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'delete') {
              try {
                await widget.connManager.deleteConnection(conn.id);
                if (mounted) _refresh();
              } on CredentialStorageException {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'The connection could not be deleted safely.',
                    ),
                  ),
                );
              }
            } else if (v == 'edit') {
              _showEditConnectionDialog(conn);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit Connection')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => _navigateToWorkspace(conn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'HERMES',
          style: TextStyle(
            fontFamily: 'Cinzel',
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_connections.isNotEmpty)
            IconButton(
              key: const Key('home_restore_config_menu'),
              tooltip: 'Restore configuration',
              onPressed: _showRestoreConfig,
              icon: const Icon(Icons.settings_backup_restore),
            ),
        ],
      ),
      body: _connections.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_outlined, size: 64, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text(
                    'No connections',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to connect to a profile-aware Hermes gateway',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const Key('home_restore_config_button'),
                    onPressed: _showRestoreConfig,
                    icon: const Icon(Icons.settings_backup_restore),
                    label: const Text('Restore configuration'),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (Responsive.isTablet(context)) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _connections.length,
                    itemBuilder: (_, i) =>
                        _buildConnectionCard(_connections[i]),
                  );
                }
                return ListView.builder(
                  itemCount: _connections.length,
                  itemBuilder: (_, i) => _buildConnectionCard(_connections[i]),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Connection',
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class _AddDialog extends StatefulWidget {
  final SavedConnection? initialConnection;
  final Future<void> Function(
    String label,
    String host,
    int port,
    String apiKey, {
    String? gatewayPrefix,
    String? dashboardPrefix,
    bool dashboardProxied,
    String? desktopGatewayUrl,
    int? dashboardPort,
    String? dashboardUsername,
    String? dashboardPassword,
  })
  onSave;
  const _AddDialog({required this.onSave, this.initialConnection});

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  late final TextEditingController _label;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _dashboardPrefix;
  late final TextEditingController _dashPort;
  late final TextEditingController _dashUser;
  late final TextEditingController _dashPass;
  late final TextEditingController _desktopGatewayUrl;
  late bool _showDashboard;
  late bool _dashboardProxied;
  bool _validating = false;
  String? _error;

  bool get _isEditing => widget.initialConnection != null;

  @override
  void initState() {
    super.initState();
    final conn = widget.initialConnection;
    _label = TextEditingController(text: conn?.label ?? 'Home');
    _host = TextEditingController(
      text: conn == null
          ? ''
          : conn.useHttps
          ? 'https://${conn.host}'
          : conn.host,
    );
    _port = TextEditingController(text: (conn?.port ?? 9119).toString());
    _dashboardPrefix = TextEditingController(text: conn?.dashboardPrefix ?? '');
    _dashPort = TextEditingController(
      text: conn?.dashboardPortOverride?.toString() ?? '',
    );
    _dashUser = TextEditingController(text: conn?.dashboardUsername ?? '');
    _dashPass = TextEditingController(text: conn?.dashboardPassword ?? '');
    // The Desktop Gateway URL is an advanced override, not a default: the
    // app derives the JSON-RPC/WebSocket origin from the dashboard details
    // when this field is blank. Pre-filling a hardcoded example here made
    // every new connection silently point at a dead host and wedge Project
    // loading. See docs/ANDROID_FINAL_UI_SPEC_DRAFT.md.
    _desktopGatewayUrl = TextEditingController(
      text: conn?.desktopGatewayUrl ?? '',
    );
    _dashboardProxied = conn?.dashboardProxied ?? false;
    _showDashboard =
        conn?.gatewayPrefix?.isNotEmpty == true ||
        conn?.dashboardPrefix?.isNotEmpty == true ||
        conn?.dashboardPortOverride != null ||
        conn?.dashboardUsername?.isNotEmpty == true ||
        conn?.dashboardPassword?.isNotEmpty == true ||
        _dashboardProxied ||
        conn?.desktopGatewayUrl?.isNotEmpty == true;
  }

  Future<void> _validateAndSave() async {
    final label = _label.text.trim();
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 9119;
    if (label.isEmpty || host.isEmpty || port <= 0 || port > 65535) return;
    setState(() {
      _validating = true;
      _error = null;
    });
    ProfileGateway? probe;
    try {
      final normalized = SavedConnection.normalizeHostAndPort(host, port);
      final dashPort = int.tryParse(_dashPort.text.trim()) ?? normalized.port;
      final uri = Uri.tryParse(host.contains('://') ? host : 'http://$host');
      final prefix = _dashboardPrefix.text.trim().isNotEmpty
          ? _dashboardPrefix.text.trim()
          : uri?.path ?? '';
      final dashUser = _dashUser.text.trim();
      final dashPass = _dashPass.text.trim();
      final gatewayUrl = _desktopGatewayUrl.text.trim();
      final candidate = SavedConnection(
        id: 'connection-probe',
        label: label,
        host: normalized.host,
        port: normalized.port,
        useHttps: normalized.useHttps,
        apiKey: '',
        dashboardPortOverride: dashPort,
        dashboardPrefix: prefix,
        dashboardUsername: dashUser.isEmpty ? null : dashUser,
        dashboardPassword: dashPass.isEmpty ? null : dashPass,
        dashboardProxied: _dashboardProxied,
        desktopGatewayUrl: gatewayUrl.isEmpty ? null : gatewayUrl,
      );
      final repository = ProfilesRepository.forConnection(candidate);
      late final ProfilesProbeResult discovery;
      try {
        discovery = await repository.probe();
      } finally {
        repository.close();
      }
      if (discovery.discovery == null) {
        throw StateError(discovery.message ?? 'Profile API unavailable');
      }
      probe = ProfileGateway.forConnection(
        candidate,
        WorkspaceScope(
          connectionId: candidate.id,
          profileName: discovery.discovery!.serverPreferred.name,
        ),
      );
      await probe.connect();
      await probe.sessions();
      if (!mounted) return;
      await widget.onSave(
        label,
        host,
        normalized.port,
        '',
        dashboardPrefix: prefix.isEmpty ? null : prefix,
        dashboardProxied: _dashboardProxied,
        desktopGatewayUrl: gatewayUrl.isEmpty ? null : gatewayUrl,
        dashboardPort: dashPort,
        dashboardUsername: dashUser.isEmpty ? null : dashUser,
        dashboardPassword: dashPass.isEmpty ? null : dashPass,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not connect to the modern Hermes gateway. $error';
          _validating = false;
        });
      }
    } finally {
      probe?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit Gateway Connection' : 'Add Gateway Connection',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText:
                    '192.168.1.50, 100.x.y.z, or hermes-machine.tailnet.ts.net',
              ),
              keyboardType: TextInputType.text,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _port,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: 'Hermes gateway port',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 4),
            InkWell(
              onTap: _validating
                  ? null
                  : () => setState(() => _showDashboard = !_showDashboard),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _showDashboard ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Custom proxy and dashboard details',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            if (_showDashboard) ...[
              const SizedBox(height: 8),
              const SizedBox(height: 12),
              TextField(
                controller: _dashboardPrefix,
                decoration: const InputDecoration(
                  labelText: 'Dashboard path prefix',
                  hintText: 'e.g. /dashboard (proxy path before /api/)',
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _dashboardProxied,
                contentPadding: EdgeInsets.zero,
                title: const Text('Dashboard behind proxy'),
                subtitle: const Text(
                  'Nginx injects auth — app sends clean requests',
                ),
                onChanged: (v) => setState(() => _dashboardProxied = v),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Use the gateway address and authentication configured on your Hermes host.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              TextField(
                controller: _dashPort,
                decoration: const InputDecoration(
                  labelText: 'Dashboard Port',
                  hintText: 'Leave blank to use the gateway port',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dashUser,
                decoration: const InputDecoration(
                  labelText: 'Dashboard Username (optional)',
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dashPass,
                decoration: const InputDecoration(
                  labelText: 'Dashboard Password (optional)',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desktopGatewayUrl,
                decoration: const InputDecoration(
                  labelText: 'Desktop Gateway URL (optional)',
                  hintText: 'https://hermes-desktop.example.lan',
                  helperText:
                      'Enables file attachments through the Desktop remote gateway.',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _validating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _validating ? null : _validateAndSave,
          child: _validating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEditing ? 'Save Changes' : 'Connect'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _label.dispose();
    _host.dispose();
    _port.dispose();
    _dashboardPrefix.dispose();
    _dashPort.dispose();
    _dashUser.dispose();
    _dashPass.dispose();
    _desktopGatewayUrl.dispose();
    super.dispose();
  }
}
