import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/profile_workspace_controller.dart';
import '../services/android_share_intent_service.dart';
import 'profile_workspace_browser.dart';
import 'profile_transcript.dart';

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
      if (chat == null) {
        return ProfileWorkspaceBrowser(
          key: ValueKey(current?.scope),
          controller: controller,
          newProject: _projectDialog,
          enableNotifications: widget.enableNotifications,
        );
      }
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.showList();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
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
                      unawaited(controller.navigateProfile(name)),
                  itemBuilder: (_) => [
                    for (final profile in controller.discovery?.profiles ?? [])
                      PopupMenuItem(
                        value: profile.name,
                        child: Text(profile.label),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          current!.scope.profileName,
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
              Expanded(child: _chat(chat)),
            ],
          ),
        ),
      );
    },
  );

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
        child: ProfileTranscript(
          key: ValueKey(chat.key),
          chat: chat,
          controller: controller,
          messageBuilder: _message,
          tail: [
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
                    chat.pendingQuestion?['question']?.toString() ??
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
    var input = '';
    // Let the field own its controller through the dialog's exit animation.
    // showDialog resolves before the route's widgets have finished unmounting.
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          onChanged: (value) => input = value,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, input.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
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
