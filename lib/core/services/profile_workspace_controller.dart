import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attachment_draft.dart';
import '../models/answer_versions.dart';
import '../models/hermes_profile.dart';
import '../models/slash_command.dart';
import 'attachment_draft_service.dart';
import 'connection_manager.dart';
import 'profile_gateway.dart';
import 'profile_selection_store.dart';
import 'profiles_repository.dart';
import 'ws_client.dart';
import 'chat_model_override_store.dart';
import '../widgets/chat_intelligence_picker.dart';

class ProfileSessionKey {
  final WorkspaceScope workspace;
  final String sessionId;
  const ProfileSessionKey(this.workspace, this.sessionId);
  Map<String, String> toJson() => {
    'connection': workspace.connectionId,
    'connection_identity': workspace.connectionIdentity,
    'profile': workspace.profileName,
    'session': sessionId,
  };
  factory ProfileSessionKey.fromJson(Map<String, dynamic> value) {
    final id = value['session'];
    final identity = value['connection_identity'];
    if (id is! String ||
        id.isEmpty ||
        identity is! String ||
        identity.isEmpty) {
      throw const FormatException('Missing session or connection ownership');
    }
    return ProfileSessionKey(
      WorkspaceScope(
        connectionId: value['connection'] as String,
        connectionIdentity: identity,
        profileName: value['profile'] as String,
      ),
      id,
    );
  }
  @override
  bool operator ==(Object other) =>
      other is ProfileSessionKey &&
      workspace == other.workspace &&
      sessionId == other.sessionId;
  @override
  int get hashCode => Object.hash(workspace, sessionId);
}

enum ProfileTurnStatus {
  idle,
  submitting,
  running,
  attention,
  reconnecting,
  settling,
  completed,
  cancelled,
  failed,
}

class ProfileChat {
  final ProfileSessionKey key;
  String runtimeId;
  String title;
  double lastActive = DateTime.now().millisecondsSinceEpoch / 1000;
  String? projectId;
  String? model;
  String? provider;
  String? reasoningEffort;
  bool changingIntelligence = false;
  String? intelligenceRuntime;
  String draft = '';
  String streaming = '';
  String? tool;
  String? error;
  bool changingAnswer = false;
  bool commandRunning = false;
  final List<String> commandOutput = [];
  Map<String, dynamic>? approval;
  Map<String, dynamic>? clarification;
  List<Map<String, dynamic>> messages = [];
  String? historySessionId;
  int? nextHistoryOffset;
  int historyGeneration = 0;
  bool historyLoading = false;
  String? historyError;
  double historyScrollOffset = 0;
  bool archived = false;
  final List<AttachmentDraft> attachments = [];
  ProfileTurnStatus status = ProfileTurnStatus.idle;
  ProfileChat({
    required this.key,
    required this.runtimeId,
    required this.title,
    this.projectId,
  });

  /// Stock Hermes can send a single question or a batch with per-question locks.
  /// A resumed batch includes answers already locked on the server.
  Map<String, dynamic>? get pendingQuestion {
    final request = clarification;
    if (request == null) return null;
    if (request['questions'] is! List) return request;
    final answered = request['answers'] is Map ? request['answers'] as Map : {};
    for (final question in ProfileGateway.records(request['questions'])) {
      final id = question['qid'];
      if (id is String && !answered.containsKey(id)) {
        return {
          ...question,
          'request_id': request['request_id'],
          'question_id': id,
        };
      }
    }
    return null;
  }

  bool get busy => {
    ProfileTurnStatus.submitting,
    ProfileTurnStatus.running,
    ProfileTurnStatus.attention,
    ProfileTurnStatus.reconnecting,
    ProfileTurnStatus.settling,
  }.contains(status);
}

class ProfileWorkspaceData {
  Future<SlashCatalog>? commandCatalog;
  final ProfileGateway gateway;
  List<Map<String, dynamic>> sessions = [];
  int? nextSessionOffset;
  bool sessionsLoadingMore = false;
  String? sessionsPageError;
  int sessionGeneration = 0;
  bool archivedOnly = false;
  final Set<String> mutatingSessions = {};
  final Set<String> deletedSessions = {};
  String searchQuery = '';
  List<Map<String, dynamic>> searchResults = [];
  bool searchLoading = false;
  String? searchError;
  int searchGeneration = 0;
  List<Map<String, dynamic>> projects = [];
  String? projectsError;
  final Map<String, ProfileChat> chats = {};
  String? selectedSession;
  Map<String, dynamic>? selectedProject;
  List<Map<String, dynamic>> projectSessions = [];
  String? projectSessionsError;
  bool projectSessionsLoading = false;
  int projectGeneration = 0;
  int reconnectAttempt = 0;
  Timer? retry;
  bool reconnecting = false;
  List<AnswerVersionGroup> answerVersions = [];
  ProfileWorkspaceData(this.gateway);
  WorkspaceScope get scope => gateway.scope;
  ProfileChat? get chat => chats[selectedSession];
  List<Map<String, dynamic>> get visibleSessions =>
      selectedProject == null ? sessions : projectSessions;
}

typedef ProfileGatewayFactory = ProfileGateway Function(WorkspaceScope scope);
typedef ProfileAttention =
    Future<void> Function(ProfileChat chat, bool needsInput);

/// Owned by the application, not the workspace/chat widgets. A foreground
/// switch never closes a socket, changes a chat owner, or cancels a turn.
class ProfileWorkspaceController extends ChangeNotifier {
  final SavedConnection connection;
  final String connectionIdentity;
  final SharedPreferences preferences;
  final ProfileGatewayFactory _factory;
  final AttachmentDraftService attachments;
  final ProfileAttention? onAttention;
  final Map<WorkspaceScope, ProfileWorkspaceData> _resources = {};
  final Set<ProfileSessionKey> _unrestoredPending = {};
  ProfileDiscovery? discovery;
  ProfileWorkspaceData? current;
  String? pendingProfile;
  String? error;
  bool visible = false;
  int _generation = 0;
  int _navigationGeneration = 0;
  bool _closed = false;
  Future<void> _journalQueue = Future.value();

  ProfileWorkspaceController({
    required this.connection,
    required this.connectionIdentity,
    required this.preferences,
    ProfileGatewayFactory? gatewayFactory,
    AttachmentDraftService? attachmentService,
    this.onAttention,
  }) : _factory =
           gatewayFactory ??
           ((scope) => ProfileGateway.forConnection(connection, scope)),
       attachments = attachmentService ?? AttachmentDraftService() {
    if (connectionIdentity.isEmpty) {
      throw ArgumentError('A verified connection identity is required');
    }
  }

  Iterable<ProfileChat> get activity => _resources.values
      .expand((r) => r.chats.values)
      .where((chat) => chat.status != ProfileTurnStatus.idle);
  bool get switching => pendingProfile != null;
  String get _journalKey => 'profile_pending_v2_$connectionIdentity';

  bool owns(ProfileSessionKey key) =>
      key.workspace.connectionId == connection.id &&
      key.workspace.connectionIdentity == connectionIdentity;

  void _changed() {
    if (!_closed) notifyListeners();
  }

  ProfileWorkspaceData _resource(String name) {
    final scope = WorkspaceScope(
      connectionId: connection.id,
      connectionIdentity: connectionIdentity,
      profileName: name,
    );
    return _resources.putIfAbsent(scope, () {
      final resource = ProfileWorkspaceData(_factory(scope));
      resource.answerVersions = AnswerVersionGroup.decode(
        preferences.getString(_versionsKey(resource)),
      );
      resource.gateway.onEvent = (event) => _event(resource, event);
      resource.gateway.onConnectionChanged = (connected) {
        if (!connected && !_closed) {
          for (final chat in resource.chats.values.where((c) => c.busy)) {
            chat.status = ProfileTurnStatus.reconnecting;
          }
          _scheduleReconnect(resource);
          _changed();
        }
      };
      return resource;
    });
  }

  Future<void> initialize() async {
    try {
      // This temporary owner is used only for host-level discovery, not data.
      discovery = await _resource('default').gateway.discover();
      final initial = ProfileSelectionStore(
        preferences,
      ).resolveInitial(connectionIdentity, discovery!);
      await switchProfile(initial.name);
      await _restorePending();
    } catch (e) {
      error = e.toString();
      _changed();
    }
  }

