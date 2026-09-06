// Named transport seams keep request functions injectable.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../models/hermes_profile.dart';
import 'connection_manager.dart';
import 'profiles_repository.dart';
import 'ws_client.dart';

typedef ScopedGet =
    Future<Map<String, dynamic>> Function(
      String endpoint,
      Map<String, String> query,
    );
typedef ScopedRpc =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> params,
    );

/// The REST page may include extra pinned rows outside its offset window.
class ProfileSessionPage {
  final List<Map<String, dynamic>> rows;
  final int offset;
  final int limit;
  final int total;
  const ProfileSessionPage({
    required this.rows,
    required this.offset,
    required this.limit,
    required this.total,
  });
  int? get nextOffset => offset + limit < total ? offset + limit : null;
}

/// The stock modern Hermes contract. All profile-owned traffic passes through
/// this immutable scope. There is no unscoped or experimental-recovery fallback.
class ProfileGateway {
  final WorkspaceScope scope;
  final ScopedGet _get;
  final ScopedRpc _rpc;
  final Future<void> Function() _connect;
  final void Function() _close;
  final Future<ProfileDiscovery> Function() discover;
  StreamCallback? onEvent;
  ConnectionCallback? onConnectionChanged;

  ProfileGateway({
    required this.scope,
    required ScopedGet get,
    required ScopedRpc rpc,
    required this.discover,
    Future<void> Function()? connect,
    void Function()? close,
  }) : _get = get,
       _rpc = rpc,
       _connect = connect ?? _nothing,
       _close = close ?? _noop;

  static Future<void> _nothing() async {}
  static void _noop() {}

  factory ProfileGateway.forConnection(
    SavedConnection connection,
    WorkspaceScope scope,
  ) {
    if (scope.connectionId != connection.id) {
      throw ArgumentError('Connection does not own this workspace');
    }
    final dashboard = DashboardClient(
      host: connection.host,
      port: connection.dashboardPort,
      useHttps: connection.useHttps,
      pathPrefix: connection.dashboardPrefix ?? '',
      proxied: connection.dashboardProxied,
      username: connection.dashboardUsername,
      password: connection.dashboardPassword,
    );
    WsClient? socket;
    var connected = false;
    Future<void>? connecting;
    late final ProfileGateway gateway;
    Future<void> open() async {
      final credentials = await dashboard.gatewayCredentials();
      final candidate = WsClient(
        connection.desktopGatewayUrl ?? dashboard.baseUrl,
        token: credentials.token,
        ticket: credentials.ticket,
      );
      candidate.onStreamEvent = (event) => gateway.onEvent?.call(event);
      candidate.onConnectionChanged = (value) {
        connected = value;
        gateway.onConnectionChanged?.call(value);
      };
      try {
        await candidate.connect();
        await candidate.waitForGatewayReady();
        socket = candidate;
      } catch (_) {
        candidate.close();
        rethrow;
      }
    }

    gateway = ProfileGateway(
      scope: scope,
      get: (endpoint, query) => dashboard
          .apiGet(endpoint, queryParameters: query)
          .timeout(const Duration(seconds: 20)),
      rpc: (method, params) async {
        final current = socket;
        if (current == null) throw StateError('Gateway is not connected');
        final envelope = await current.send(method, params);
        final error = envelope['error'];
        if (error is Map) {
          throw JsonRpcError.fromGateway(
            method,
            error,
            fallbackMessage: 'Gateway request failed',
          );
        }
        final result = envelope['result'];
        if (result is! Map) throw const FormatException('Missing RPC result');
        return Map<String, dynamic>.from(result);
      },
      discover: () => ProfilesRepository(
        dashboard.apiGet,
      ).discover().timeout(const Duration(seconds: 20)),
      connect: () =>
          connecting ??
          (connected && socket != null
              ? Future<void>.value()
              : connecting = (() async {
                  socket?.close();
                  socket = null;
                  try {
                    await open();
                  } finally {
                    connecting = null;
                  }
                })()),
      close: () {
        socket?.close();
        dashboard.close();
      },
    );
    return gateway;
  }

  Future<void> connect() => _connect();
  void close() => _close();

  /// Revalidate immediately before writes. Stock servers can still have a
  /// deletion-after-validation race; client validation cannot fix that race.
  Future<void> requireProfile() async {
    if ((await discover()).named(scope.profileName) == null) {
      throw StateError('Profile ${scope.profileName} is no longer available');
    }
  }

