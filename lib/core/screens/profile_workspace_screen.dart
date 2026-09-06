import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/profile_workspace_controller.dart';
import '../services/android_share_intent_service.dart';

/// Phone workspace: host/profile stays visible above sessions or a conversation.
/// Network work and drafts belong to the application controller.
class ProfileWorkspaceScreen extends StatefulWidget {
  final ProfileWorkspaceController controller;
  final AndroidSharePayload? initialSharedPayload;
  final bool initialQuickChat;
  final Future<void> Function()? enableNotifications;
  const ProfileWorkspaceScreen({
    super.key,
    required this.controller,
    this.initialSharedPayload,
    this.initialQuickChat = false,
    this.enableNotifications,
  });
  @override
  State<ProfileWorkspaceScreen> createState() => _ProfileWorkspaceScreenState();
}

class _ProfileWorkspaceScreenState extends State<ProfileWorkspaceScreen>
    with WidgetsBindingObserver {
  ProfileWorkspaceController get controller => widget.controller;
  final _composer = TextEditingController();
  ProfileSessionKey? _composerKey;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.visible = true;
    unawaited(_enter());
  }

  Future<void> _enter() async {
    if (controller.discovery == null) await controller.initialize();
    if (!mounted || controller.current == null) return;
    if (widget.initialQuickChat || widget.initialSharedPayload != null) {
      await _run(() async {
        final chat = await controller.createChat();
        chat.draft = widget.initialSharedPayload?.text ?? '';
        for (final file
            in widget.initialSharedPayload?.files ?? <AndroidSharedFile>[]) {
          await controller.addAttachment(chat, file.path, file.name);
        }
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    controller.visible = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed && controller.current != null) {
      unawaited(controller.reconnect(controller.current!.scope));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    controller.visible = false;
    WidgetsBinding.instance.removeObserver(this);
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final current = controller.current;
      final chat = current?.chat;
      if (_composerKey != chat?.key || _composer.text != (chat?.draft ?? '')) {
        _composerKey = chat?.key;
        _composer.value = TextEditingValue(
          text: chat?.draft ?? '',
          selection: TextSelection.collapsed(offset: chat?.draft.length ?? 0),
        );
      }
      return PopScope(
        canPop: chat == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.showList();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: chat == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back to sessions',
                    onPressed: controller.showList,
                  ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.connection.label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Switch profile',
                  onSelected: (name) =>
                      unawaited(controller.switchProfile(name)),
                  itemBuilder: (_) => [
                    for (final profile in controller.discovery?.profiles ?? [])
                      PopupMenuItem(
                        value: profile.name,
                        child: Row(
                          children: [
                            if (profile.name == current?.scope.profileName)
                              const Icon(Icons.check, size: 18),
                            Flexible(child: Text(profile.label)),
                          ],
                        ),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          current?.scope.profileName ?? 'Loading profiles',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (widget.enableNotifications != null)
                IconButton(
                  tooltip: 'Enable completion notifications',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _run(widget.enableNotifications!),
                ),
              IconButton(
                tooltip: 'Refresh workspace',
                icon: const Icon(Icons.refresh),
                onPressed: () => _run(controller.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              if (controller.switching) const LinearProgressIndicator(),
              if (controller.error != null)
                MaterialBanner(
                  content: Text(controller.error!),
                  actions: [
                    TextButton(
                      onPressed: () => _run(controller.refresh),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              Expanded(
                child: current == null
                    ? Center(
                        child: controller.error == null
                            ? const CircularProgressIndicator()
                            : const Text('Workspace unavailable'),
                      )
                    : chat != null
                    ? _chat(chat)
                    : _workspace(),
              ),
            ],
          ),
          bottomNavigationBar: chat != null
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (value) =>
                      setState(() => _tab = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline),
                      label: 'Chats',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.folder_outlined),
                      label: 'Projects',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bolt_outlined),
                      label: 'Activity',
                    ),
                  ],
                ),
          floatingActionButton: chat != null || current == null || _tab == 2
              ? null
              : FloatingActionButton.extended(
                  onPressed: controller.switching
                      ? null
                      : () => _run(() async {
                          if (_tab == 1) {
                            await _projectDialog();
                          } else {
                            await controller.createChat();
                          }
                        }),
                  icon: const Icon(Icons.add),
                  label: Text(_tab == 1 ? 'New project' : 'New chat'),
                ),
        ),
      );
    },
  );

  Widget _workspace() {
    final resource = controller.current!;
    if (_tab == 2) {
      final activity = controller.activity.toList();
      if (activity.isEmpty) return const Center(child: Text('No active work'));
      return ListView(
        children: [
          for (final chat in activity)
            ListTile(
              title: Text(
                chat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${chat.key.workspace.profileName} · ${chat.status.name}',
              ),
              trailing: chat.busy
                  ? IconButton(
                      icon: const Icon(Icons.stop_circle_outlined),
                      tooltip: 'Stop this chat',
                      onPressed: () => _run(() => controller.stop(chat)),
                    )
                  : null,
              onTap: () => _run(() => controller.openSession(chat.key)),
            ),
        ],
      );
    }
    if (_tab == 1) {
      if (resource.projectsError != null) {
        return Center(child: Text(resource.projectsError!));
      }
      if (resource.projects.isEmpty) {
        return const Center(child: Text('No projects in this profile'));
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          for (final project in resource.projects)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(project['name']?.toString() ?? 'Project'),
              subtitle: Text(
                project['primary_path']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                unawaited(controller.selectProject(project));
                setState(() => _tab = 0);
              },
            ),
        ],
      );
    }
    final rows = resource.visibleSessions;
    final local = resource.chats.values.where(
      (c) =>
          (resource.selectedProject == null ||
              c.projectId == resource.selectedProject!['id']) &&
          !rows.any((r) => r['id'] == c.key.sessionId),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (resource.selectedProject != null)
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(resource.selectedProject!['name'].toString()),
            subtitle: const Text('Project chats · new chats use this folder'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Leave project',
              onPressed: () => controller.selectProject(null),
            ),
          ),
        if (resource.projectSessionsLoading) const LinearProgressIndicator(),
        if (resource.selectedProject != null &&
            resource.projectSessionsError != null)
          ListTile(
            title: Text(resource.projectSessionsError!),
            trailing: TextButton(
              onPressed: () => _run(
                () => controller.selectProject(resource.selectedProject),
              ),
              child: const Text('Retry'),
            ),
          ),
        if (rows.isEmpty &&
            local.isEmpty &&
            !resource.projectSessionsLoading &&
            resource.projectSessionsError == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('No chats here yet')),
          ),
        for (final chat in local)
          ListTile(
            title: Text(chat.title, maxLines: 2),
            subtitle: Text(chat.status.name),
            onTap: () => _run(() => controller.openSession(chat.key)),
          ),
        for (final row in rows)
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(
              row['title']?.toString().isNotEmpty == true
                  ? row['title'].toString()
                  : 'Untitled chat',
              maxLines: 2,
            ),
            subtitle: Text(
              resource.chats[row['id']]?.status.name ??
                  row['source']?.toString() ??
                  '',
            ),
            onTap: () => _run(
              () => controller.openSession(
                ProfileSessionKey(resource.scope, row['id'] as String),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chat(ProfileChat chat) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                chat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              chat.status.name,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final message in chat.messages) _message(message),
            if (chat.streaming.isNotEmpty)
              _message({'role': 'assistant', 'content': chat.streaming}),
            if (chat.tool != null)
              ExpansionTile(
                title: Text(chat.tool!),
                children: const [Text('Running on the connected Hermes host')],
              ),
            if (chat.error != null)
              Text(
                chat.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (chat.status == ProfileTurnStatus.reconnecting)
              TextButton(
                onPressed: () =>
                    _run(() => controller.reconnect(chat.key.workspace)),
                child: const Text('Reconnect and check history'),
              ),
            if (chat.approval != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Approval needed'),
                      SelectableText(
                        chat.approval!['command']?.toString() ??
                            chat.approval!['description']?.toString() ??
                            'The agent needs permission to continue.',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _run(() => controller.approve(chat, 'deny')),
                            child: const Text('Deny'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                _run(() => controller.approve(chat, 'once')),
                            child: const Text('Allow once'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (chat.clarification != null)
              Card(
                child: ListTile(
                  title: Text(
                    chat.clarification!['question']?.toString() ??
                        'Input requested',
                  ),
                  trailing: TextButton(
                    onPressed: () => _run(() async {
                      final answer = await _textDialog(
                        'Reply to Hermes',
                        'Answer',
                      );
                      if (answer != null) {
                        await controller.clarify(chat, answer);
                      }
                    }),
                    child: const Text('Reply'),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (chat.attachments.isNotEmpty)
        Wrap(
          children: [
            for (final file in chat.attachments)
              InputChip(
                label: Text(file.name),
                onDeleted: chat.busy
                    ? null
                    : () => _run(() => controller.removeAttachment(chat, file)),
              ),
          ],
        ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Attach file',
                icon: const Icon(Icons.add),
                onPressed: chat.busy
                    ? null
                    : () => _run(() async {
                        final result = await FilePicker.platform.pickFiles();
                        final file = result?.files.single;
                        if (file?.path != null) {
                          await controller.addAttachment(
                            chat,
                            file!.path!,
                            file.name,
                          );
                        }
                      }),
              ),
              Expanded(
                child: TextField(
                  key: const Key('profile-message-composer'),
                  controller: _composer,
                  minLines: 1,
                  maxLines: 6,
                  onChanged: (value) => chat.draft = value,
                  decoration: const InputDecoration(
                    hintText: 'Message Hermes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: chat.busy ? 'Stop' : 'Send',
                icon: Icon(chat.busy ? Icons.stop : Icons.arrow_upward),
                onPressed: controller.switching
                    ? null
                    : () => _run(
                        () => chat.busy
                            ? controller.stop(chat)
                            : controller.send(chat),
                      ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _message(Map<String, dynamic> message) {
    final role = message['role']?.toString() ?? '';
    final content =
        (message['display_content'] ??
                message['content'] ??
                message['text'] ??
                '')
            .toString();
    if (content.isEmpty) return const SizedBox.shrink();
    if (role == 'tool') {
      return ExpansionTile(
        title: const Text('Tool result'),
        children: [SelectableText(content)],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role == 'user' ? 'You' : 'Hermes',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 5),
          SelectableText(content),
        ],
      ),
    );
  }

  Future<String?> _textDialog(String title, String label) async {
    final input = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: input,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, input.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } finally {
      input.dispose();
    }
  }

  Future<void> _projectDialog() async {
    final name = await _textDialog('New project', 'Project name');
    if (name == null || name.isEmpty || !mounted) return;
    final path = await _textDialog(
      'Project folder on Hermes host',
      'Absolute path',
    );
    if (path == null || path.isEmpty) return;
    await controller.createProject(name, path);
  }
}
