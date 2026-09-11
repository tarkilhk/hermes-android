import 'package:flutter/material.dart';

import '../services/profile_workspace_controller.dart';

/// Presents the activity already observed by this connection's controller.
/// Server-wide discovery belongs to the later Activity feature work.
class WorkspaceActivityContent extends StatelessWidget {
  const WorkspaceActivityContent({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  final ProfileWorkspaceController controller;
  final ValueChanged<ProfileChat> onOpen;

  @override
  Widget build(BuildContext context) {
    final chats = controller.activity.toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text('Activity from chats opened on this connection.'),
        ),
        if (chats.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(Icons.pending_actions_outlined, size: 40),
                SizedBox(height: 16),
                Text('No recent activity'),
              ],
            ),
          ),
        for (final chat in chats)
          Card(
            child: ListTile(
              key: ValueKey(
                'activity-${chat.key.workspace.profileName}-${chat.key.sessionId}',
              ),
              leading: Icon(
                chat.status == ProfileTurnStatus.attention
                    ? Icons.front_hand_outlined
                    : Icons.chat_bubble_outline,
              ),
              title: Text(
                chat.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${chat.key.workspace.profileName} · ${chat.status.name}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.switching ? null : () => onOpen(chat),
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