  Future<Map<String, dynamic>> read(
    String endpoint, [
    Map<String, String> query = const {},
  ]) => _get(endpoint, {...query, 'profile': scope.profileName});

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) => _rpc(method, {...params, 'profile': scope.profileName});

  static const sessionPageSize = 50;
  static const projectSessionScanLimit = 5000;

  Future<ProfileSessionPage> sessions({
    int offset = 0,
    int limit = sessionPageSize,
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('Invalid session page');
    }
    final result = await read('sessions', {
      'limit': '$limit',
      'offset': '$offset',
      'order': 'recent',
    });
    if (result['offset'] != offset ||
        result['limit'] != limit ||
        result['total'] is! int ||
        (result['total'] as int) < 0) {
      throw const FormatException('Invalid session pagination metadata');
    }
    final rows = records(result['sessions']);
    for (final row in rows) {
      if (row['profile'] != scope.profileName ||
          row['id'] is! String ||
          (row['id'] as String).isEmpty) {
        throw const FormatException(
          'Session response has a different profile owner',
        );
      }
    }
    return ProfileSessionPage(
      rows: rows,
      offset: offset,
      limit: limit,
      total: result['total'] as int,
    );
  }

  Future<List<Map<String, dynamic>>> projects() async {
    final rows = records(
      (await call('projects.tree', {'preview_limit': 0}))['projects'],
    );
    final projects = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row['isNoProject'] == true) continue;
      if (row['id'] is! String ||
          row['label'] is! String ||
          row['lastActive'] is! num) {
        throw const FormatException('Invalid project overview');
      }
      projects.add({...row, 'name': row['label'], 'primary_path': row['path']});
    }
    projects.sort(
      (a, b) => (b['lastActive'] as num).compareTo(a['lastActive'] as num),
    );
    return projects;
  }

  Future<List<Map<String, dynamic>>> projectSessions(String projectId) async {
    await requireProfile();
    final result = await call('projects.project_sessions', {
      'project_id': projectId,
      'session_limit': projectSessionScanLimit,
    });
    final project = result['project'];
    if (project is! Map || project['id'] != projectId) {
      throw StateError('Project is no longer available');
    }
    final rows = <String, Map<String, dynamic>>{};
    for (final repo in records(project['repos'])) {
      for (final group in records(repo['groups'])) {
        for (final session in records(group['sessions'])) {
          if (session['profile'] != scope.profileName ||
              session['id'] is! String) {
            throw const FormatException('Invalid project session owner');
          }
          rows[session['id'] as String] = session;
        }
      }
    }
    return rows.values.toList();
  }

  Future<Map<String, dynamic>> createSession({
    String? cwd,
    String? title,
  }) async {
    await requireProfile();
    return _ownedSession(
      await call('session.create', {
        'source': 'desktop',
        'close_on_disconnect': false,
        'cwd': ?cwd,
        'title': ?title,
      }),
    );
  }

  Future<Map<String, dynamic>> resume(String durableId) async {
    await requireProfile();
    return _ownedSession(
      await call('session.resume', {'session_id': durableId}),
    );
  }

  Map<String, dynamic> _ownedSession(Map<String, dynamic> result) {
    if (result['info'] is! Map ||
        result['info']['profile_name'] != scope.profileName) {
      throw const FormatException(
        'Session response has a different profile owner',
      );
    }
    if (result['session_id'] is! String ||
        (result['session_id'] as String).isEmpty) {
      throw const FormatException('Session response has no runtime identity');
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> history(String id) async => records(
    (await read('sessions/${Uri.encodeComponent(id)}/messages', {
      'limit': '500',
      'order': 'oldest',
    }))['messages'],
  );

  Future<Map<String, dynamic>> createProject(String name, String path) async {
    await requireProfile();
    final result = await call('projects.create', {
      'name': name,
      'folders': [path],
      'primary_path': path,
    });
    if (result['project'] is! Map) {
      throw const FormatException('Missing project');
    }
    return Map<String, dynamic>.from(result['project']);
  }

  static List<Map<String, dynamic>> records(Object? value) {
    if (value is! List || value.any((row) => row is! Map)) {
      throw const FormatException('Expected a list of records');
    }
    return value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}
