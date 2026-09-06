import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/profile_workspace_controller.dart';

Future<String?> _choose(
  BuildContext context,
  String title,
  String scope,
  List<(String, String, IconData, bool)> actions,
) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(scope),
          ),
          const Divider(),
          for (final (id, label, icon, enabled) in actions)
            ListTile(
              enabled: enabled,
              leading: Icon(
                icon,
                color: id == 'delete'
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              title: Text(
                label,
                style: TextStyle(
                  color: id == 'delete'
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              onTap: () => Navigator.pop(context, id),
            ),
        ],
      ),
    ),
  ),
);

Future<void> showProjectActions(
  BuildContext context,
  ProfileWorkspaceController controller,
  Map<String, dynamic> project,
) async {
  final scope = controller.current!.scope;
  final action = await _choose(
    context,
    project['name'] as String,
    scope.profileName,
    [('new', 'New chat in project', Icons.edit_square, true)],
  );
  if (action == 'new') {
    await controller.createChat(inProject: project, owner: scope);
  }
}

Future<void> showChatActions(
  BuildContext context,
  ProfileWorkspaceController controller,
  Map<String, dynamic> row,
) async {
  final resource = controller.current!;
  final key = ProfileSessionKey(resource.scope, row['id'] as String);
  final title = row['title']?.toString() ?? 'Untitled chat';
  final busy = resource.chats[key.sessionId]?.busy == true;
  final pinned = row['pinned'] == true;
  final archived = row['archived'] == true || resource.archivedOnly;
  final unread = row['unread'] == true;
  final action = await _choose(context, title, resource.scope.profileName, [
    ('rename', 'Rename', Icons.edit_outlined, true),
    ('pin', pinned ? 'Unpin' : 'Pin', Icons.push_pin_outlined, true),
    (
      'unread',
      unread ? 'Mark as read' : 'Mark as unread',
      Icons.mark_email_unread_outlined,
      true,
    ),
    ('copy', 'Copy ID', Icons.copy_outlined, true),
    (
      'archive',
      archived ? 'Unarchive' : 'Archive',
      Icons.archive_outlined,
      !busy,
    ),
    ('delete', 'Delete', Icons.delete_outline, !busy),
  ]);
  if (action == null || !context.mounted) return;
  if (action == 'copy') {
    await Clipboard.setData(ClipboardData(text: key.sessionId));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat ID copied')));
    }
    return;
  }
  if (action == 'rename') {
    var value = title;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextFormField(
          initialValue: title,
          autofocus: true,
          maxLength: 200,
          onChanged: (text) => value = text,
          decoration: const InputDecoration(labelText: 'Chat title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await controller.mutateSession(key, changes: {'title': result});
    }
  } else if (action == 'delete') {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          'Permanently delete "$title" from ${resource.scope.profileName}? Its stored history cannot be recovered. Archive it instead to keep the conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.mutateSession(key, delete: true);
  } else {
    await controller.mutateSession(
      key,
      changes: switch (action) {
        'pin' => {'pinned': !pinned},
        'archive' => {'archived': !archived},
        'unread' => {'unread': !unread},
        _ => throw StateError('Unknown action'),
      },
    );
  }
}
