import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_output.dart';
import '../services/connection_manager.dart';
import '../services/android_file_delivery_service.dart';
import '../services/remote_files_client.dart';
import '../widgets/chat_image_preview.dart';
import '../widgets/markdown_code_block.dart';
import '../widgets/profile_message.dart';
import 'pdf_preview_screen.dart';

class ChatOutputsScreen extends StatefulWidget {
  final String chatTitle;
  final Future<List<Map<String, dynamic>>> Function() loadHistory;
  final Future<RemoteFileDownload> Function(String path) download;
  final Future<RemoteTextPreview> Function(String path) readText;
  final Future<void> Function(RemoteFileDownload)? deliver;
  final AndroidFileDeliveryService fileDelivery;

  const ChatOutputsScreen({
    super.key,
    required this.chatTitle,
    required this.loadHistory,
    required this.download,
    required this.readText,
    this.deliver,
    this.fileDelivery = const AndroidFileDeliveryService(),
  });

  @override
  State<ChatOutputsScreen> createState() => _ChatOutputsScreenState();
}

class _ChatOutputsScreenState extends State<ChatOutputsScreen> {
  late Future<List<ChatOutput>> _outputs = _load();
  bool _working = false;

  void _error(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is DashboardResponseTooLargeException
              ? 'This file exceeds the ${(error.maxBytes / (1024 * 1024)).round()} MiB download limit.'
              : 'This output could not be opened. It may have moved or be unavailable on Hermes.',
        ),
      ),
    );
  }

  Future<List<ChatOutput>> _load() async =>
      extractChatOutputs(await widget.loadHistory());

  Future<void> _share(RemoteFileDownload download) async {
    if (widget.deliver != null) return widget.deliver!(download);
    final directory = await (await getTemporaryDirectory()).createTemp(
      'hermes-output-',
    );
    final file = File('${directory.path}/${download.filename}');
    await file.writeAsBytes(download.bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _error(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openLink(String target) async {
    final uri = ProfileMessage.externalLink(target);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open link');
    }
  }

  Future<void> _preview(ChatOutput output) async {
    final path = output.path;
    if (output.kind == ChatOutputKind.image) {
      RemoteFileDownload? download;
      Uri? uri;
      if (path != null) {
        download = await widget.download(path);
      } else if (output.url!.startsWith('data:image/')) {
        final data = UriData.parse(output.url!);
        final extension =
            const {
              'image/png': 'png',
              'image/jpeg': 'jpg',
              'image/gif': 'gif',
              'image/webp': 'webp',
              'image/svg+xml': 'svg',
            }[data.mimeType] ??
            'img';
        download = RemoteFileDownload(
          filename: 'image.$extension',
          bytes: data.contentAsBytes(),
        );
      } else {
        uri = ProfileMessage.externalLink(output.url!);
        if (uri == null) throw StateError('Invalid image link');
      }
      if (!mounted) return;
      final imageFile = download;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (previewContext) => ChatImagePreview(
            uri: uri,
            bytes: imageFile?.bytes,
            title: output.label,
            actionLabel: imageFile == null
                ? 'Open in browser'
                : 'Save or share',
            onOpenExternal: () async {
              try {
                if (imageFile != null) {
                  await _share(imageFile);
                } else {
                  await _openLink(output.url!);
                }
              } catch (error) {
                if (previewContext.mounted) _error(previewContext, error);
              }
            },
          ),
        ),
      );
      return;
    }
    if (path == null) return _openLink(output.url!);
    final preview = await widget.readText(path);
    if (!mounted) return;
    final canOpen = widget.fileDelivery.supportsType(
      output.label,
      mimeType: preview.mimeType,
    );
    final isPdf =
        preview.mimeType.split(';').first.trim().toLowerCase() ==
            'application/pdf' ||
        output.label.toLowerCase().endsWith('.pdf');
    var delivering = false;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (previewContext, setPreviewState) {
            Future<void> deliverFile({required bool open}) async {
              if (!mounted || delivering) return;
              setPreviewState(() => delivering = true);
              try {
                final file = await widget.download(path);
                if (!mounted || !previewContext.mounted) return;
                if (open) {
                  final opened = await widget.fileDelivery.openInApp(
                    file,
                    mimeType: preview.mimeType,
                  );
                  if (!opened && previewContext.mounted) {
                    ScaffoldMessenger.of(previewContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No compatible app was found. Use Save or share instead.',
                        ),
                      ),
                    );
                  }
                } else {
                  await _share(file);
                }
              } catch (error) {
                if (previewContext.mounted) _error(previewContext, error);
              } finally {
                if (previewContext.mounted) {
                  setPreviewState(() => delivering = false);
                }
              }
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  output.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (preview.binary)
                    Text(
                      canOpen
                          ? 'Open this file in a compatible app, or save/share a copy.'
                          : 'Use Save or share to open this file in another app.',
                    )
                  else ...[
                    if (preview.truncated)
                      const Text(
                        'Preview shortened by Hermes. Save the file to read it all.',
                      ),
                    MarkdownCodeBlock(
                      code: preview.text,
                      language: preview.language,
                    ),
                  ],
                  if (isPdf)
                    FilledButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Read PDF'),
                      onPressed: delivering
                          ? null
                          : () async {
                              if (delivering) return;
                              setPreviewState(() => delivering = true);
                              try {
                                await Navigator.of(previewContext).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PdfPreviewScreen(
                                      title: output.label,
                                      download: () => widget.download(path),
                                    ),
                                  ),
                                );
                              } finally {
                                if (previewContext.mounted) {
                                  setPreviewState(() => delivering = false);
                                }
                              }
                            },
                    ),
                  if (canOpen)
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open in app'),
                      onPressed: delivering
                          ? null
                          : () => deliverFile(open: true),
                    ),
                  FilledButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Save or share'),
                    onPressed: delivering
                        ? null
                        : () => deliverFile(open: false),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Outputs · ${widget.chatTitle}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh outputs',
          icon: const Icon(Icons.refresh),
          onPressed: _working
              ? null
              : () => setState(() {
                  _outputs = _load();
                }),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_working) const LinearProgressIndicator(),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Files and links found in this chat. Some paths may no longer exist.',
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ChatOutput>>(
            future: _outputs,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          snapshot.error is StateError
                              ? (snapshot.error as StateError).message
                                    .toString()
                              : 'Outputs could not be loaded.',
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _outputs = _load();
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final outputs = snapshot.data ?? [];
              if (outputs.isEmpty) {
                return const Center(
                  child: Text('No files or links found in this chat.'),
                );
              }
              return ListView.builder(
                itemCount: outputs.length,
                itemBuilder: (context, index) {
                  final output = outputs[index];
                  return ListTile(
                    leading: Icon(switch (output.kind) {
                      ChatOutputKind.image => Icons.image_outlined,
                      ChatOutputKind.file => Icons.insert_drive_file_outlined,
                      ChatOutputKind.link => Icons.link,
                    }),
                    title: Text(
                      output.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      output.target,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: _working ? null : () => _run(() => _preview(output)),
                    trailing: output.path == null
                        ? null
                        : IconButton(
                            tooltip: 'Save or share ${output.label}',
                            icon: const Icon(Icons.ios_share),
                            onPressed: _working
                                ? null
                                : () => _run(
                                    () async => _share(
                                      await widget.download(output.path!),
                                    ),
                                  ),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