  Future<bool> switchProfile(
    String name, {
    bool resetNavigation = false,
  }) async {
    final generation = ++_generation;
    if (current != null) _clearSearch(current!);
    _cancelOlderLoads();
    if (current != null) _invalidateSessionLoad(current!);
    final target = _resource(name);
    if (target != current) _invalidateSessionLoad(target);
    final sessionReadGeneration = target.sessionGeneration;
    pendingProfile = name;
    error = null;
    _changed();
    try {
      final profiles = await target.gateway.discover();
      if (profiles.named(name) == null) {
        throw StateError('Profile $name is no longer available');
      }
      await target.gateway.connect();
      final archivedOnly = resetNavigation ? false : target.archivedOnly;
      final sessions = await target.gateway.sessions(
        archivedOnly: archivedOnly,
      );
      List<Map<String, dynamic>> projects = [];
      String? projectError;
      try {
        projects = await target.gateway.projects();
      } catch (_) {
        projectError = 'Projects are unavailable for $name. Retry to reload.';
      }
      if (_closed || generation != _generation) return false;
      if (sessionReadGeneration != target.sessionGeneration) {
        throw StateError('Chats changed while loading. Refresh to reload.');
      }
      _clearSearch(target);
      target.archivedOnly = archivedOnly;
      _replaceSessions(target, sessions);
      target.projects = projects;
      target.projectsError = projectError;
      if (resetNavigation) {
        target.selectedSession = null;
        target.selectedProject = null;
        target.projectGeneration++;
        target.projectSessions = [];
        target.projectSessionsLoading = false;
        target.projectSessionsError = null;
      }
      final selectedId = target.selectedProject?['id'];
      if (selectedId != null) {
        final selected = projects
            .where((p) => p['id'] == selectedId)
            .firstOrNull;
        if (selected != null) {
          target.selectedProject = selected;
          unawaited(_loadProject(target, selected));
        } else {
          target.projectGeneration++;
          target.projectSessionsLoading = false;
          target.projectSessions = [];
          target.projectSessionsError = 'The selected project is unavailable.';
        }
      }
      discovery = profiles;
      current = target;
      pendingProfile = null;
      await ProfileSelectionStore(preferences).write(connectionIdentity, name);
      _changed();
      return true;
    } catch (e) {
      if (!_closed && generation == _generation) {
        pendingProfile = null;
        error = e.toString();
        _changed();
      }
      return false;
    }
  }

  Future<void> refresh() async {
    final resource = current;
    if (resource == null) {
      await initialize();
      return;
    }
    resource.commandCatalog = null;
    await switchProfile(resource.scope.profileName);
    if (_unrestoredPending.isNotEmpty) await _restorePending();
  }

  /// Profile navigation always enters that profile's root tree, never a stale
  /// project or chat retained from an earlier visit. Running owners are kept.
  Future<void> navigateProfile(String name) async {
    await switchProfile(name, resetNavigation: true);
  }

  void _invalidateSessionLoad(ProfileWorkspaceData resource) {
    resource.sessionGeneration++;
    resource.sessionsLoadingMore = false;
  }

  void _clearSearch(ProfileWorkspaceData resource) {
    resource.searchGeneration++;
    resource.searchQuery = '';
    resource.searchResults = [];
    resource.searchLoading = false;
    resource.searchError = null;
  }

  void clearSearch() {
    if (current != null) _clearSearch(current!);
    _changed();
  }

  Future<void> searchChats(String query) async {
    final resource = current;
    if (resource == null || switching || _closed) return;
    _clearSearch(resource);
    final generation = resource.searchGeneration;
    resource.searchQuery = query.trim().toLowerCase();
    if (resource.searchQuery.isEmpty) {
      _changed();
      return;
    }
    resource.searchLoading = true;
    _changed();
    bool valid() =>
        !_closed &&
        current == resource &&
        !switching &&
        generation == resource.searchGeneration;
    try {
      final rows = await resource.gateway.search(resource.searchQuery);
      if (valid()) resource.searchResults = rows;
    } catch (_) {
      if (valid()) {
        resource.searchError =
            'Search failed. Retry without changing your query.';
      }
    } finally {
      if (valid()) {
        resource.searchLoading = false;
        _changed();
      }
    }
  }

  void _cancelOlderLoads() {
    for (final resource in _resources.values) {
      for (final chat in resource.chats.values) {
        chat.historyGeneration++;
        chat.historyLoading = false;
      }
    }
  }

  /// Read-only transcript hydration, also usable without attaching a runtime.
  Future<void> refreshHistory(ProfileChat chat) async {
    final resource = _owned(chat);
    final generation = ++chat.historyGeneration;
    chat.historyLoading = true;
    chat.historyError = null;
    _changed();
    try {
      final page = await resource.gateway.history(chat.key.sessionId);
      if (_closed || chat.historyGeneration != generation) return;
      final anchor =
          page.rows.isEmpty || chat.historySessionId != page.sessionId
          ? -1
          : chat.messages.indexWhere((r) => r['id'] == page.rows.first['id']);
      final prefix = anchor > 0
          ? chat.messages.take(anchor).toList()
          : <Map<String, dynamic>>[];
      chat.messages = [...prefix, ...page.rows];
      chat.historySessionId = page.sessionId;
      chat.nextHistoryOffset = page.nextOffset == null
          ? null
          : chat.messages.length;
      await _refreshAnswerIds(chat);
    } catch (_) {
      if (!_closed && chat.historyGeneration == generation) {
        chat.historyError = 'History could not be loaded. Retry to reload.';
      }
    } finally {
      if (!_closed && chat.historyGeneration == generation) {
        chat.historyLoading = false;
        _changed();
      }
    }
  }

  Future<void> loadOlderMessages(ProfileChat chat) async {
    final resource = _owned(chat);
    if (_closed ||
        switching ||
        current?.chat != chat ||
        chat.historyLoading ||
        chat.nextHistoryOffset == null) {
      return;
    }
    final generation = chat.historyGeneration;
    final offset = chat.nextHistoryOffset!;
    chat.historyLoading = true;
    chat.historyError = null;
    _changed();
    bool valid() =>
        !_closed &&
        !switching &&
        current?.chat == chat &&
        chat.historyGeneration == generation;
    try {
      final page = await resource.gateway.history(
        chat.historySessionId!,
        offset: offset,
      );
      if (!valid()) return;
      if (page.sessionId != chat.historySessionId) {
        throw StateError('History moved to a new segment');
      }
      final ids = chat.messages.map((r) => r['id']).toSet();
      final oldest =
          chat.messages.where((r) => r['id'] is int).firstOrNull?['id'] as int?;
      final older = page.rows
          .where(
            (r) =>
                !ids.contains(r['id']) &&
                (oldest == null || (r['id'] as int) < oldest),
          )
          .toList();
      chat.messages = [...older, ...chat.messages];
      chat.nextHistoryOffset = page.nextOffset;
    } catch (_) {
      if (valid()) {
        chat.historyError =
            'Older messages could not be loaded. Retry or refresh history.';
      }
    } finally {
      if (valid()) {
        chat.historyLoading = false;
        _changed();
      }
    }
  }

  void _replaceSessions(
    ProfileWorkspaceData resource,
    ProfileSessionPage page,
  ) {
    resource.sessions = _mergeSessionRows([], page.rows);
    resource.nextSessionOffset = page.nextOffset;
    resource.sessionsPageError = null;
  }

  List<Map<String, dynamic>> _mergeSessionRows(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> incoming,
  ) => <String, Map<String, dynamic>>{
    for (final row in previous) row['id'] as String: row,
    for (final row in incoming) row['id'] as String: row,
  }.values.toList();

