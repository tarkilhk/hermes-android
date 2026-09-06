import 'dart:async';

import 'package:flutter/material.dart';

import '../services/profile_workspace_controller.dart';

/// The reference-inspired navigation tree. All rows come from its immutable
/// profile owner; project membership remains the server's decision.
class ProfileWorkspaceBrowser extends StatefulWidget {
  final ProfileWorkspaceController controller;
  final Future<void> Function() newProject;
  final Future<void> Function()? enableNotifications;
  const ProfileWorkspaceBrowser({
    super.key,
    required this.controller,
    required this.newProject,
    this.enableNotifications,
  });
  @override
  State<ProfileWorkspaceBrowser> createState() =>
      _ProfileWorkspaceBrowserState();
}

class _ProfileWorkspaceBrowserState extends State<ProfileWorkspaceBrowser> {
  ProfileWorkspaceController get controller => widget.controller;
  String _query = '';
  String _view = 'home';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete that action. Please retry.'),
          ),
        );
      }
    }
  }

  void _back() {
    if (controller.switching) return;
    if (controller.current?.selectedProject != null) {
      unawaited(controller.selectProject(null));
    } else if (_view != 'home') {
      setState(() => _view = 'home');
    } else {
      Navigator.maybePop(context);
    }
    _search.clear();
    setState(() => _query = '');
  }

  static num _activity(Map<String, dynamic> row) =>
      (row['last_active'] ?? row['started_at']) is num
      ? (row['last_active'] ?? row['started_at']) as num
      : 0;

  String _age(Map<String, dynamic> row) {
    final time = _activity(row);
    if (time <= 0) return '';
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch((time * 1000).round()),
    );
    if (age.inMinutes < 1) return 'now';
    if (age.inHours < 1) return '${age.inMinutes}m';
    if (age.inDays < 1) return '${age.inHours}h';
    if (age.inDays < 7) return '${age.inDays}d';
    return '${age.inDays ~/ 7}w';
  }

  Widget _heading(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        ?action,
      ],
    ),
  );

  Widget _project(Map<String, dynamic> project) => ListTile(
    key: ValueKey('project-${project['id']}'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    minTileHeight: 52,
    leading: const Icon(Icons.folder_outlined, size: 23),
    minLeadingWidth: 22,
    title: Text(
      project['name'] as String,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 16),
    ),
    onTap: controller.switching
        ? null
        : () {
            _search.clear();
            setState(() {
              _query = '';
              _view = 'home';
            });
            unawaited(_run(() => controller.selectProject(project)));
          },
  );

  Widget _session(Map<String, dynamic> row) {
    final resource = controller.current!;
    final local = resource.chats[row['id']];
    final title = row['title']?.toString().trim();
    return ListTile(
      key: ValueKey('chat-${row['id']}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minTileHeight: 52,
      title: Text(
        title?.isNotEmpty == true ? title! : 'Untitled chat',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (local?.busy == true)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                local?.status == ProfileTurnStatus.attention
                    ? Icons.help_outline
                    : Icons.more_horiz,
                size: 18,
              ),
            ),
          Text(
            _age(row),
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: controller.switching
          ? null
          : () => _run(
              () => controller.openSession(
                ProfileSessionKey(resource.scope, row['id'] as String),
              ),
            ),
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );

  List<Widget> _tree() {
    final resource = controller.current!;
    if (_view == 'activity') {
      return [
        for (final chat in controller.activity)
          ListTile(
            title: Text(
              chat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${chat.key.workspace.profileName} · ${chat.status.name}',
            ),
            onTap: () => _run(() => controller.openSession(chat.key)),
          ),
        if (controller.activity.isEmpty) _empty('No active work'),
      ];
    }
    if (_view == 'projects' && resource.selectedProject == null) {
      return [
        if (resource.projectsError != null) _empty(resource.projectsError!),
        for (final project in resource.projects.where(
          (p) => p['name'].toString().toLowerCase().contains(_query),
        ))
          _project(project),
        if (resource.projects.isEmpty && resource.projectsError == null)
          _empty('No projects in this profile'),
      ];
    }
    final project = resource.selectedProject;
    final rows = <String, Map<String, dynamic>>{
      for (final row in resource.visibleSessions) row['id'] as String: row,
    };
    for (final chat in resource.chats.values) {
      if ((project == null || chat.projectId == project['id']) &&
          !rows.containsKey(chat.key.sessionId)) {
        rows[chat.key.sessionId] = {
          'id': chat.key.sessionId,
          'title': chat.title,
          'last_active': chat.lastActive,
        };
      }
    }
    final matches =
        rows.values
            .where((r) => r['title'].toString().toLowerCase().contains(_query))
            .toList()
          ..sort((a, b) => _activity(b).compareTo(_activity(a)));
    final pinned = matches.where((r) => r['pinned'] == true).toList();
    final recent = matches.where((r) => r['pinned'] != true).toList();
    return [
      if (project == null && _query.isEmpty) ...[
        _heading(
          'Projects',
          action: resource.projects.length > 5
              ? TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _view = 'projects'),
                  child: const Text('See all'),
                )
              : null,
        ),
        if (resource.projectsError != null)
          ListTile(
            title: Text(resource.projectsError!),
            trailing: TextButton(
              onPressed: () => _run(controller.refresh),
              child: const Text('Retry'),
            ),
          )
        else if (resource.projects.isEmpty)
          _empty('No projects in this profile')
        else
          ...resource.projects.take(5).map(_project),
      ],
      if (project != null && resource.projectSessionsLoading)
        const LinearProgressIndicator(),
      if (project != null && resource.projectSessionsError != null)
        ListTile(
          title: Text(resource.projectSessionsError!),
          trailing: TextButton(
            onPressed: () => _run(() => controller.selectProject(project)),
            child: const Text('Retry'),
          ),
        ),
      if (pinned.isNotEmpty) ...[
        _heading('Pinned chats'),
        ...pinned.map(_session),
      ],
      if (project == null || pinned.isNotEmpty)
        _heading(_query.isEmpty ? 'Recents' : 'Search results'),
      ...recent.map(_session),
      if (matches.isEmpty &&
          !resource.projectSessionsLoading &&
          resource.projectSessionsError == null)
        _empty(_query.isEmpty ? 'No chats here yet' : 'No matching chats'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final resource = controller.current;
    final project = resource?.selectedProject;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xff151515) : Colors.white;
    final foreground = dark ? Colors.white : const Color(0xff171717);
    return PopScope(
      canPop: project == null && _view == 'home',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          centerTitle: project == null,
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: project == null ? 'Back' : 'Back to workspace',
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project?['name']?.toString() ??
                    (_view == 'projects'
                        ? 'All projects'
                        : _view == 'activity'
                        ? 'Activity'
                        : 'Hermes'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 21,
                ),
              ),
              Text(
                '${controller.connection.label}${project == null ? '' : ' · ${resource!.scope.profileName}'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              enabled: resource != null && !controller.switching,
              tooltip: 'Workspace options',
              onSelected: (value) {
                if (value == 'refresh') unawaited(_run(controller.refresh));
                if (value == 'new-project') unawaited(_run(widget.newProject));
                if (value == 'notifications') {
                  unawaited(_run(widget.enableNotifications!));
                }
                if (value == 'activity') {
                  unawaited(controller.selectProject(null));
                  setState(() => _view = 'activity');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                const PopupMenuItem(
                  value: 'new-project',
                  child: Text('New project'),
                ),
                const PopupMenuItem(value: 'activity', child: Text('Activity')),
                if (widget.enableNotifications != null)
                  const PopupMenuItem(
                    value: 'notifications',
                    child: Text('Enable completion notifications'),
                  ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  for (final profile in controller.discovery?.profiles ?? [])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('profile-${profile.name}'),
                        label: Text(profile.label),
                        selected: resource?.scope.profileName == profile.name,
                        showCheckmark: false,
                        selectedColor: foreground,
                        backgroundColor: dark
                            ? const Color(0xff292929)
                            : const Color(0xffeeeeee),
                        labelStyle: TextStyle(
                          color: resource?.scope.profileName == profile.name
                              ? background
                              : foreground,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: const StadiumBorder(side: BorderSide.none),
                        side: BorderSide.none,
                        onSelected: (_) {
                          _search.clear();
                          setState(() {
                            _query = '';
                            _view = 'home';
                          });
                          unawaited(
                            _run(
                              () => controller.navigateProfile(profile.name),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (controller.error != null)
              ListTile(
                title: Text(controller.error!),
                trailing: TextButton(
                  onPressed: () => _run(controller.refresh),
                  child: const Text('Retry'),
                ),
              ),
            Expanded(
              child: controller.switching || resource == null
                  ? Center(
                      child: controller.error == null
                          ? const CircularProgressIndicator()
                          : const Text('Workspace unavailable'),
                    )
                  : RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: ListView(
                        key: ValueKey(
                          '${resource.scope.storageNamespace}-${project?['id']}-$_view',
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        children: _tree(),
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _view == 'activity'
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (value) => setState(
                            () => _query = value.trim().toLowerCase(),
                          ),
                          decoration: InputDecoration(
                            hintText: _view == 'projects'
                                ? 'Search projects'
                                : 'Search chats',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: dark
                                ? const Color(0xff292929)
                                : const Color(0xfff5f5f5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: controller.switching || resource == null
                            ? null
                            : () => _run(() async {
                                if (_view == 'projects') {
                                  await widget.newProject();
                                } else {
                                  await controller.createChat();
                                }
                              }),
                        icon: const Icon(Icons.edit_square, size: 21),
                        label: Text(
                          _view == 'projects' ? 'Project' : 'New chat',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
