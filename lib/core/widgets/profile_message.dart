import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'markdown_code_block.dart';

/// Remote content is display-only. Links require a tap, and images never fetch
/// automatically or resolve a remote host path against the phone's filesystem.
class ProfileMessage extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool streaming;
  const ProfileMessage({
    super.key,
    required this.message,
    this.streaming = false,
  });

  static Uri? externalLink(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  Future<void> _open(BuildContext context, String href) async {
    final uri = externalLink(href);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // A missing browser is a visible, recoverable UI error.
      }
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uri == null
                ? 'Only http and https web links can be opened here.'
                : 'Could not open this link.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = message['role']?.toString() ?? '';
    final content = (message['display_content'] ?? message['content'] ?? '')
        .toString();
    if (content.isEmpty) return const SizedBox.shrink();
    if (role == 'tool') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          key: ValueKey('tool-${message['id']}'),
          leading: const Icon(Icons.terminal, size: 20),
          title: Text(
            message['tool_name']?.toString() ?? 'Tool result',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: const Text('Tap to inspect output'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              content,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }
    final user = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!user)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                role == 'assistant' ? 'Hermes' : 'System',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Container(
            margin: EdgeInsets.only(left: user ? 28 : 0),
            padding: user ? const EdgeInsets.all(14) : EdgeInsets.zero,
            decoration: user
                ? BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: user
                ? SelectableText(
                    content,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final segment in splitMarkdownCodeBlocks(content))
                        if (segment is MarkdownCodeBlock)
                          segment
                        else
                          MarkdownBody(
                            data: segment as String,
                            selectable: true,
                            onTapLink: (_, href, _) {
                              if (href != null) _open(context, href);
                            },
                            sizedImageBuilder: (config) => OutlinedButton.icon(
                              onPressed: () =>
                                  _open(context, config.uri.toString()),
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                config.alt ?? 'Open image link',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                .copyWith(
                                  p: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.5,
                                  ),
                                  blockSpacing: 12,
                                  code: theme.textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    backgroundColor:
                                        theme.colorScheme.surfaceContainerHigh,
                                  ),
                                  tableColumnWidth: const FlexColumnWidth(),
                                ),
                          ),
                    ],
                  ),
          ),
          if (!streaming)
            IconButton(
              tooltip: 'Copy message',
              icon: const Icon(Icons.copy_outlined, size: 17),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
