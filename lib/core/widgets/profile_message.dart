import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'markdown_code_block.dart';
import 'profile_tool_activity.dart';
import '../theme/profile_markdown_style.dart';

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

  Widget _copy(BuildContext context, String content) => IconButton(
    tooltip: 'Copy message',
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    icon: const Icon(Icons.copy_outlined, size: 17),
    onPressed: () async {
      await Clipboard.setData(ClipboardData(text: content));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message copied')));
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = message['role']?.toString() ?? '';
    final content = (message['display_content'] ?? message['content'] ?? '')
        .toString();
    if (content.isEmpty) return const SizedBox.shrink();
    if (role == 'tool') {
      return ProfileToolActivity(messages: [message]);
    }
    final user = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!user)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      role == 'assistant' ? 'H' : 'S',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    role == 'assistant' ? 'Hermes' : 'System',
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (!streaming) _copy(context, content),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: user
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  margin: EdgeInsets.only(left: user ? 28 : 0),
                  padding: user
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                      : EdgeInsets.zero,
                  decoration: user
                      ? BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(6),
                          ),
                        )
                      : null,
                  child: user
                      ? SelectableText(
                          content,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final segment in splitMarkdownCodeBlocks(
                              content,
                            ))
                              if (segment is MarkdownCodeBlock)
                                segment
                              else
                                Theme(
                                  data: profileMarkdownTheme(theme),
                                  child: MarkdownBody(
                                    data: segment as String,
                                    selectable: true,
                                    onTapLink: (_, href, _) {
                                      if (href != null) _open(context, href);
                                    },
                                    sizedImageBuilder: (config) =>
                                        OutlinedButton.icon(
                                          onPressed: () => _open(
                                            context,
                                            config.uri.toString(),
                                          ),
                                          icon: const Icon(
                                            Icons.image_outlined,
                                          ),
                                          label: Text(
                                            config.alt ?? 'Open image link',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    styleSheet: profileMarkdownStyle(theme),
                                  ),
                                ),
                          ],
                        ),
                ),
              ),
              if (user && !streaming) _copy(context, content),
            ],
          ),
        ],
      ),
    );
  }
}
