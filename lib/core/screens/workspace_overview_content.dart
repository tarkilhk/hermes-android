import 'package:flutter/material.dart';

import '../models/profile_live_activity.dart';
import '../services/profile_workspace_controller.dart';

class WorkspaceActivityContent extends StatelessWidget {
  const WorkspaceActivityContent({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  final ProfileWorkspaceController controller;
  final ValueChanged<ProfileLiveActivity> onOpen;

  @override
  Widget build(BuildContext context) {
    final activity = controller.liveActivity;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text('Sessions running across this Hermes connection.'),
        ),
        if (controller.activityLoading) const LinearProgressIndicator(),
        if (controller.activityLoaded &&
            controller.activityAvailableProfiles == 0 &&
            controller.activityProfileErrors.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('Activity unavailable.'),
          )
        else
          for (final message in controller.activityProfileErrors.values)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message),
            ),
        if (activity.isEmpty && controller.activityLoaded)
          if (controller.activityAvailableProfiles > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(Icons.pending_actions_outlined, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    controller.activityProfileErrors.isEmpty
                        ? 'No ongoing sessions'
                        : 'No ongoing sessions found in available profiles',
                  ),
                ],
              ),
            ),
        for (final item in activity)
          Card(
            child: ListTile(
              key: ValueKey(
                'activity-${item.workspace.profileName}-${item.sessionId}',
              ),
              leading: Icon(
                item.state == ProfileLiveActivityState.needsInput
                    ? Icons.front_hand_outlined
                    : Icons.chat_bubble_outline,
              ),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${item.workspace.profileName} · '
                '${item.state == ProfileLiveActivityState.needsInput ? 'Needs input' : 'Running'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.switching ? null : () => onOpen(item),
            ),
          ),
      ],
    );
  }
}

/// Read-only administration entry using already-discovered server information.
class HermesAdministrationContent extends StatelessWidget {
  const HermesAdministrationContent({
    super.key,
    required this.controller,
    this.onConnections,
  });

  final ProfileWorkspaceController controller;
  final VoidCallback? onConnections;

  @override
  Widget build(BuildContext context) {
    final profile = controller.discovery?.named(
      controller.current?.scope.profileName,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text('Connection and selected profile'),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(controller.connection.label),
                subtitle: Text(
                  '${controller.connection.host}:${controller.connection.dashboardPort}',
                ),
              ),
              if (profile != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(profile.label),
                  subtitle: Text(profile.description ?? profile.name),
                ),
                if (profile.model != null)
                  ListTile(
                    title: const Text('Default model'),
                    subtitle: Text(profile.model!),
                  ),
                if (profile.provider != null)
                  ListTile(
                    title: const Text('Provider'),
                    subtitle: Text(profile.provider!),
                  ),
              ],
            ],
          ),
        ),
        if (onConnections != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_ethernet),
              title: const Text('Manage connections'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onConnections,
            ),
          ),
        ],
      ],
    );
  }
}
