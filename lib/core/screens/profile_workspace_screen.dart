import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/profile_workspace_controller.dart';
import '../services/android_share_intent_service.dart';
import '../widgets/profile_message.dart';
import '../models/answer_versions.dart';
import '../widgets/answer_actions.dart';
import '../models/gateway_clarify.dart';
import '../models/gateway_approval.dart';
import '../widgets/gateway_sensitive_prompt_panel.dart';
import '../widgets/gateway_clarify_dialog.dart';
import '../widgets/chat_find_sheet.dart';
import '../theme/profile_workspace_theme.dart';
import '../widgets/profile_chat_indicator.dart';
import '../widgets/chat_intelligence_picker.dart';
import '../widgets/context_fuse.dart';
import '../widgets/profile_execution_activity.dart';
import '../widgets/slash_command_suggestions.dart';
import '../widgets/side_question_delivery_card.dart';
import 'profile_workspace_browser.dart';
import 'profile_transcript.dart';
import 'chat_outputs_screen.dart';
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
    if (_destination == AppDestination.activity) {
      await controller.refreshActivity();
    }
    if (widget.initialQuickChat || widget.initialSharedPayload != null) {
      await _run(() async {
        final chat = await controller.createChat();
        await controller.updateDraft(
          chat,
          widget.initialSharedPayload?.text ?? '',
        );
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
              PopupMenuButton<String>(
                tooltip: 'Chat actions',
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  if (action == 'refresh') {
                    unawaited(_run(controller.refresh));
                  } else if (action == 'find') {
                    unawaited(
                      showChatFindSheet(
                        context,
                        loadHistory: () => controller.savedHistory(chat),
                      ),
                    );
                  } else if (action == 'outputs') {
                    unawaited(_run(() => _openOutputs(chat)));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'outputs', child: Text('Outputs')),
                  PopupMenuItem(value: 'find', child: Text('Find in chat')),
                  PopupMenuItem(
                    value: 'refresh',
                    child: Text('Refresh workspace'),
                  ),
                ],
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

  Future<void> _openOutputs(ProfileChat chat) async {
    final files = controller.outputFiles(chat);
    final owner = chat.key;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatOutputsScreen(
            chatTitle: chat.title,
            loadHistory: () => controller.savedHistory(chat),
            download: (path) => files.download(
              path,
              profileName: owner.workspace.profileName,
              storedSessionId: owner.sessionId,
            ),
            readText: (path) => files.readText(
              path,
              profileName: owner.workspace.profileName,
              storedSessionId: owner.sessionId,
            ),
          ),
        ),
      );
    } finally {
      files.close();
    }
  }

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
    final reasoning = profileMessageReasoning(message);
    final savedPrompt =
        isAnswerPrompt(message) && answerMessageId(message) != null;
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
        !chat.commandRunning &&
        !controller.switching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reasoning.isNotEmpty) ProfileReasoningDisclosure(text: reasoning),
        if (savedPrompt)
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 40),
                child: ProfileMessage(message: message),
              ),
              Positioned(
                right: 0,
                bottom: 12,
                child: IconButton(
                  key: ValueKey('edit-message-${answerMessageId(message)}'),
                  tooltip: 'Edit message',
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: enabled
                      ? () => _editSavedMessage(chat, message)
                      : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ),
            ],
          )
        else
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

  Future<void> _editSavedMessage(
    ProfileChat chat,
    Map<String, dynamic> message,
  ) async {
    var input = answerMessageText(message);
    var submitting = false;
    String? inlineError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canSubmit =
              !submitting && !chat.busy && input.trim().isNotEmpty;
          return AlertDialog(
            scrollable: true,
            title: const Text('Edit and resend?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "This replaces this message's turn and all later history in this chat.",
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: input,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 6,
                  onChanged: (value) => setDialogState(() {
                    input = value;
                    inlineError = null;
                  }),
                ),
                if (inlineError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    inlineError!,
                    key: const ValueKey('edit-message-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: canSubmit
                    ? () async {
                        setDialogState(() {
                          submitting = true;
                          inlineError = null;
                        });
                        var accepted = false;
                        try {
                          accepted = await controller.editSavedPrompt(
                            chat,
                            message,
                            input,
                          );
                        } catch (_) {
                          // Keep the correction in place for a deliberate retry.
                        }
                        if (!dialogContext.mounted) return;
                        if (accepted) {
                          Navigator.pop(dialogContext);
                          return;
                        }
                        setDialogState(() {
                          submitting = false;
                          inlineError =
                              chat.error ??
                              'Hermes did not accept the edited message.';
                        });
                      }
                    : null,
                child: submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Replace and resend'),
              ),
            ],
          );
        },
      ),
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
            if (chat.tool != null &&
                !chat.toolActivities.any((activity) => !activity.isTerminal))
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
            if (chat.toolActivities.isNotEmpty)
              ProfileLiveToolActivity(activities: chat.toolActivities),
            if (chat.todos.isNotEmpty) ProfileTodoPanel(todos: chat.todos),
            if (chat.reasoning.isNotEmpty)
              ProfileReasoningDisclosure(
                text: chat.reasoning,
                running: chat.busy,
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
              Builder(
                builder: (context) {
                  final approval = GatewayApprovalRequest.fromEventData(
                    chat.approval!,
                  );
                  return Card(
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
                              for (final choice in approval.choices)
                                choice == GatewayApprovalChoice.deny
                                    ? OutlinedButton(
                                        onPressed: chat.approvalResponding
                                            ? null
                                            : () => _run(
                                                () => controller.approve(
                                                  chat,
                                                  choice.wireValue,
                                                ),
                                              ),
                                        child: const Text('Deny'),
                                      )
                                    : FilledButton(
                                        onPressed: chat.approvalResponding
                                            ? null
                                            : () => _run(
                                                () => controller.approve(
                                                  chat,
                                                  choice.wireValue,
                                                ),
                                              ),
                                        child: Text(switch (choice) {
                                          GatewayApprovalChoice.once =>
                                            'Allow once',
                                          GatewayApprovalChoice.session =>
                                            'Allow for session',
                                          GatewayApprovalChoice.always =>
                                            'Always allow',
                                          GatewayApprovalChoice.deny => 'Deny',
                                        }),
                                      ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (chat.sensitivePrompt != null)
              Builder(
                builder: (context) {
                  final request = chat.sensitivePrompt!;
                  return GatewaySensitivePromptPanel(
                    key: ValueKey((chat.key, request.kind, request.requestId)),
                    request: request,
                    enabled:
                        !chat.sensitivePromptResponding &&
                        chat.status != ProfileTurnStatus.reconnecting,
                    onRespond: (value) => controller.respondSensitivePrompt(
                      chat,
                      value,
                      expectedRequest: request,
                    ),
                  );
                },
              ),
            for (final output in chat.commandOutput)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SelectableText(output),
              ),
            for (final delivery in chat.sideQuestionDeliveries)
              SideQuestionDeliveryCard(
                key: ValueKey((chat.key, delivery.taskId, delivery.state)),
                delivery: delivery,
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
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
                                    avatar: file.error == null
                                        ? null
                                        : Tooltip(
                                            message: file.error!,
                                            child: const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 18,
                                            ),
                                          ),
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
                        onChanged: (value) {
                          unawaited(
                            controller.updateDraft(chat, value).catchError((_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This draft could not be saved on the device.',
                                    ),
                                  ),
                                );
                              }
                            }),
                          );
                          setState(() {});
                        },
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
                                reasoningEffort:
                                    chat.reasoningEffort ?? 'default',
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
                                        () =>
                                            _chooseIntelligence(chat, context),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_hasMessageActions(chat))
                            IconButton(
                              tooltip: 'Message actions',
                              icon: Badge(
                                isLabelVisible: chat.queuedPrompts.isNotEmpty,
                                label: Text('${chat.queuedPrompts.length}'),
                                child: const Icon(Icons.more_horiz),
                              ),
                              onPressed: () => _showBusyActions(chat, context),
                            ),
                          Semantics(
                            container: true,
                            hint:
                                chat.queuedPrompts.isNotEmpty ||
                                    (chat.busy &&
                                        chat.draft.trim().isNotEmpty &&
                                        chat.attachments.isEmpty)
                                ? 'Long press for steer or queue actions'
                                : null,
                            child: GestureDetector(
                              onLongPress:
                                  chat.queuedPrompts.isNotEmpty ||
                                      (chat.busy &&
                                          chat.draft.trim().isNotEmpty &&
                                          chat.attachments.isEmpty)
                                  ? () => _showBusyActions(chat, context)
                                  : null,
                              child: IconButton.filled(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                tooltip:
                                    chat.busy &&
                                        !chat.draft.trimLeft().startsWith('/')
                                    ? 'Stop'
                                    : 'Send',
                                icon: Icon(
                                  chat.busy &&
                                          !chat.draft.trimLeft().startsWith('/')
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
                                                !chat.draft
                                                    .trimLeft()
                                                    .startsWith('/')
                                            ? controller.stop(chat)
                                            : controller.send(chat),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -4,
                  left: 24,
                  right: 24,
                  child: ContextFuse(occupancy: chat.context),
                ),
              ],
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

  bool _canForkDraft(ProfileChat chat) =>
      !chat.busy &&
      !chat.queueDraining &&
      chat.draft.trim().isNotEmpty &&
      !chat.draft.trimLeft().startsWith('/') &&
      chat.attachments.isEmpty &&
      chat.messages.any(
        (message) =>
            message['role'] == 'assistant' &&
            answerMessageId(message) != null &&
            isBranchMessage(message),
      );

  bool _hasMessageActions(ProfileChat chat) =>
      !controller.switching &&
      !chat.commandRunning &&
      !chat.changingAnswer &&
      !chat.changingIntelligence &&
      (_canForkDraft(chat) ||
          chat.queuedPrompts.isNotEmpty ||
          (chat.busy &&
              chat.draft.trim().isNotEmpty &&
              !chat.draft.trimLeft().startsWith('/') &&
              chat.attachments.isEmpty));

  Future<void> _showBusyActions(ProfileChat chat, BuildContext context) async {
    if (!_hasMessageActions(chat)) return;
    final text = chat.draft.trim();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .55,
            child: ListView(
              children: [
                if (_canForkDraft(chat))
                  ListTile(
                    leading: const Icon(Icons.fork_right),
                    title: const Text('Fork into a new chat'),
                    subtitle: const Text(
                      'Branch at the latest saved answer and send this message',
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'fork'),
                  ),
                if (text.isNotEmpty &&
                    !text.startsWith('/') &&
                    chat.busy &&
                    chat.attachments.isEmpty) ...[
                  ListTile(
                    leading: const Icon(Icons.alt_route),
                    title: const Text('Steer this turn'),
                    subtitle: const Text(
                      'Send this text into the running turn',
                    ),
                    onTap:
                        !chat.steering &&
                            {
                              ProfileTurnStatus.running,
                              ProfileTurnStatus.attention,
                            }.contains(chat.status)
                        ? () => Navigator.pop(sheetContext, 'steer')
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.queue),
                    title: const Text('Queue for the next turn'),
                    subtitle: const Text(
                      'Keep this message for when Hermes is idle',
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'queue'),
                  ),
                ],
                if (chat.queuePaused)
                  ListTile(
                    leading: const Icon(Icons.pause_circle_outline),
                    title: const Text('Queued messages are paused'),
                    subtitle: const Text(
                      'Check history before resuming; a previous send may have reached Hermes.',
                    ),
                    onTap: chat.queueDraining
                        ? null
                        : () async {
                            await _run(() => controller.resumeQueue(chat));
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                    trailing: const Icon(Icons.play_arrow),
                  ),
                if (chat.queuedPrompts.isNotEmpty)
                  ...chat.queuedPrompts.asMap().entries.map(
                    (entry) => ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text('Remove queued: ${entry.value}'),
                      onTap: chat.queueDraining
                          ? null
                          : () async {
                              await _run(
                                () => controller.removeQueuedPrompt(
                                  chat,
                                  entry.key,
                                  expectedText: entry.value,
                                ),
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                    ),
                  ),
                if (chat.busy)
                  ListTile(
                    leading: const Icon(Icons.stop),
                    title: const Text('Stop'),
                    onTap: () => Navigator.pop(sheetContext, 'stop'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'fork') {
      await _run(() async {
        await controller.forkPrompt(chat, text);
      });
    } else if (action == 'steer') {
      final accepted = await _runValue(() => controller.steer(chat, text));
      if (accepted == true && mounted && chat.draft.trim() == text) {
        await controller.updateDraft(chat, '');
      } else if (accepted == false && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hermes rejected the steering message.'),
          ),
        );
      }
    } else if (action == 'queue') {
      await _run(() async => controller.queuePrompt(chat, text));
    } else if (action == 'stop') {
      await _run(() => controller.stop(chat));
    }
  }

  Future<T?> _runValue<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return null;
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
    if (destination == AppDestination.activity) {
      unawaited(_run(controller.refreshActivity));
    }
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
              tooltip: _destination == AppDestination.activity
                  ? 'Refresh activity'
                  : 'Refresh workspace',
              icon: const Icon(Icons.refresh),
              onPressed:
                  controller.switching ||
                      (_destination == AppDestination.activity &&
                          controller.activityLoading)
                  ? null
                  : () => _run(
                      _destination == AppDestination.activity
                          ? controller.refreshActivity
                          : controller.refresh,
                    ),
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
                onOpen: (item) => _run(() async {
                  await controller.openSession(
                    ProfileSessionKey(item.workspace, item.sessionId),
                  );
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