  /// A navigation or refresh invalidates publication, not the owning socket or
  /// any running turn. A failed page keeps its offset and existing rows for retry.
  Future<void> loadMoreSessions() async {
    final resource = current;
    if (_closed ||
        switching ||
        resource == null ||
        resource.selectedProject != null ||
        resource.sessionsLoadingMore ||
        resource.nextSessionOffset == null) {
      return;
    }
    final generation = resource.sessionGeneration;
    final offset = resource.nextSessionOffset!;
    resource.sessionsLoadingMore = true;
    resource.sessionsPageError = null;
    _changed();
    bool valid() =>
        !_closed &&
        current == resource &&
        !switching &&
        generation == resource.sessionGeneration;
    try {
      final page = await resource.gateway.sessions(
        offset: offset,
        archivedOnly: resource.archivedOnly,
      );
      if (!valid()) return;
      resource.sessions = _mergeSessionRows(resource.sessions, page.rows);
      resource.nextSessionOffset = page.nextOffset;
    } catch (_) {
      if (valid()) {
        resource.sessionsPageError = 'More chats could not be loaded. Retry.';
      }
    } finally {
      if (valid()) {
        resource.sessionsLoadingMore = false;
        _changed();
      }
    }
  }

  Future<void> _refreshSessions(ProfileWorkspaceData resource) async {
    _invalidateSessionLoad(resource);
    final generation = resource.sessionGeneration;
    final page = await resource.gateway.sessions(
      archivedOnly: resource.archivedOnly,
    );
    if (!_closed && generation == resource.sessionGeneration) {
      _replaceSessions(resource, page);
    }
  }

  ProfileWorkspaceData _writable() {
    if (switching || current == null) {
      throw StateError('Wait for profile loading');
    }
    return current!;
  }

