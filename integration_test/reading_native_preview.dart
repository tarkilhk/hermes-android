/// Disposable Android entry point for exercising real PDF/media/WebView plugins.
/// Fixtures are generated locally; this target never connects to Hermes.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hermes_android/core/screens/pdf_preview_screen.dart';
import 'package:hermes_android/core/services/media_preview_service.dart';
import 'package:hermes_android/core/services/remote_files_client.dart';
import 'package:hermes_android/core/services/web_preview.dart';
import 'package:hermes_android/core/widgets/web_output_preview.dart';

void main() {
  if (!kDebugMode) throw StateError('Native reading QA requires debug mode.');
  runApp(
    MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: const _Menu()),
  );
}

class _Menu extends StatelessWidget {
  const _Menu();

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    Future<void> play(String filename, List<int> bytes) async {
      try {
        final opened = await const MediaPreviewService().open(
          RemoteFileDownload(filename: filename, bytes: bytes),
          title: filename,
        );
        if (!opened) throw StateError('Native player unavailable');
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Native reading QA')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Two-page PDF'),
            onTap: () => open(
              PdfPreviewScreen(
                title: 'QA two-page.pdf',
                download: () async =>
                    RemoteFileDownload(filename: 'qa.pdf', bytes: _pdf()),
              ),
            ),
          ),
          ListTile(
            title: const Text('Audio playback'),
            onTap: () => play('QA tone.wav', _wav()),
          ),
          ListTile(
            title: const Text('Video playback'),
            onTap: () => play(
              'QA test pattern.mp4',
              base64Decode(
                const String.fromEnvironment('HERMES_QA_VIDEO_BASE64'),
              ),
            ),
          ),
          ListTile(
            title: const Text('HTML preview'),
            onTap: () => open(
              const WebOutputPreview(
                title: 'QA HTML',
                format: WebOutputFormat.html,
                source:
                    '<!doctype html><html><meta name="viewport" content="width=device-width"><body style="background:#fff;color:#152231;padding:24px"><h1>Hermes reading check</h1><p>Local HTML preview.</p><button onclick="this.textContent=\'Interaction passed\'">Test interaction</button></body></html>',
              ),
            ),
          ),
          ListTile(
            title: const Text('Diagram preview'),
            onTap: () => open(
              const WebOutputPreview(
                title: 'QA diagram',
                format: WebOutputFormat.mermaid,
                source:
                    'flowchart TD\n  A[Draft] --> B[Hermes server]\n  B --> C[Read result]',
              ),
            ),
          ),
          ListTile(
            title: const Text('Browser preview'),
            onTap: () => openWebPreview(
              Uri.parse(
                const String.fromEnvironment(
                  'HERMES_QA_BROWSER_URL',
                  defaultValue: 'http://127.0.0.1:8765/',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Uint8List _pdf() {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>',
    for (final stream in [6, 7])
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] /Resources << /Font << /F1 5 0 R >> >> /Contents $stream 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    for (final page in [1, 2])
      _pdfStream('BT /F1 20 Tf 30 330 Td (Hermes PDF page $page) Tj ET'),
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(buffer.length);
    buffer.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
  }
  final start = buffer.length;
  buffer.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$start\n%%EOF\n',
  );
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}

String _pdfStream(String content) =>
    '<< /Length ${content.length} >>\nstream\n$content\nendstream';

Uint8List _wav() {
  const rate = 8000;
  const samples = rate * 12;
  final data = ByteData(44 + samples * 2);
  final bytes = data.buffer.asUint8List();
  void tag(int offset, String text) =>
      bytes.setRange(offset, offset + 4, ascii.encode(text));
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var sample = 0; sample < samples; sample++) {
    data.setInt16(
      44 + sample * 2,
      (sin(2 * pi * 440 * sample / rate) * 2000).round(),
      Endian.little,
    );
  }
  return bytes;
}
