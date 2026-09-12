import 'package:flutter/material.dart';

import '../models/session_control.dart';
import '../services/profile_workspace_controller.dart';

/// Displays the server-owned goal for one captured chat and its supported
/// controls. The containing screen decides whether an empty panel is shown.
class ProfileGoalPanel extends StatefulWidget {
  final ProfileWorkspaceController controller;
  final ProfileChat chat;
  final bool initiallyExpanded;

  const ProfileGoalPanel({
    super.key,
    required this.controller,
    required this.chat,
    this.initiallyExpanded = false,
  });

  @override
  State<ProfileGoalPanel> createState() => _ProfileGoalPanelState();
}

class _ProfileGoalPanelState extends State<ProfileGoalPanel> {
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    _requestRefresh();
  }

  @override
  void didUpdateWidget(ProfileGoalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chat, widget.chat)) {
      _requested = false;
      _requestRefresh();
    }
  }

  void _requestRefresh() {
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await widget.controller.refreshSessionControl(widget.chat);
      } catch (_) {
        // The controller retains the error for the panel.
      }
    });
  }

  Future<void> _refresh() async {
    try {
      await widget.controller.refreshSessionControl(widget.chat);
    } catch (_) {
      // The controller retains the error for the panel.
    }
  }

  Future<void> _run(SessionControlAction action) async {
    try {
      await widget.controller.controlSession(widget.chat, action);
    } catch (_) {
      // The controller retains the error and notice for the panel.
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear goal?'),
        content: const Text('This clears the goal on the Hermes server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(SessionControlAction.goalClear);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final chat = widget.chat;
      final snapshot = chat.sessionControl;
      final goal = snapshot?.goal;
      final working = chat.sessionControlLoading || chat.sessionControlWorking;
      final error = chat.sessionControlError;
      return ExpansionTile(
        key: ValueKey(('goal', chat.key)),
        initiallyExpanded: widget.initiallyExpanded,
        minTileHeight: 48,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.track_changes_outlined, size: 20),
        title: const Text('Goal'),
        subtitle: Text(_summary(goal, chat.sessionControlNotice)),
        trailing: chat.sessionControlLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [
          if (error != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(error)),
                TextButton(
                  onPressed: working ? null : _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          if (goal == null && error == null)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Hermes has no active goal for this chat.'),
            ),
          if (goal != null) _GoalDetails(goal: goal),
          if (goal != null)
            _GoalActions(
              goal: goal,
              disabled: working,
              onAction: _run,
              onClear: _clear,
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: working ? null : _refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ),
          if (chat.sessionControlNotice case final notice?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(notice),
            ),
        ],
      );
    },
  );

  static String _summary(SessionGoal? goal, String? notice) {
    if (goal == null) return notice ?? 'Server state';
    return '${_statusLabel(goal.status)} · ${goal.turnsUsed}/${goal.maxTurns} turns';
  }

  static String _statusLabel(SessionGoalStatus status) => switch (status) {
    SessionGoalStatus.active => 'Active',
    SessionGoalStatus.done => 'Done',
    SessionGoalStatus.paused => 'Paused',
  };
}

class _GoalDetails extends StatelessWidget {
  final SessionGoal goal;

  const _GoalDetails({required this.goal});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 360),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(goal.title),
          const SizedBox(height: 8),
          _Field(label: 'Outcome', value: goal.contract.outcome),
          _Field(label: 'Verification', value: goal.contract.verification),
          _Field(label: 'Constraints', value: goal.contract.constraints),
          _Field(label: 'Boundaries', value: goal.contract.boundaries),
          _Field(label: 'Stop when', value: goal.contract.stopWhen),
          if (goal.subgoals.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Criteria',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (var i = 0; i < goal.subgoals.length; i++)
              SelectableText('${i + 1}. ${goal.subgoals[i]}'),
          ],
          if (goal.gates.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Verification gates',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final gate in goal.gates)
              SelectableText(
                '${gate.command} · ${gate.attempts} attempts · ${gate.maxRetries} retries allowed · ${gate.timeoutSeconds}s timeout · ${gate.lastExitCode == null ? 'not run' : 'exit ${gate.lastExitCode}'}',
              ),
          ],
          if (goal.pausedReason != null)
            _Field(label: 'Paused', value: goal.pausedReason!),
          if (goal.lastVerdict != null)
            _Field(
              label: 'Last verdict',
              value: _verdictText(goal.lastVerdict!),
            ),
          if (goal.lastReason != null)
            _Field(label: 'Reason', value: goal.lastReason!),
          if (goal.waitBarrier != null)
            _Field(
              label: 'Waiting',
              value: _barrierText(context, goal.waitBarrier!),
            ),
        ],
      ),
    ),
  );

  String _barrierText(BuildContext context, SessionGoalWaitBarrier barrier) {
    if (barrier.type == SessionGoalWaitType.until) {
      final local = DateTime.fromMillisecondsSinceEpoch(
        (barrier.untilAt! * 1000).round(),
      ).toLocal();
      final material = MaterialLocalizations.of(context);
      final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
      return '${barrier.reason} (until ${material.formatFullDate(local)} $time)';
    }
    return switch (barrier.type) {
      SessionGoalWaitType.session =>
        '${barrier.reason} (session ${barrier.sessionTarget})',
      SessionGoalWaitType.pid =>
        '${barrier.reason} (process ${barrier.processId})',
      SessionGoalWaitType.until => barrier.reason,
    };
  }

  static String _verdictText(SessionGoalVerdict verdict) => switch (verdict) {
    SessionGoalVerdict.blocked => 'Blocked',
    SessionGoalVerdict.continueRunning => 'Continue',
    SessionGoalVerdict.done => 'Done',
    SessionGoalVerdict.skipped => 'Skipped',
    SessionGoalVerdict.wait => 'Waiting',
  };
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: value.trim().isEmpty
        ? const SizedBox.shrink()
        : SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
  );
}

class _GoalActions extends StatelessWidget {
  final SessionGoal goal;
  final bool disabled;
  final Future<void> Function(SessionControlAction) onAction;
  final Future<void> Function() onClear;

  const _GoalActions({
    required this.goal,
    required this.disabled,
    required this.onAction,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      if (goal.status == SessionGoalStatus.active)
        TextButton.icon(
          onPressed: disabled
              ? null
              : () => onAction(SessionControlAction.goalPause),
          icon: const Icon(Icons.pause, size: 18),
          label: const Text('Pause'),
        ),
      if (goal.status == SessionGoalStatus.paused ||
          goal.status == SessionGoalStatus.done)
        TextButton.icon(
          onPressed: disabled
              ? null
              : () => onAction(SessionControlAction.goalResume),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Resume'),
        ),
      if (goal.waitBarrier != null)
        TextButton.icon(
          onPressed: disabled
              ? null
              : () => onAction(SessionControlAction.goalUnwait),
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: const Text('Resume now'),
        ),
      TextButton.icon(
        onPressed: disabled ? null : onClear,
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text('Clear'),
      ),
    ],
  );
}
