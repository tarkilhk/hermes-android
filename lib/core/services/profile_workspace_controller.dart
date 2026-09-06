import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attachment_draft.dart';
import '../models/hermes_profile.dart';
import 'attachment_draft_service.dart';
import 'connection_manager.dart';
import 'profile_gateway.dart';
import 'profile_selection_store.dart';
import 'profiles_repository.dart';
import 'ws_client.dart';

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
  final String? projectId;
  String draft = '';
  String streaming = '';
  String? tool;
  String? error;
  Map<String, dynamic>? approval;
  Map<String, dynamic>? clarification;
  List<Map<String, dynamic>> messages = [];
  String? historySessionId;
  int? nextHistoryOffset;
  int historyGeneration = 0;
  bool historyLoading = false;
  String? historyError;
  double historyScrollOffset = 0;
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
  final ProfileGateway gateway;
  List<Map<String, dynamic>> sessions = [];
  int? nextSessionOffset;
  bool sessionsLoadingMore = false;
  String? sessionsPageError;
  int sessionGeneration = 0;
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
    pendingProfile = name;
    error = null;
    _changed();
    try {
      final profiles = await target.gateway.discover();
      if (profiles.named(name) == null) {
        throw StateError('Profile $name is no longer available');
      }
      await target.gateway.connect();
      final sessions = await target.gateway.sessions();
      List<Map<String, dynamic>> projects = [];
      String? projectError;
      try {
        projects = await target.gateway.projects();
      } catch (_) {
        projectError = 'Projects are unavailable for $name. Retry to reload.';
      }
      if (_closed || generation != _generation) return false;
      _clearSearch(target);
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
      final page = await resource.gateway.sessions(offset: offset);
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
    final page = await resource.gateway.sessions();
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

  Future<ProfileChat> createChat() async {
    final resource = _writable();
    final project = resource.selectedProject;
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
    resource.selectedSession = id;
    _changed();
    return chat;
  }

  Future<void> openSession(ProfileSessionKey key) async {
    if (!owns(key)) {
      throw ArgumentError('Wrong connection settings or host');
    }
    if (current?.scope != key.workspace &&
        !await switchProfile(key.workspace.profileName)) {
      return;
    }
    final resource = _resource(key.workspace.profileName);
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
      _hydrate(chat, response);
    }
    // The user may have navigated again while resume was in flight.
    if (current == resource && !switching) {
      resource.selectedSession = key.sessionId;
    }
    _changed();
    if (current?.chat == chat) await refreshHistory(chat);
  }

  void showList() {
    _cancelOlderLoads();
    current?.selectedSession = null;
    _changed();
  }

  Future<void> selectProject(Map<String, dynamic>? project) {
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

  Future<void> send(ProfileChat chat) async {
    final resource = _owned(chat);
    if (chat.busy || (chat.draft.trim().isEmpty && chat.attachments.isEmpty)) {
      return;
    }
    final text = chat.draft.trim();
    chat.lastActive = DateTime.now().millisecondsSinceEpoch / 1000;
    final files = List<AttachmentDraft>.of(chat.attachments);
    chat.status = ProfileTurnStatus.submitting;
    chat.error = null;
    _changed();
    var submitted = false;
    try {
      await resource.gateway.requireProfile();
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
          chat.messages.add({'role': 'user', 'content': text});
          chat.streaming = '';
          chat.draft = '';
          chat.attachments.clear();
          chat.status = ProfileTurnStatus.running;
          if (chat.title == 'New chat') {
            chat.title = text.isEmpty ? 'Attachment' : text;
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

  Future<void> clarify(ProfileChat chat, String answer) async {
    final resource = _owned(chat);
    final request = chat.clarification;
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
