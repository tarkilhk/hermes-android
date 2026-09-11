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
import '../widgets/slash_command_suggestions.dart';
import 'profile_workspace_browser.dart';
import 'profile_transcript.dart';
import '../widgets/app_drawer.dart';
import 'app_settings_content.dart';
import 'workspace_overview_content.dart';

/// Phone workspace with profile selection outside the conversation.
/// Network work and drafts belong to the application controller.
class ProfileWorkspaceScreen extends StatefulWidget {
  final ProfileWorkspaceController controller;
  final AndroidSharePayload? initialSharedPayload;
  final bool initialQuickChat;
  final Future<void> Function()? enableNotifications;
  final VoidCallback? onConnections;
  final VoidCallback? onPreferencesChanged;
  final AppDestination initialDestination;
  const ProfileWorkspaceScreen({
    super.key,
    required this.controller,
    this.initialSharedPayload,
    this.initialQuickChat = false,
    this.enableNotifications,
    this.onConnections,
    this.onPreferencesChanged,
    this.initialDestination = AppDestination.chats,
  });
  @override
  State<ProfileWorkspaceScreen> createState() => _ProfileWorkspaceScreenState();
}

class _ProfileWorkspaceScreenState extends State<ProfileWorkspaceScreen>
    with WidgetsBindingObserver {
  ProfileWorkspaceController get controller => widget.controller;
  final _composer = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  ProfileSessionKey? _composerKey;
  ProfileSessionKey? _loadingIntelligence;
  late AppDestination _destination;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
    WidgetsBinding.instance.addObserver(this);
    controller.visible = _destination == AppDestination.chats;
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
    controller.visible =
        state == AppLifecycleState.resumed &&
        _destination == AppDestination.chats;
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
    data: profileWorkspaceTheme(
      Theme.of(context),
      accent: WorkspaceAccent.fromName(
        controller.preferences.getString(WorkspaceAccent.preferenceKey),
      ),
    ),
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
      if (_destination != AppDestination.chats) {
        return _secondaryDestination(context);
      }
      if (chat == null) {
        return ProfileWorkspaceBrowser(
          key: ValueKey(current?.scope),
          controller: controller,
          newProject: _projectDialog,
          drawer: _drawer(),
        );
      }
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack(controller.showList);
        },
        child: Scaffold(
          key: _scaffoldKey,
          drawer: _drawer(),
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
                Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 14),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${controller.connection.label} · ${controller.chatProjectLabel(chat)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Open navigation menu',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
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
                      onPressed: () => _run(controller.retry),
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
    if (isHiddenAnswerMessage(message)) return const SizedBox.shrink();
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
            for (final output in chat.commandOutput)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SelectableText(output),
              ),
            if (chat.pendingQuestion != null) _questionPanel(chat),
          ],
        ),
      ),
      if (!chat.commandRunning)
        SlashCommandSuggestions(
          key: ValueKey(chat.key),
          controller: controller,
          chat: chat,
          composer: _composer,
        ),
      if (chat.commandRunning) const LinearProgressIndicator(),
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
                                        chat.commandRunning ||
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
                    enabled: !chat.commandRunning,
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
                          : 'Message Hermes or type /',
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
                                chat.commandRunning ||
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
                                    chat.commandRunning ||
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
                        tooltip:
                            chat.busy && !chat.draft.trimLeft().startsWith('/')
                            ? 'Stop'
                            : 'Send',
                        icon: Icon(
                          chat.busy && !chat.draft.trimLeft().startsWith('/')
                              ? Icons.stop
                              : Icons.arrow_upward,
                        ),
                        onPressed:
                            controller.switching ||
                                chat.changingAnswer ||
                                chat.commandRunning ||
                                chat.changingIntelligence ||
                                (!chat.busy &&
                                    chat.draft.trim().isEmpty &&
                                    chat.attachments.isEmpty)
                            ? null
                            : () => _run(
                                () =>
                                    chat.busy &&
                                        !chat.draft.trimLeft().startsWith('/')
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

  void _handleBack(VoidCallback navigateBack) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState!.closeDrawer();
    } else {
      navigateBack();
    }
  }

  Widget _drawer() => AppDrawer(
    selected: _destination,
    connectionLabel: controller.connection.label,
    profileLabel: controller.current?.scope.profileName,
    onSelected: _selectDestination,
  );

  void _selectDestination(AppDestination destination) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (destination == AppDestination.connections) {
      if (widget.onConnections != null) {
        widget.onConnections!();
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }
    setState(() => _destination = destination);
    controller.visible = destination == AppDestination.chats;
  }

  Widget _secondaryDestination(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _handleBack(() => _selectDestination(AppDestination.chats));
    },
    child: Scaffold(
      key: _scaffoldKey,
      drawer: _drawer(),
      appBar: AppBar(
        title: Text(_destination.label),
        actions: [
          if (_destination != AppDestination.settings)
            IconButton(
              tooltip: 'Refresh workspace',
              icon: const Icon(Icons.refresh),
              onPressed: controller.switching
                  ? null
                  : () => _run(controller.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
          if (controller.switching && _destination != AppDestination.settings)
            const LinearProgressIndicator(),
          if (controller.error != null &&
              _destination != AppDestination.settings)
            ListTile(
              title: Text(controller.error!),
              trailing: TextButton(
                onPressed: () => _run(controller.retry),
                child: const Text('Retry'),
              ),
            ),
          Expanded(
            child: switch (_destination) {
              AppDestination.settings => AppSettingsContent(
                preferences: controller.preferences,
                enableNotifications: widget.enableNotifications,
                onChanged: () {
                  setState(() {});
                  widget.onPreferencesChanged?.call();
                },
              ),
              AppDestination.activity => WorkspaceActivityContent(
                controller: controller,
                onOpen: (chat) => _run(() async {
                  await controller.openSession(chat.key);
                  if (mounted) _selectDestination(AppDestination.chats);
                }),
              ),
              _ => HermesAdministrationContent(
                controller: controller,
                onConnections: () =>
                    _selectDestination(AppDestination.connections),
              ),
            },
          ),
        ],
      ),
    ),
  );

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
