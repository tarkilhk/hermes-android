import 'package:flutter/material.dart';

/// Opened only after tapping an image in a conversation.
class ChatImagePreview extends StatelessWidget {
  final Uri uri;
  final String title;
  final VoidCallback onOpenExternal;

  const ChatImagePreview({
    super.key,
    required this.uri,
    required this.title,
    required this.onOpenExternal,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Open in browser',
          icon: const Icon(Icons.open_in_new),
          onPressed: onOpenExternal,
        ),
      ],
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Image.network(
          uri.toString(),
          semanticLabel: title,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stack) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This image could not be previewed. Try opening it in your browser.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onOpenExternal,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in browser'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