  Future<ProfileChat> createChat({
    Map<String, dynamic>? inProject,
    WorkspaceScope? owner,
  }) async {
    _navigationGeneration++;
    final resource = _writable();
    if (owner != null && owner != resource.scope) {
      throw StateError('Profile changed. Open the menu again.');
    }
    final project = inProject ?? resource.selectedProject;
    if (project != null && !resource.projects.contains(project)) {
      throw ArgumentError('Wrong project owner');
    }
    final response = await resource.gateway.createSession(
      cwd: project?['primary_path'] as String?,
    );
    final id = response['stored_session_id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Missing durable session identity');
    }
    final chat = ProfileChat(
      key: ProfileSessionKey(resource.scope, id),
      runtimeId: response['session_id'] as String,
      title: 'New chat',
      projectId: project?['id'] as String?,
    );
    resource.chats[id] = chat;
    _hydrateIntelligence(chat, response);
    if (current == resource && !switching) resource.selectedSession = id;
    _changed();
    return chat;
  }

  Future<void> openSession(ProfileSessionKey key) async {
    final navigation = ++_navigationGeneration;
    if (!owns(key)) {
      throw ArgumentError('Wrong connection settings or host');
    }
    if (current?.scope != key.workspace &&
        !await switchProfile(key.workspace.profileName)) {
      return;
    }
    final resource = _resource(key.workspace.profileName);
    if (resource.deletedSessions.contains(key.sessionId)) {
      throw StateError('Chat was deleted');
    }
    _cancelOlderLoads();
    var chat = resource.chats[key.sessionId];
    if (chat == null) {
      final response = await resource.gateway.resume(key.sessionId);
      chat = ProfileChat(
        key: key,
        runtimeId: response['session_id'] as String,
        title:
            [
                  ...resource.searchResults,
                  ...resource.visibleSessions,
                  ...resource.sessions,
                ]
                .where((s) => s['id'] == key.sessionId)
                .firstOrNull?['title']
                ?.toString() ??
            'Chat',
      );
      resource.chats[key.sessionId] = chat;
      chat.archived =
          resource.archivedOnly ||
          resource.searchResults.any(
            (row) => row['id'] == key.sessionId && row['archived'] == true,
          );
      if (resource.deletedSessions.contains(key.sessionId)) {
        resource.chats.remove(key.sessionId);
        return;
      }
      _hydrate(chat, response);
    }
    // The user may have navigated again while resume was in flight.
    if (current == resource &&
        !switching &&
        navigation == _navigationGeneration) {
      resource.selectedSession = key.sessionId;
    }
    _changed();
    if (current?.chat == chat) await refreshHistory(chat);
  }

  void showList() {
    _navigationGeneration++;
    _cancelOlderLoads();
    current?.selectedSession = null;
    _changed();
  }

  Future<void> showArchived(bool archived) async {
    final resource = _writable();
    final previous = resource.archivedOnly;
    final rows = resource.sessions;
    final offset = resource.nextSessionOffset;
    resource.archivedOnly = archived;
    resource.selectedProject = null;
    resource.projectGeneration++;
    resource.projectSessionsLoading = false;
    _clearSearch(resource);
    resource.sessions = [];
    resource.nextSessionOffset = null;
    _changed();
    final archiveReadGeneration = resource.sessionGeneration + 1;
    try {
      await _refreshSessions(resource);
    } catch (_) {
      if (resource.sessionGeneration == archiveReadGeneration) {
        resource.archivedOnly = previous;
        resource.sessions = rows;
        resource.nextSessionOffset = offset;
      }
      rethrow;
    } finally {
      _changed();
    }
  }

  Future<void> mutateSession(
    ProfileSessionKey key, {
    Map<String, dynamic> changes = const {},
    bool delete = false,
  }) async {
    final resource = _writable();
    if (!owns(key) || resource.scope != key.workspace) {
      throw StateError('Profile changed. Open the menu again.');
    }
    final id = key.sessionId;
    if (resource.mutatingSessions.contains(id)) return;
    final chat = resource.chats[id];
    if ((delete || changes.containsKey('archived')) && chat?.busy == true) {
      throw StateError(
        'Wait for this chat to finish before archiving or deleting.',
      );
    }
    resource.mutatingSessions.add(id);
    _changed();
    try {
      Map<String, dynamic> updated = changes;
      if (delete) {
        await resource.gateway.deleteSession(id);
      } else {
        final result = await resource.gateway.updateSession(id, changes);
        updated = {
          ...changes,
          if (changes.containsKey('title')) 'title': result['title'],
        };
      }
      if (_closed) return;
      _invalidateSessionLoad(resource);
      if (delete || changes.containsKey('archived')) {
        resource.nextSessionOffset = 0;
      }
      resource.projectGeneration++;
      resource.projectSessionsLoading = false;
      resource.searchGeneration++;
      resource.searchLoading = false;
      void apply(List<Map<String, dynamic>> rows, {bool search = false}) {
        for (var index = 0; index < rows.length; index++) {
          if (rows[index]['id'] == id) {
            rows[index] = {...rows[index], ...updated};
          }
        }
        rows.removeWhere(
          (row) =>
              row['id'] == id &&
              (delete ||
                  (!search &&
                      changes.containsKey('archived') &&
                      changes['archived'] != resource.archivedOnly)),
        );
      }

      apply(resource.sessions);
      apply(resource.projectSessions);
      apply(resource.searchResults, search: true);
      if (delete) {
        resource.deletedSessions.add(id);
        resource.chats.remove(id);
      } else if (chat != null) {
        if (updated['title'] is String) chat.title = updated['title'] as String;
        if (updated['archived'] is bool) {
          chat.archived = updated['archived'] as bool;
        }
      }
      if (resource.selectedSession == id &&
          (delete || changes['archived'] == true)) {
        resource.selectedSession = null;
      }
    } finally {
      resource.mutatingSessions.remove(id);
      _changed();
    }
  }

  Future<bool> moveSessionToProject(
    ProfileSessionKey key,
    Map<String, dynamic> project,
  ) async {
    final resource = _writable();
    if (!owns(key) || resource.scope != key.workspace) {
      throw StateError('Profile changed. Open the menu again.');
    }
    if (!resource.projects.contains(project) ||
        project['isNoProject'] == true ||
        ProfileGateway.projectDirectory(project).isEmpty) {
      throw StateError('Project is unavailable. Open the menu again.');
    }
    final id = key.sessionId;
    if (resource.mutatingSessions.contains(id)) return false;
    if (resource.chats[id]?.busy == true) {
      throw StateError('Wait for this chat to finish before moving.');
    }
    resource.mutatingSessions.add(id);
    _changed();
    try {
      final updated = await resource.gateway.moveSession(
        id,
        ProfileGateway.projectDirectory(project),
      );
      if (_closed) return true;
      _invalidateSessionLoad(resource);
      resource.searchGeneration++;
      resource.searchLoading = false;
      resource.projectGeneration++;
      resource.projectSessionsLoading = false;
      for (final rows in [
        resource.sessions,
        resource.projectSessions,
        resource.searchResults,
      ]) {
        for (var index = 0; index < rows.length; index++) {
          if (rows[index]['id'] == id) {
            rows[index] = {...rows[index], ...updated};
          }
        }
      }
      resource.chats[id]?.projectId = project['id'] as String;
      // Do not leave a moved row in its old folder while the tree reloads.
      if (resource.selectedProject?['id'] != project['id']) {
        resource.projectSessions.removeWhere((row) => row['id'] == id);
      }
      _changed();
      final navigation = _generation;
      final generation = resource.projectGeneration;
      bool valid() =>
          !_closed &&
          current == resource &&
          !switching &&
          navigation == _generation &&
          generation == resource.projectGeneration;
      try {
        final projects = await resource.gateway.projects();
        if (valid()) {
          resource.projects = projects;
          resource.projectsError = null;
          final selectedId = resource.selectedProject?['id'];
          if (selectedId != null) {
            final selected = projects
                .where((p) => p['id'] == selectedId)
                .firstOrNull;
            if (selected != null) {
              resource.selectedProject = selected;
              await _loadProject(resource, selected);
            } else {
              resource.projectSessions = [];
              resource.projectSessionsError =
                  'The selected project is unavailable.';
            }
          }
        }
      } catch (_) {
        if (valid()) {
          resource.projectsError = 'Chat moved. Refresh to reload projects.';
        }
      }
      return true;
    } finally {
      resource.mutatingSessions.remove(id);
      _changed();
    }
  }

  Future<void> selectProject(Map<String, dynamic>? project) {
    _navigationGeneration++;
    final resource = _writable();
    if (project != null && !resource.projects.contains(project)) {
      throw ArgumentError('Wrong project owner');
    }
    _invalidateSessionLoad(resource);
    _clearSearch(resource);
    resource.selectedProject = project;
    resource.selectedSession = null;
    resource.projectSessions = [];
    resource.projectSessionsError = null;
    resource.projectGeneration++;
    resource.projectSessionsLoading = false;
    _changed();
    return project == null ? Future.value() : _loadProject(resource, project);
  }

  Future<void> _loadProject(
    ProfileWorkspaceData resource,
    Map<String, dynamic> project,
  ) async {
    final generation = ++resource.projectGeneration;
    resource.projectSessionsLoading = true;
    _changed();
    try {
      final rows = await resource.gateway.projectSessions(
        project['id'] as String,
      );
      if (_closed || generation != resource.projectGeneration) return;
      resource.projectSessions = rows;
      resource.projectSessionsError = null;
    } catch (e) {
      if (_closed || generation != resource.projectGeneration) return;
      resource.projectSessions = [];
      resource.projectSessionsError = e.toString();
    } finally {
      if (!_closed && generation == resource.projectGeneration) {
        resource.projectSessionsLoading = false;
        _changed();
      }
    }
  }

  Future<void> createProject(String name, String path) async {
    final resource = _writable();
    await resource.gateway.createProject(name, path);
    resource.projects = await resource.gateway.projects();
    _changed();
  }

  Future<void> addAttachment(ProfileChat chat, String path, String name) async {
    _owned(chat);
    if (chat.busy) throw StateError('Wait for the current turn');
    final image = RegExp(
      r'\.(png|jpe?g|webp)$',
      caseSensitive: false,
    ).hasMatch(name);
    final draft = image
        ? await attachments.prepareImage(
            sourcePath: path,
            displayName: name,
            existingDrafts: chat.attachments,
            mode: AttachmentDraftMode.remoteGateway,
          )
        : await attachments.prepareGenericFile(
            sourcePath: path,
            displayName: name,
            existingDrafts: chat.attachments,
          );
    chat.attachments.add(draft);
    _changed();
  }

  Future<void> removeAttachment(ProfileChat chat, AttachmentDraft draft) async {
    _owned(chat);
    if (chat.busy) return;
    chat.attachments.remove(draft);
    await attachments.removeCachedFile(draft);
    _changed();
  }

  ProfileWorkspaceData _owned(ProfileChat chat) {
    final resource = _resources[chat.key.workspace];
    if (resource == null ||
        !identical(resource.chats[chat.key.sessionId], chat)) {
      throw ArgumentError('Chat does not belong to this controller');
    }
    return resource;
  }

  String _versionsKey(ProfileWorkspaceData resource) =>
      'answer_versions_v1_${resource.scope.storageNamespace}';

  AnswerVersionGroup? answerVersionsForMessage(
    ProfileChat chat,
    Map<String, dynamic> message,
  ) {
    final id = answerMessageId(message);
    if (id == null) return null;
    return _owned(chat).answerVersions
        .where((g) => g.answerIds[chat.key.sessionId] == id)
        .firstOrNull;
  }

  Future<void> _refreshAnswerIds(ProfileChat chat) async {
    final resource = _owned(chat);
    final groups = resource.answerVersions
        .where((g) => g.selections.containsKey(chat.key.sessionId))
        .toList();
    if (groups.isEmpty) return;
    final history = await resource.gateway.fullHistory(chat.runtimeId);
    var ordinal = -1;
    final answers = <int, int>{};
    for (final message in history) {
      if (isAnswerPrompt(message)) ordinal++;
      final id = answerMessageId(message);
      if (message['role'] == 'assistant' &&
          isBranchMessage(message) &&
          id != null) {
        answers[ordinal] = id;
      }
    }
    var changed = false;
    for (final group in groups) {
      final id = answers[group.userOrdinal];
      if (id != null && group.answerIds[chat.key.sessionId] != id) {
        group.answerIds[chat.key.sessionId] = id;
        changed = true;
      }
    }
    if (changed &&
        !await preferences.setString(
          _versionsKey(resource),
          jsonEncode(resource.answerVersions.map((g) => g.toJson()).toList()),
        )) {
      throw StateError('Could not save answer positions');
    }
  }

  AnswerVersionGroup? answerVersions(ProfileChat chat, int userOrdinal) =>
      _owned(chat).answerVersions
          .where(
            (group) =>
                group.userOrdinal == userOrdinal &&
                group.selections.containsKey(chat.key.sessionId),
          )
          .firstOrNull;

  Future<void> selectAnswer(
    ProfileChat chat,
    AnswerVersionGroup group,
    int index,
  ) async {
    final resource = _owned(chat);
    if (chat.busy ||
        chat.changingAnswer ||
        chat.changingIntelligence ||
        switching) {
      return;
    }
    if (!resource.answerVersions.contains(group) ||
        !group.selections.containsKey(chat.key.sessionId) ||
        index < 0 ||
        index >= group.sessions.length) {
      throw ArgumentError('Unknown answer version');
    }
    chat.changingAnswer = true;
    _changed();
    try {
      await openSession(
        ProfileSessionKey(resource.scope, group.sessions[index]),
      );
    } finally {
      chat.changingAnswer = false;
      _changed();
    }
  }

  /// Fork before regenerating so no operation rewrites the source transcript.
  Future<ProfileChat?> branchAnswer(
    ProfileChat source,
    int messageIndex, {
    bool regenerate = false,
  }) async {
    final resource = _owned(source);
    if (source.busy ||
        source.changingAnswer ||
        source.changingIntelligence ||
        switching) {
      return null;
    }
    if (messageIndex < 0 || messageIndex >= source.messages.length) {
      throw ArgumentError('Unknown answer');
    }
    final selected = source.messages[messageIndex];
    final selectedId = answerMessageId(selected);
    if (selectedId == null) {
      throw StateError('Wait for this answer to be saved');
    }
    final navigation = _navigationGeneration;
    final profileGeneration = _generation;
    source.changingAnswer = true;
    _changed();
    try {
      // Address the saved row, even when only the newest history page is visible.
      final history = await resource.gateway.fullHistory(source.runtimeId);
      final targetIndex = history.indexWhere(
        (m) => answerMessageId(m) == selectedId,
      );
      final target = AnswerTarget.at(history, targetIndex);
      if (target == null ||
          answerMessageText(history[targetIndex]) !=
              answerMessageText(selected)) {
        throw StateError(
          'History changed. Reconnect to reload before branching.',
        );
      }
      if (regenerate && target.userOrdinal < 0) {
        throw StateError('This answer has no saved prompt to regenerate');
      }
      final expected = history
          .take(targetIndex + 1)
          .where(isBranchMessage)
          .toList();
      final result = await resource.gateway.branch(
        source.runtimeId,
        target.branchCount,
      );
      final id = result['stored_session_id'];
      if (id is! String ||
          id.isEmpty ||
          id == source.key.sessionId ||
          resource.chats.containsKey(id)) {
        throw const FormatException(
          'Branch has no new durable session identity',
        );
      }
      final child = ProfileChat(
        key: ProfileSessionKey(resource.scope, id),
        runtimeId: result['session_id'] as String,
        projectId: source.projectId,
        title: regenerate
            ? source.title
            : result['title']?.toString() ?? '${source.title} branch',
      );
      _hydrate(child, result);
      child.messages = answerHistoryRows(
        ProfileGateway.records(result['messages']),
      );
      resource.chats[id] = child;
      // Retain the returned child even on validation failure, so it is reachable.
      resource.sessions.insert(0, {
        'id': id,
        'title': child.title,
        'profile': resource.scope.profileName,
      });
      final copied = child.messages.where(isBranchMessage).toList();
      if (copied.length != expected.length ||
          List.generate(expected.length, (i) => i).any(
            (i) =>
                copied[i]['role'] != expected[i]['role'] ||
                answerMessageText(copied[i]) != answerMessageText(expected[i]),
          )) {
        throw StateError(
          'The gateway did not copy the requested answer boundary. The original is unchanged.',
        );
      }
      if (regenerate) {
        final snapshot = jsonEncode(
          resource.answerVersions.map((g) => g.toJson()).toList(),
        );
        var group = answerVersions(source, target.userOrdinal);
        // Earlier answers are inherited by this continuation. Their controls
        // must still be available when another, later answer is regenerated.
        for (final earlier in resource.answerVersions.where(
          (g) => g.userOrdinal < target.userOrdinal,
        )) {
          final selected = earlier.selections[source.key.sessionId];
          if (selected != null) earlier.selections[id] = selected;
        }
        if (group == null) {
          group = AnswerVersionGroup(
            target.userOrdinal,
            [source.key.sessionId],
            {source.key.sessionId: 0},
          );
          resource.answerVersions.add(group);
        }
        group.selections[id] = group.sessions.length;
        group.sessions.add(id);
        group.answerIds[source.key.sessionId] = selectedId;
        try {
          if (!await preferences.setString(
            _versionsKey(resource),
            jsonEncode(resource.answerVersions.map((g) => g.toJson()).toList()),
          )) {
            throw StateError('Could not save answer links');
          }
        } catch (_) {
          resource.answerVersions = AnswerVersionGroup.decode(snapshot);
          rethrow;
        }
      }
      if (current == resource &&
          resource.chat == source &&
          navigation == _navigationGeneration &&
          profileGeneration == _generation &&
          !switching) {
        resource.selectedSession = id;
      }
      _changed();
      if (regenerate && !await _regenerate(child, target)) {
        // A rejected request produced no alternate answer. Keep the standalone
        // child reachable in Chats, but do not count a copy as a new version.
        for (final group in resource.answerVersions) {
          group.selections.remove(id);
          group.answerIds.remove(id);
          final index = group.sessions.indexOf(id);
          if (index >= 0) {
            group.sessions.removeAt(index);
            group.selections.updateAll(
              (_, selected) => selected > index ? selected - 1 : selected,
            );
          }
        }
        resource.answerVersions.removeWhere(
          (group) => group.sessions.length < 2,
        );
        if (!await preferences.setString(
          _versionsKey(resource),
          jsonEncode(resource.answerVersions.map((g) => g.toJson()).toList()),
        )) {
          throw StateError(
            'Regeneration failed and answer links could not be updated',
          );
        }
        if (current == resource &&
            resource.chat == child &&
            navigation == _navigationGeneration &&
            profileGeneration == _generation) {
          resource.selectedSession = source.key.sessionId;
        }
        throw StateError(child.error ?? 'Regeneration failed');
      }
      if (!regenerate) await refreshHistory(child);
      return child;
    } finally {
      source.changingAnswer = false;
      _changed();
    }
  }

  Future<bool> _regenerate(ProfileChat chat, AnswerTarget target) async {
    final resource = _owned(chat);
    chat.status = ProfileTurnStatus.submitting;
    _changed();
    var submitted = false;
    var rejected = false;
    final original = chat.messages;
    try {
      await resource.gateway.requireProfile();
      final history = await resource.gateway.fullHistory(chat.runtimeId);
      final users = history.where(isAnswerPrompt).toList();
      if (target.userOrdinal >= users.length ||
          answerMessageText(users[target.userOrdinal]) != target.prompt) {
        throw StateError(
          'Could not locate the original prompt in the new session',
        );
      }
      final prompt = users[target.userOrdinal];
      final rowId = prompt['row_id'];
      if (rowId is! int || rowId <= 0) {
        throw StateError(
          'The gateway did not return a saved prompt address for regeneration',
        );
      }
      await _journal();
      chat.messages = answerHistoryRows(
        history.take(history.indexOf(prompt) + 1).toList(),
      );
      chat.streaming = '';
      chat.status = ProfileTurnStatus.running;
      submitted = true;
      _changed();
      await resource.gateway.call('prompt.submit', {
        'session_id': chat.runtimeId,
        'text': target.prompt,
        'truncate_before_row_id': rowId,
        'confirm_truncate': true,
        'confirm_empty_truncate': true,
      });
    } catch (e) {
      if (e is JsonRpcError || !submitted) {
        rejected = true;
        chat.messages = original;
        chat.status = ProfileTurnStatus.failed;
        chat.error = 'Could not regenerate: $e';
      } else {
        chat.status = ProfileTurnStatus.reconnecting;
        chat.error =
            'Regeneration status is uncertain. Reconnect to check history.';
        _scheduleReconnect(resource);
      }
    }
    await _journal();
    _changed();
    return !rejected;
  }

  String _intelligenceOwner(ProfileChat chat) =>
      jsonEncode([connectionIdentity, chat.key.workspace.profileName]);

  ChatModelOverride? _savedIntelligence(ProfileChat chat) =>
      ChatModelOverrideStore(preferences).read(
        connectionIdentity: _intelligenceOwner(chat),
        sessionId: chat.key.sessionId,
      );

  void _hydrateIntelligence(ProfileChat chat, Map<String, dynamic> response) {
    final info = response['info'];
    if (info is Map) {
      chat.model = info['model']?.toString() ?? chat.model;
      chat.provider = info['provider']?.toString() ?? chat.provider;
      chat.reasoningEffort =
          info['reasoning_effort']?.toString() ?? chat.reasoningEffort;
    }
    final saved = _savedIntelligence(chat);
    if (saved != null) {
      chat.model = saved.model;
      chat.provider = saved.provider;
      chat.reasoningEffort = saved.reasoningEffort;
    }
  }

  /// Reads and writes always use this chat's immutable profile owner and live ID.
  Future<
    ({
      List<ChatModelChoice> choices,
      String defaultModel,
      String? defaultProvider,
    })
  >
  loadIntelligence(ProfileChat chat) async {
    final gateway = _owned(chat).gateway;
    final results = await Future.wait([
      gateway.read('model/info'),
      gateway.read('model/options'),
      gateway.call('config.get', {
        'session_id': chat.runtimeId,
        'key': 'reasoning',
      }),
    ]);
    final defaults = results[0];
    final choices = <ChatModelChoice>[];
    for (final provider in ProfileGateway.records(results[1]['providers'])) {
      final slug = (provider['slug'] ?? provider['id'])?.toString() ?? '';
      if (slug.isEmpty || provider['models'] is! List) continue;
      for (final value in provider['models'] as List) {
        final model = value is String
            ? value
            : value is Map
            ? (value['id'] ?? value['model'] ?? value['name'])?.toString()
            : null;
        if (model != null && model.trim().isNotEmpty) {
          choices.add(ChatModelChoice(provider: slug, model: model.trim()));
        }
      }
    }
    if (choices.isEmpty) {
      throw StateError('This profile returned no selectable models.');
    }
    chat.model ??= defaults['model']?.toString();
    chat.provider ??= defaults['provider']?.toString();
    chat.reasoningEffort =
        _savedIntelligence(chat)?.reasoningEffort ??
        WsClient.normalizeReasoningEffort(results[2]['value']);
    _changed();
    return (
      choices: choices,
      defaultModel: defaults['model']?.toString() ?? 'Default',
      defaultProvider: defaults['provider']?.toString(),
    );
  }

  Future<void> _writeIntelligence(
    ProfileChat chat,
    ChatIntelligenceSelection selection,
  ) async {
    final gateway = _owned(chat).gateway;
    if (!WsClient.validReasoningEfforts.contains(selection.reasoningEffort)) {
      throw ArgumentError('Unsupported reasoning effort');
    }
    await gateway.requireProfile();
    final runtime = chat.runtimeId;
    final result = await gateway.call('config.set', {
      'session_id': runtime,
      'key': 'model',
      'value': WsClient.buildSessionModelValue(
        provider: selection.choice.provider,
        model: selection.choice.model,
      ),
    });
    if (result['confirm_required'] == true) {
      throw StateError(
        result['confirm_message']?.toString() ?? 'Model needs confirmation.',
      );
    }
    if (chat.runtimeId != runtime) {
      throw StateError('Chat reconnected. Try applying again.');
    }
    chat.model = selection.choice.model;
    chat.provider = selection.choice.provider;
    // Save the acknowledged model even if the separate reasoning request fails.
    await _saveIntelligence(chat);
    await gateway.call('config.set', {
      'session_id': runtime,
      'key': 'reasoning',
      'value': selection.reasoningEffort,
    });
    if (chat.runtimeId != runtime) {
      throw StateError('Chat reconnected. Try applying again.');
    }
    chat.reasoningEffort = selection.reasoningEffort;
    await _saveIntelligence(chat);
    chat.intelligenceRuntime = runtime;
  }

  Future<void> _saveIntelligence(ProfileChat chat) =>
      ChatModelOverrideStore(preferences).save(
        connectionIdentity: _intelligenceOwner(chat),
        sessionId: chat.key.sessionId,
        provider: chat.provider!,
        model: chat.model!,
        reasoningEffort: chat.reasoningEffort,
      );

  Future<void> setIntelligence(
    ProfileChat chat,
    ChatIntelligenceSelection selection,
  ) async {
    _owned(chat);
    if (chat.busy ||
        chat.changingAnswer ||
        chat.changingIntelligence ||
        switching ||
        current?.chat != chat) {
      throw StateError(
        'Wait for this chat to be ready before changing its model.',
      );
    }
    chat.changingIntelligence = true;
    _changed();
    try {
      await _writeIntelligence(chat, selection);
    } finally {
      chat.changingIntelligence = false;
      _changed();
    }
  }

  Future<void> _restoreIntelligence(ProfileChat chat) async {
    final saved = _savedIntelligence(chat);
    if (saved == null || chat.intelligenceRuntime == chat.runtimeId) return;
    await _writeIntelligence(
      chat,
      ChatIntelligenceSelection(
        choice: ChatModelChoice(provider: saved.provider, model: saved.model),
        reasoningEffort: saved.reasoningEffort ?? 'medium',
      ),
    );
  }

  Future<SlashCatalog> commandCatalog(ProfileChat chat) {
    final resource = _owned(chat);
    return resource.commandCatalog ??= (() async {
      try {
        return SlashCatalog.fromJson(
          await resource.gateway.call('commands.catalog', {
            'session_id': chat.runtimeId,
          }),
        );
      } catch (_) {
        resource.commandCatalog = null;
        rethrow;
      }
    })();
  }

  Future<Map<String, dynamic>> completeCommand(ProfileChat chat, String text) =>
      _owned(chat).gateway.call('complete.slash', {
        'session_id': chat.runtimeId,
        'text': text,
      });

  Future<void> send(ProfileChat chat) async {
    if (chat.commandRunning || chat.changingIntelligence || switching) return;
    if (chat.draft.trimLeft().startsWith('/')) {
      await _sendCommand(chat);
      return;
    }
    await _sendPrompt(chat);
  }

  Future<void> _sendCommand(ProfileChat chat) async {
    if (chat.changingAnswer) return;
    final invocation = SlashInvocation.parse(chat.draft);
    if (invocation == null) {
      chat.error = 'Choose a command or enter its name after /.';
      _changed();
      return;
    }
    final resource = _owned(chat);
    final original = chat.draft;
    chat.commandRunning = true;
    chat.error = null;
    _changed();
    try {
      await resource.gateway.requireProfile();
      final catalog = await commandCatalog(chat);
      var name = catalog.resolve(invocation.name);
      var argument = invocation.argument;
      final visited = <String>{};
      while (true) {
        if (!visited.add(name) || visited.length > 16) {
          throw StateError('Command alias cycle');
        }
        // Session navigation belongs to the phone; slash workers own a different
        // CLI session and must never create, rename or select it on our behalf.
        if (await _localCommand(chat, name, argument)) {
          chat.draft = '';
          break;
        }
        final unavailable = catalog.unavailable(name);
        if (unavailable != null) throw StateError(unavailable);
        if (chat.busy) {
          throw StateError(
            'Wait for the current turn or stop it before running /$name.',
          );
        }
        Map<String, dynamic> result;
        try {
          result = await resource.gateway.call('command.dispatch', {
            'session_id': chat.runtimeId,
            'name': name,
            'arg': argument,
          });
        } on JsonRpcError catch (e) {
          // This exact refusal means dispatch did not execute anything. Never
          // retry a timeout or a command failure through another execution path.
          if (e.code != 4018 ||
              !e.message.startsWith(
                'not a quick/plugin/bundle/skill command:',
              )) {
            rethrow;
          }
          result = await resource.gateway.call('slash.exec', {
            'session_id': chat.runtimeId,
            'command': '/$name${argument.isEmpty ? '' : ' $argument'}',
          });
        }
        final type = result['type'];
        if (type == 'alias') {
          final target = result['target'] as String? ?? '';
          final alias = SlashInvocation.parse(
            '${target.startsWith('/') ? '' : '/'}$target',
          );
          if (alias == null) {
            throw const FormatException('Invalid command alias');
          }
          name = catalog.resolve(alias.name);
          argument = [
            alias.argument,
            argument,
          ].where((s) => s.isNotEmpty).join(' ');
          continue;
        }
        for (final key in ['notice', 'warning', 'output']) {
          final line = result[key];
          if (line is String && line.isNotEmpty) chat.commandOutput.add(line);
        }
        if (type == 'skill' || type == 'send' || type == 'prefill') {
          final message = result['message'];
          if (message is! String || message.isEmpty) {
            throw const FormatException('Command returned an empty prompt');
          }
          if (type == 'prefill') {
            chat.draft = message;
            // /undo changes server history. Read through the runtime owner.
            await refreshHistory(chat);
          } else {
            await _sendPrompt(
              chat,
              prompt: message,
              display: result['display'] as String? ?? original,
            );
          }
        } else if ((type == null || type == 'exec' || type == 'plugin') &&
            result['output'] is String) {
          if (chat.attachments.isNotEmpty) {
            chat.commandOutput.add(
              'Attachments remain in the composer for your next message.',
            );
          }
          chat.draft = '';
          try {
            await refreshHistory(chat);
            await _refreshSessions(resource);
          } catch (_) {
            chat.commandOutput.add(
              'Command finished. Refresh to reload history.',
            );
          }
        } else {
          throw FormatException('Unsupported command response: $type');
        }
        break;
      }
    } catch (e) {
      chat.error = e is TimeoutException
          ? 'Command status is uncertain. It was not retried. Check the session before running it again.'
          : e.toString();
    } finally {
      chat.commandRunning = false;
      _changed();
    }
  }

  Future<bool> _localCommand(
    ProfileChat chat,
    String name,
    String argument,
  ) async {
    final resource = _owned(chat);
    switch (name) {
      case 'new':
      case 'reset':
        if (current != resource || current?.chat != chat || switching) {
          throw StateError('Return to this chat to create a session.');
        }
        await createChat();
      case 'profile':
        if (argument.isEmpty) {
          chat.commandOutput.add('Profile: ${resource.scope.profileName}');
        } else if (current == resource && current?.chat == chat && !switching) {
          if (!await switchProfile(argument)) {
            throw StateError(error ?? 'Profile switch failed');
          }
        } else {
          throw StateError('Return to this chat to switch profiles.');
        }
      case 'sessions':
      case 'resume':
      case 'switch':
        if (current != resource || current?.chat != chat || switching) {
          throw StateError('Return to this chat to select a session.');
        }
        if (argument.isEmpty) {
          showList();
        } else {
          final matches = resource.sessions
              .where((s) => s['id'] == argument || s['title'] == argument)
              .toList();
          if (matches.length != 1) {
            throw StateError(
              'Choose a session from Chats, or use its exact ID or title.',
            );
          }
          await openSession(
            ProfileSessionKey(resource.scope, matches.single['id'] as String),
          );
        }
      case 'title':
        if (argument.isEmpty) {
          chat.commandOutput.add(chat.title);
          break;
        }
        final result = await resource.gateway.call('session.title', {
          'session_id': chat.runtimeId,
          'title': argument,
        });
        chat.title = result['title'] as String? ?? argument;
        chat.commandOutput.add('Session title: ${chat.title}');
      case 'branch':
      case 'fork':
        if (chat.busy || switching) {
          throw StateError('Wait for the current turn before branching.');
        }
        final index = chat.messages.lastIndexWhere(
          (m) => m['role'] == 'assistant' && isBranchMessage(m),
        );
        if (index < 0) {
          throw StateError('Send a message before branching this chat.');
        }
        final child = await branchAnswer(chat, index);
        if (child == null) throw StateError('Could not branch this chat.');
        if (argument.isNotEmpty) {
          final result = await resource.gateway.call('session.title', {
            'session_id': child.runtimeId,
            'title': argument,
          });
          child.title = result['title'] as String? ?? argument;
        }
      case 'save':
        final result = await resource.gateway.call('session.save', {
          'session_id': chat.runtimeId,
        });
        final file = result['file'];
        if (file is! String || file.isEmpty) {
          throw const FormatException(
            'The server did not return the saved file path.',
          );
        }
        chat.commandOutput.add('Saved on the Hermes host: $file');
      case 'status':
        final result = await resource.gateway.call('session.status', {
          'session_id': chat.runtimeId,
        });
        chat.commandOutput.add(
          result['output'] as String? ?? 'Status unavailable.',
        );
      case 'history':
        await refreshHistory(chat);
        chat.commandOutput.add('Conversation history refreshed.');
      case 'bg':
      case 'background':
      case 'btw':
        if (argument.isEmpty) throw StateError('Usage: /$name <message>');
        await resource.gateway.call(
          name == 'btw' ? 'prompt.btw' : 'prompt.background',
          {'session_id': chat.runtimeId, 'text': argument},
        );
        chat.commandOutput.add('Started /$name on the Hermes host.');
      case 'stop':
      case 'interrupt':
        await stop(chat);
        chat.commandOutput.add('Interrupt requested.');
        if (name == 'stop') {
          final result = await resource.gateway.call('process.stop');
          chat.commandOutput.add(
            'Background processes stopped: ${result['killed']}',
          );
        }
      case 'skills':
        if (argument.isNotEmpty && argument != 'list') return false;
        final catalog = await commandCatalog(chat);
        chat.commandOutput.add(
          catalog.commands
              .where((c) => c.category.toLowerCase().contains('skill'))
              .map((c) => '${c.text}  ${c.description}')
              .join('\n'),
        );
        if (catalog.warning.isNotEmpty) chat.commandOutput.add(catalog.warning);
      case 'help':
      case 'commands':
        final catalog = await commandCatalog(chat);
        chat.commandOutput.add(
          catalog.commands.map((c) => '${c.text}  ${c.description}').join('\n'),
        );
        if (catalog.warning.isNotEmpty) chat.commandOutput.add(catalog.warning);
      case 'steer':
        if (argument.isEmpty) throw StateError('Usage: /steer <message>');
        await resource.gateway.call('session.steer', {
          'session_id': chat.runtimeId,
          'text': argument,
        });
        chat.commandOutput.add('Steering message sent.');
      default:
        return false;
    }
    return true;
  }

  Future<void> _sendPrompt(
    ProfileChat chat, {
    String? prompt,
    String? display,
  }) async {
    final resource = _owned(chat);
    if (chat.busy ||
        chat.changingAnswer ||
        chat.changingIntelligence ||
        ((prompt ?? chat.draft).trim().isEmpty && chat.attachments.isEmpty)) {
      return;
    }
    final text = prompt ?? chat.draft.trim();
    chat.lastActive = DateTime.now().millisecondsSinceEpoch / 1000;
    final files = List<AttachmentDraft>.of(chat.attachments);
    chat.status = ProfileTurnStatus.submitting;
    chat.error = null;
    _changed();
    var submitted = false;
    try {
      await resource.gateway.requireProfile();
      await _restoreIntelligence(chat);
      // Persist only ownership and status. No prompt text, paths or credentials.
      await _journal();
      await AttachmentDraftSendCoordinator(attachments).uploadThenSubmit(
        drafts: files,
        upload: ({required draft, required dataUrl}) async {
          final result = await resource.gateway.call('file.attach', {
            'session_id': chat.runtimeId,
            'name': draft.name,
            'data_url': dataUrl,
          });
          final ref = result['ref_text'];
          if (ref is! String || ref.isEmpty) {
            throw const FormatException('Missing attachment reference');
          }
          return AttachmentUploadReceipt(refText: ref);
        },
        onChanged: (_) => _changed(),
        submitPrompt: (refs) async {
          await resource.gateway.requireProfile();
          chat.messages.add({
            'role': 'user',
            'content': text,
            'display_content': ?display,
          });
          chat.streaming = '';
          chat.draft = '';
          chat.attachments.clear();
          chat.status = ProfileTurnStatus.running;
          if (chat.title == 'New chat') {
            chat.title = display ?? (text.isEmpty ? 'Attachment' : text);
          }
          submitted = true;
          _changed();
          await resource.gateway.call('prompt.submit', {
            'session_id': chat.runtimeId,
            'text': [text, ...refs].where((s) => s.isNotEmpty).join('\n\n'),
          });
        },
      );
      await attachments.removeAll(files);
    } catch (e) {
      chat.error = submitted
          ? 'Delivery or completion is uncertain. Reconnect to check history. The prompt will not be resent.'
          : e.toString();
      chat.status = submitted
          ? ProfileTurnStatus.reconnecting
          : ProfileTurnStatus.failed;
      if (submitted) _scheduleReconnect(resource);
    }
    await _journal();
    _changed();
  }

  Future<void> stop(ProfileChat chat) async => _owned(
    chat,
  ).gateway.call('session.interrupt', {'session_id': chat.runtimeId});

  Future<void> approve(ProfileChat chat, String choice) async {
    if (!{'once', 'deny'}.contains(choice)) {
      throw ArgumentError('Unsupported approval');
    }
    await _owned(chat).gateway.call('approval.respond', {
      'session_id': chat.runtimeId,
      'choice': choice,
    });
    chat.approval = null;
    chat.status = ProfileTurnStatus.running;
    _changed();
  }

  Future<void> clarify(
    ProfileChat chat,
    String answer, {
    Map<String, dynamic>? expectedRequest,
  }) async {
    final resource = _owned(chat);
    final request = chat.clarification;
    if (expectedRequest != null && !identical(expectedRequest, request)) {
      throw StateError(
        'This question has changed. Review the current question.',
      );
    }
    final question = chat.pendingQuestion;
    if (question == null) return;
    final result = await resource.gateway.call('clarify.respond', {
      'session_id': chat.runtimeId,
      'request_id': question['request_id'],
      'answer': answer,
      if (question['question_id'] != null)
        'question_id': question['question_id'],
    });
    if (!identical(chat.clarification, request)) return;
    if (result['status'] == 'expired') {
      await reconnect(resource.scope);
      chat.error =
          'This input request expired. Your answer was not submitted again.';
    } else if (result['remaining'] is List &&
        (result['remaining'] as List).isNotEmpty) {
      chat.clarification = {
        ...request!,
        'answers': {
          if (request['answers'] is Map)
            ...Map<String, dynamic>.from(request['answers'] as Map),
          question['question_id'] as String: answer,
        },
      };
      chat.status = ProfileTurnStatus.attention;
    } else {
      chat.clarification = null;
      if (chat.status == ProfileTurnStatus.attention) {
        chat.status = ProfileTurnStatus.running;
      }
    }
    _changed();
  }

  void _event(ProfileWorkspaceData resource, StreamEvent event) {
    if (_closed) return;
    final chat = resource.chats.values
        .where((c) => c.runtimeId == event.sessionId)
        .firstOrNull;
    if (chat == null) return;
    switch (event.type) {
      case 'message.delta':
        chat.streaming += event.data['text']?.toString() ?? '';
      case 'message.interim':
        final text = event.data['text']?.toString() ?? chat.streaming;
        if (text.isNotEmpty) {
          chat.messages.add({'role': 'assistant', 'content': text});
        }
        chat.streaming = '';
      case 'tool.start':
        chat.tool =
            event.data['name']?.toString() ??
            event.data['tool']?.toString() ??
            'Working';
      case 'tool.complete':
        chat.tool = null;
      case 'btw.complete':
      case 'background.complete':
        chat.commandOutput.add(
          event.data['text']?.toString() ?? 'Background command finished.',
        );
        _notify(chat, false);
      case 'approval.request':
        chat.approval = event.data;
        chat.status = ProfileTurnStatus.attention;
        _notify(chat, true);
      case 'clarify.request':
        chat.clarification = event.data;
        chat.status = ProfileTurnStatus.attention;
        _notify(chat, true);
      case 'message.complete':
      case 'turn.end':
        if (chat.busy && chat.status != ProfileTurnStatus.settling) {
          unawaited(
            _settle(resource, chat, event.data).catchError((Object e) {
              chat.error = e.toString();
              _changed();
            }),
          );
        }
      case 'error':
      case 'turn.error':
        chat.status = ProfileTurnStatus.failed;
        chat.error = event.data['message']?.toString() ?? 'Turn failed';
        _notify(chat, true);
        unawaited(_journal().catchError((Object _) {}));
    }
    _changed();
  }

  Future<void> _settle(
    ProfileWorkspaceData resource,
    ProfileChat chat,
    Map<String, dynamic> completion,
  ) async {
    chat.status = ProfileTurnStatus.settling;
    final failed = completion['status'] == 'error';
    final cancelled = completion['status'] == 'interrupted';
    final failure = failed
        ? (completion['error'] ?? completion['text'] ?? 'Turn failed')
              .toString()
        : null;
    chat.tool = null;
    chat.approval = null;
    chat.clarification = null;
    final finalText = completion['text']?.toString() ?? chat.streaming;
    if (finalText.isNotEmpty) {
      chat.messages.add({'role': 'assistant', 'content': finalText});
    }
    chat.streaming = '';
    chat.error = failure;
    try {
      await refreshHistory(chat);
      if (chat.historyError != null) throw StateError('History refresh failed');
      if (!switching) await _refreshSessions(resource);
      try {
        resource.projects = await resource.gateway.projects();
        final selectedId = resource.selectedProject?['id'];
        if (selectedId != null) {
          resource.selectedProject =
              resource.projects
                  .where((project) => project['id'] == selectedId)
                  .firstOrNull ??
              resource.selectedProject;
        }
        resource.projectsError = null;
      } catch (_) {
        resource.projectsError =
            'Projects could not be refreshed. Retry to reload.';
      }
      final project = resource.selectedProject;
      if (project != null) await _loadProject(resource, project);
    } catch (_) {
      chat.error =
          failure ??
          'Turn finished. History refresh failed; reconnect to reload.';
    }
    chat.status = failed
        ? ProfileTurnStatus.failed
        : cancelled
        ? ProfileTurnStatus.cancelled
        : ProfileTurnStatus.completed;
    await _journal();
    _notify(chat, failed);
    _changed();
  }

  void _notify(ProfileChat chat, bool attention) {
    if (visible && current?.chat == chat) return;
    final callback = onAttention;
    if (callback != null) {
      unawaited(callback(chat, attention).catchError((Object _) {}));
    }
  }

  void _scheduleReconnect(ProfileWorkspaceData resource) {
    if (_closed ||
        resource.retry != null ||
        resource.reconnecting ||
        resource.reconnectAttempt >= 5) {
      return;
    }
    resource.retry = Timer(
      Duration(seconds: 1 << resource.reconnectAttempt++),
      () {
        resource.retry = null;
        unawaited(reconnect(resource.scope));
      },
    );
  }

  Future<void> reconnect(WorkspaceScope scope) async {
    final resource = _resources[scope];
    if (resource == null || resource.reconnecting || _closed) return;
    resource.reconnecting = true;
    try {
      await resource.gateway.connect();
      for (final chat in resource.chats.values.toList()) {
        if (!chat.busy && chat != resource.chat) continue;
        final wasBusy = chat.busy;
        _hydrate(chat, await resource.gateway.resume(chat.key.sessionId));
        await refreshHistory(chat);
        if (wasBusy && !chat.busy) {
          _notify(chat, chat.status == ProfileTurnStatus.failed);
        }
      }
      resource.reconnectAttempt = 0;
      await _journal();
    } catch (_) {
      error =
          'Could not reconnect to ${scope.profileName}. No prompts were resent.';
    } finally {
      resource.reconnecting = false;
      _changed();
      if (resource.chats.values.any(
        (c) => c.status == ProfileTurnStatus.reconnecting,
      )) {
        _scheduleReconnect(resource);
      }
    }
  }

  void _hydrate(ProfileChat chat, Map<String, dynamic> result) {
    final wasBusy = chat.busy;
    chat.runtimeId = result['session_id'] as String;
    _hydrateIntelligence(chat, result);
    final inflight = result['inflight'] as Map?;
    chat.streaming = inflight?['assistant']?.toString() ?? '';
    chat.approval = result['pending_approval'] is Map
        ? Map<String, dynamic>.from(result['pending_approval'])
        : null;
    chat.clarification = result['pending_clarify'] is Map
        ? Map<String, dynamic>.from(result['pending_clarify'])
        : null;
    final failed = inflight?['status'] == 'error';
    chat.status = failed
        ? ProfileTurnStatus.failed
        : chat.approval != null || chat.clarification != null
        ? ProfileTurnStatus.attention
        : result['running'] == true
        ? ProfileTurnStatus.running
        : wasBusy
        ? ProfileTurnStatus.completed
        : ProfileTurnStatus.idle;
    chat.error = failed
        ? (inflight?['error']?.toString() ?? 'Turn failed')
        : null;
  }

  Future<void> _journal() {
    final snapshot = {
      ..._unrestoredPending,
      ...activity.where((c) => c.busy).map((c) => c.key),
    }.map((key) => jsonEncode(key.toJson())).toList();
    final write = _journalQueue.then((_) async {
      if (!await preferences.setStringList(_journalKey, snapshot)) {
        throw StateError('Could not save pending chat owners');
      }
    });
    _journalQueue = write.catchError((Object _) {});
    return write;
  }

  Future<void> _restorePending() async {
    for (final raw in preferences.getStringList(_journalKey) ?? <String>[]) {
      try {
        final key = ProfileSessionKey.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (!owns(key)) continue;
        _unrestoredPending.add(key);
      } catch (_) {
        error = 'A saved pending chat identity could not be read.';
      }
    }
    // Keep every unresolved owner in subsequent journal snapshots, even if its
    // profile is unavailable while another profile starts or settles a turn.
    for (final key in _unrestoredPending.toList()) {
      try {
        final resource = _resource(key.workspace.profileName);
        if (resource.chats.containsKey(key.sessionId)) {
          _unrestoredPending.remove(key);
          continue;
        }
        await resource.gateway.connect();
        final result = await resource.gateway.resume(key.sessionId);
        final chat = ProfileChat(
          key: key,
          runtimeId: result['session_id'] as String,
          title: 'Restored chat',
        )..status = ProfileTurnStatus.reconnecting;
        _hydrate(chat, result);
        resource.chats[key.sessionId] = chat;
        await refreshHistory(chat);
        _unrestoredPending.remove(key);
        if (!chat.busy) _notify(chat, chat.status == ProfileTurnStatus.failed);
      } catch (_) {
        error =
            'Some pending chats could not be restored. No prompts were resent.';
      }
    }
    await _journal();
    _changed();
  }

  @override
  void dispose() {
    _closed = true;
    for (final resource in _resources.values) {
      resource.retry?.cancel();
      resource.gateway.close();
    }
    super.dispose();
  }
}
