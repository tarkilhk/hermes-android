import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/chat_output.dart';

void main() {
  test('extracts and deduplicates assistant-delivered outputs', () {
    final outputs = extractChatOutputs([
      {
        'role': 'assistant',
        'content': '''
Finished. MEDIA: "/srv/output/final report.pdf"
![chart](https://cdn.example.test/chart.png)
[source](https://example.test/results)
Also saved /srv/output/data.csv and /srv/output/data.csv.
''',
      },
    ]);

    expect(outputs.map((output) => output.target), [
      '/srv/output/final report.pdf',
      'https://cdn.example.test/chart.png',
      'https://example.test/results',
      '/srv/output/data.csv',
    ]);
    expect(outputs.map((output) => output.kind), [
      ChatOutputKind.file,
      ChatOutputKind.image,
      ChatOutputKind.link,
      ChatOutputKind.file,
    ]);
    expect(outputs.map((output) => output.label), [
      'final report.pdf',
      'chart.png',
      'results',
      'data.csv',
    ]);
    expect(outputs.first.path, '/srv/output/final report.pdf');
    expect(outputs[1].url, 'https://cdn.example.test/chart.png');
  });

  test('uses explicit producer fields and ignores passive tool paths', () {
    final outputs = extractChatOutputs([
      {
        'role': 'tool',
        'tool_name': 'web_search',
        'content': jsonEncode({
          'cache_path': '/srv/cache/passive.json',
          'source_url': 'https://example.test/passive',
        }),
      },
      {
        'role': 'tool',
        'tool_name': 'document_export',
        'content': jsonEncode({
          'output_path': '/srv/output/report.pdf',
          'cache_path': '/srv/cache/internal.json',
        }),
      },
      {
        'role': 'tool',
        'tool_name': 'write_file',
        'content': jsonEncode({
          'files_modified': ['/srv/output/notes.md'],
        }),
      },
    ]);

    expect(outputs.map((output) => output.target), [
      '/srv/output/report.pdf',
      '/srv/output/notes.md',
    ]);
  });

  test('extracts structured and wrapped browser screenshots', () {
    final outputs = extractChatOutputs([
      {
        'role': 'tool',
        'tool_name': 'browser_vision',
        'content': {
          '_multimodal': true,
          'meta': {'screenshot_path': '/srv/output/native.png'},
        },
      },
      {
        'role': 'tool',
        'tool_name': 'browser_vision',
        'content':
            'Image attached. Screenshot path: /srv/output/page capture.png',
      },
      {
        'role': 'tool',
        'tool_name': 'image_generate',
        'content': '''<untrusted_tool_result source="image_generate">
External data follows.

{"generated_image":"/srv/output/generated.webp"}
</untrusted_tool_result>''',
      },
    ]);

    expect(outputs.map((output) => output.target), [
      '/srv/output/native.png',
      '/srv/output/page capture.png',
      '/srv/output/generated.webp',
    ]);
    expect(
      outputs.every((output) => output.kind == ChatOutputKind.image),
      isTrue,
    );
  });

  test('accepts productive document formats from explicit delivery forms', () {
    final outputs = extractChatOutputs([
      {
        'role': 'assistant',
        'content': '''
MEDIA: report.docx
[Workbook](results.xlsx)
Mentioning draft.pptx in prose does not make it an output.
Saved /srv/output/slides.pptx.
''',
      },
      {
        'role': 'tool',
        'tool_name': 'document_export',
        'content': jsonEncode({'output_file': 'handout.pdf'}),
      },
    ]);

    expect(outputs.map((output) => output.target), [
      'report.docx',
      'results.xlsx',
      '/srv/output/slides.pptx',
      'handout.pdf',
    ]);
    expect(
      outputs.every((output) => output.kind == ChatOutputKind.file),
      isTrue,
    );
  });

  test('normalizes file URIs and gives embedded images a short label', () {
    final outputs = extractChatOutputs([
      {
        'role': 'assistant',
        'content': '''
MEDIA: file:///srv/output/report.pdf
MEDIA: file:///C:/Temp/workbook.xlsx
MEDIA: file://server/share/slides.pptx
![inline](data:image/png;base64,AAAA)
''',
      },
    ]);

    expect(outputs.map((output) => output.path), [
      '/srv/output/report.pdf',
      'C:/Temp/workbook.xlsx',
      '//server/share/slides.pptx',
      null,
    ]);
    expect(outputs.last.label, 'Embedded image');
  });
}
