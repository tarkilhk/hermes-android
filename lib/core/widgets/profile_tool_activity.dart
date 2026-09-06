import 'package:flutter/material.dart';

/// Disclosure for contiguous tool results. Never contains approvals or questions.
class ProfileToolActivity extends StatelessWidget {
  const ProfileToolActivity({super.key, required this.messages});
  final List<Map<String, dynamic>> messages;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = messages.length == 1
        ? messages.single['tool_name']?.toString() ?? 'Tool result'
        : '${messages.length} tool results';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: ValueKey('tools-${messages.last['id']}'),
          minTileHeight: 48,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(
            Icons.terminal_rounded,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          title: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurfaceVariant,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final message in messages) ...[
              const Divider(height: 16),
              if (messages.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    message['tool_name']?.toString() ?? 'Tool result',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              SelectableText(
                (message['display_content'] ?? message['content'] ?? '')
                    .toString(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: colors.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chronological groups; non-tool messages always remain individual entries.
List<List<Map<String, dynamic>>> groupTranscriptRows(
  List<Map<String, dynamic>> rows,
) {
  final groups = <List<Map<String, dynamic>>>[];
  for (final row in rows) {
    if (row['role'] == 'tool' &&
        groups.isNotEmpty &&
        groups.last.last['role'] == 'tool') {
      groups.last.add(row);
    } else {
      groups.add([row]);
    }
  }
  return groups;
}
