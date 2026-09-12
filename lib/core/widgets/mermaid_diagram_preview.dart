import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'markdown_code_block.dart';

/// A disposable view of one diagram, opened explicitly from its source block.
class MermaidDiagramPreview extends StatefulWidget {
  static const maxSourceLength = 50000;
  static const viewType = 'com.hermesagent.hermes_android/mermaid_diagram';

  final String source;

  const MermaidDiagramPreview({super.key, required this.source});

  @override
  State<MermaidDiagramPreview> createState() => _MermaidDiagramPreviewState();
}

class _MermaidDiagramPreviewState extends State<MermaidDiagramPreview> {
  bool _showSource = false;

  @override
  Widget build(BuildContext context) {
    final supported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final canRender =
        supported &&
        widget.source.isNotEmpty &&
        widget.source.length <= MermaidDiagramPreview.maxSourceLength;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagram'),
        actions: [
          if (canRender)
            IconButton(
              tooltip: _showSource ? 'Show diagram' : 'Show source',
              icon: Icon(
                _showSource ? Icons.account_tree_outlined : Icons.code,
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
                      const Text('This diagram is available as source here.'),
                    MarkdownCodeBlock(
                      code: widget.source,
                      language: 'mermaid',
                      previewEnabled: false,
                    ),
                  ],
                ),
              )
            : AndroidView(
                key: ValueKey(theme.brightness),
                viewType: MermaidDiagramPreview.viewType,
                creationParamsCodec: const StandardMessageCodec(),
                creationParams: {
                  'source': widget.source,
                  'dark': theme.brightness == Brightness.dark,
                },
              ),
      ),
    );
  }
}
