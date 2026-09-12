import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'markdown_code_block.dart';

enum DiagramFormat { mermaid, svg }

/// A disposable native view of a diagram, opened explicitly from its source.
class DiagramPreview extends StatefulWidget {
  static const maxMermaidSourceLength = 50000;
  static const maxSvgSourceLength = 256 * 1024;
  static const viewType = 'com.hermesagent.hermes_android/mermaid_diagram';

  final String source;
  final DiagramFormat format;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DiagramPreview({
    super.key,
    required this.source,
    required this.format,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<DiagramPreview> createState() => _DiagramPreviewState();
}

class _DiagramPreviewState extends State<DiagramPreview> {
  bool _showSource = false;

  @override
  Widget build(BuildContext context) {
    final supported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final limit = widget.format == DiagramFormat.svg
        ? DiagramPreview.maxSvgSourceLength
        : DiagramPreview.maxMermaidSourceLength;
    final canRender =
        supported && widget.source.isNotEmpty && widget.source.length <= limit;
    final svg = widget.format == DiagramFormat.svg;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? (svg ? 'SVG preview' : 'Diagram'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.onAction != null)
            IconButton(
              tooltip: widget.actionLabel,
              icon: const Icon(Icons.ios_share),
              onPressed: widget.onAction,
            ),
          if (canRender)
            IconButton(
              tooltip: _showSource
                  ? (svg ? 'Show SVG' : 'Show diagram')
                  : 'Show source',
              icon: Icon(
                _showSource
                    ? (svg ? Icons.image_outlined : Icons.account_tree_outlined)
                    : Icons.code,
              ),
              onPressed: () => setState(() => _showSource = !_showSource),
            ),
        ],
      ),
      body: SafeArea(
        child: _showSource || !canRender
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!canRender)
                      Text(
                        svg
                            ? 'This SVG is available as source here.'
                            : 'This diagram is available as source here.',
                      ),
                    MarkdownCodeBlock(
                      code: widget.source,
                      language: svg ? 'svg' : 'mermaid',
                      previewEnabled: false,
                    ),
                  ],
                ),
              )
            : AndroidView(
                key: ValueKey(theme.brightness),
                viewType: DiagramPreview.viewType,
                creationParamsCodec: const StandardMessageCodec(),
                creationParams: {
                  'source': widget.source,
                  'dark': theme.brightness == Brightness.dark,
                  'format': svg ? 'svg' : 'mermaid',
                },
              ),
      ),
    );
  }
}
