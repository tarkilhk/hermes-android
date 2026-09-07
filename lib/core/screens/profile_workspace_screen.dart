import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/profile_workspace_controller.dart';
import '../services/android_share_intent_service.dart';
import '../widgets/profile_message.dart';
import '../models/answer_versions.dart';
import '../widgets/answer_actions.dart';
import '../models/gateway_clarify.dart';
import '../widgets/gateway_clarify_dialog.dart';
import '../theme/profile_workspace_theme.dart';
import '../widgets/profile_chat_indicator.dart';
import '../widgets/chat_intelligence_picker.dart';
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
  ProfileSessionKey? _loadingIntelligence;
  late WorkspaceAccent _accent;

  @override
  void initState() {
    super.initState();
    _accent = WorkspaceAccent.fromName(
      controller.preferences.getString(WorkspaceAccent.preferenceKey),
    );
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
  Widget build(BuildContext context) => Theme(
    data: profileWorkspaceTheme(Theme.of(context), accent: _accent),
    child: Builder(builder: (context) => _buildWorkspace(context)),
  );

  Widget _buildWorkspace(BuildContext context) => ListenableBuilder(
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
          appearance: () => _chooseAccent(context),
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
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Switch profile',
                  enabled: !controller.switching,
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
                          '${controller.connection.label} · ${current!.scope.profileName}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Accent color',
                icon: const Icon(Icons.palette_outlined, size: 21),
                onPressed: () => _chooseAccent(context),
              ),
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
              Expanded(child: _chat(chat, context)),
            ],
          ),
        ),
      );
    },
  );

  Widget _questionPanel(ProfileChat chat) {
    final payload = chat.clarification!;
    final questions = GatewayClarifyRequest.fromEventDataList(payload);
    final pending = chat.pendingQuestion!;
    final index = questions.indexWhere(
      (q) => q.questionId == pending['question_id'],
    );
    if (index < 0) {
      return const Text(
        'This question could not be displayed. Refresh to try again.',
      );
    }
    final question = questions[index];
    return GatewayClarifyDialog(
      key: ValueKey((chat.key, question.requestId, question.questionId)),
      inline: true,
      request: question,
      number: index + 1,
      total: questions.length,
      onRespond: (answer) =>
          controller.clarify(chat, answer, expectedRequest: payload),
    );
  }

  Widget _answer(ProfileChat chat, Map<String, dynamic> message) {
    final savedAnswer =
        message['role'] == 'assistant' &&
        answerMessageId(message) != null &&
        isBranchMessage(message);
    final group = controller.answerVersionsForMessage(chat, message);
    final selected = group?.selections[chat.key.sessionId] ?? 0;
    final enabled =
        !chat.busy &&
        !chat.changingAnswer &&
        !chat.changingIntelligence &&
        !controller.switching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileMessage(message: message),
        if (savedAnswer)
          AnswerActions(
            key: ValueKey('answer-actions-${answerMessageId(message)}'),
            busy: chat.changingAnswer,
            onBranch: enabled
                ? () => _run(() async {
                    await controller.branchAnswer(
                      chat,
                      chat.messages.indexOf(message),
                    );
                  })
                : null,
            onRegenerate: enabled
                ? () => _run(() async {
                    await controller.branchAnswer(
                      chat,
                      chat.messages.indexOf(message),
                      regenerate: true,
                    );
                  })
                : null,
            version: selected + 1,
            count: group?.sessions.length ?? 1,
            onPrevious: enabled && group != null
                ? () => _run(
                    () => controller.selectAnswer(chat, group, selected - 1),
                  )
                : null,
            onNext: enabled && group != null
                ? () => _run(
                    () => controller.selectAnswer(chat, group, selected + 1),
                  )
                : null,
          ),
      ],
    );
  }

  Widget _chat(ProfileChat chat, BuildContext context) => Column(
    children: [
      if (chat.busy || chat.error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              ProfileChatIndicator(chat: chat, row: const {}),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _status(chat),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      Expanded(
        child: ProfileTranscript(
          key: ValueKey(chat.key),
          chat: chat,
          controller: controller,
          messageBuilder: (message) => _answer(chat, message),
          tail: [
            if (chat.streaming.isNotEmpty)
              ProfileMessage(
                message: {'role': 'assistant', 'content': chat.streaming},
                streaming: true,
              ),
            if (chat.tool != null)
              ExpansionTile(
                minTileHeight: 48,
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.terminal, size: 20),
                title: Text(
                  'Using ${chat.tool!}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
            if (chat.pendingQuestion != null) _questionPanel(chat),
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: DecoratedBox(
            key: const ValueKey('conversation-composer'),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (chat.attachments.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final file in chat.attachments)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: InputChip(
                                label: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 180,
                                  ),
                                  child: Text(
                                    file.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                onDeleted:
                                    chat.busy ||
                                        chat.changingAnswer ||
                                        controller.switching
                                    ? null
                                    : () => _run(
                                        () => controller.removeAttachment(
                                          chat,
                                          file,
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  TextField(
                    key: const Key('profile-message-composer'),
                    controller: _composer,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (value) => setState(() => chat.draft = value),
                    decoration: InputDecoration(
                      isDense: true,
                      hintMaxLines: 1,
                      hintText: chat.busy
                          ? 'Draft your next message'
                          : 'Message Hermes',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Attach file',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.add),
                        onPressed:
                            chat.busy ||
                                chat.changingAnswer ||
                                controller.switching
                            ? null
                            : () => _run(() async {
                                final result = await FilePicker.platform
                                    .pickFiles();
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
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ChatIntelligenceButton(
                            model: chat.model ?? 'Model',
                            reasoningEffort: chat.reasoningEffort ?? 'default',
                            loading:
                                _loadingIntelligence == chat.key ||
                                chat.changingIntelligence,
                            onPressed:
                                chat.busy ||
                                    chat.changingAnswer ||
                                    controller.switching ||
                                    chat.changingIntelligence ||
                                    _loadingIntelligence != null
                                ? null
                                : () => _run(
                                    () => _chooseIntelligence(chat, context),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        tooltip: chat.busy ? 'Stop' : 'Send',
                        icon: Icon(chat.busy ? Icons.stop : Icons.arrow_upward),
                        onPressed:
                            controller.switching ||
                                chat.changingAnswer ||
                                chat.changingIntelligence ||
                                (!chat.busy &&
                                    chat.draft.trim().isEmpty &&
                                    chat.attachments.isEmpty)
                            ? null
                            : () => _run(
                                () => chat.busy
                                    ? controller.stop(chat)
                                    : controller.send(chat),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Future<void> _chooseIntelligence(
    ProfileChat chat,
    BuildContext context,
  ) async {
    setState(() => _loadingIntelligence = chat.key);
    try {
      final options = await controller.loadIntelligence(chat);
      if (!mounted ||
          !context.mounted ||
          controller.current?.chat != chat ||
          controller.switching) {
        return;
      }
      setState(() => _loadingIntelligence = null);
      final choice = options.choices
          .where(
            (choice) =>
                choice.model == chat.model &&
                (chat.provider == null || choice.provider == chat.provider),
          )
          .firstOrNull;
      // Keep an existing model visible even if it is absent from today's catalog.
      final initial =
          choice ??
          ChatModelChoice(
            provider: chat.provider ?? options.defaultProvider ?? '',
            model: chat.model ?? options.defaultModel,
          );
      final selection = await showChatIntelligencePicker(
        context: context,
        choices: options.choices,
        initialChoice: initial,
        initialReasoningEffort: chat.reasoningEffort ?? 'medium',
        defaultModel: options.defaultModel,
        defaultProvider: options.defaultProvider,
      );
      if (selection != null && mounted) {
        await controller.setIntelligence(chat, selection);
      }
    } finally {
      if (mounted) setState(() => _loadingIntelligence = null);
    }
  }

  Future<void> _chooseAccent(BuildContext context) async {
    final choice = await showDialog<WorkspaceAccent>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accent color'),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personalize this device. Status colors stay consistent.',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final accent in WorkspaceAccent.values)
                      ChoiceChip(
                        key: ValueKey('accent-${accent.name}'),
                        label: Text(accent.label),
                        selected: _accent == accent,
                        avatar: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? accent.dark
                              : accent.light,
                          radius: 9,
                        ),
                        onSelected: (_) => Navigator.pop(context, accent),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await _run(() async {
      final saved = await controller.preferences.setString(
        WorkspaceAccent.preferenceKey,
        choice.name,
      );
      if (!saved) throw StateError('Could not save accent color');
      if (mounted) setState(() => _accent = choice);
    });
  }

  String _status(ProfileChat chat) => switch (chat.status) {
    ProfileTurnStatus.idle => 'Ready',
    ProfileTurnStatus.submitting => 'Sending message…',
    ProfileTurnStatus.running =>
      chat.tool != null
          ? 'Using ${chat.tool}'
          : chat.streaming.isEmpty
          ? 'Hermes is working…'
          : 'Writing response…',
    ProfileTurnStatus.attention =>
      chat.approval != null ? 'Approval needed' : 'Your reply is needed',
    ProfileTurnStatus.reconnecting => 'Connection lost · checking this chat',
    ProfileTurnStatus.settling => 'Updating history…',
    ProfileTurnStatus.completed => 'Response complete',
    ProfileTurnStatus.cancelled => 'Stopped',
    ProfileTurnStatus.failed => 'Something went wrong',
  };

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
