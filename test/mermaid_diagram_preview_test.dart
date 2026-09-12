import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/widgets/markdown_code_block.dart';
import 'package:hermes_android/core/widgets/mermaid_diagram_preview.dart';
import 'package:hermes_android/core/widgets/profile_message.dart';

void main() {
  test('only complete non-streaming Mermaid blocks offer rendering', () {
    const source = '```mermaid\ngraph TD\nA --> B\n```';
    final complete =
        splitMarkdownCodeBlocks(source).single as MarkdownCodeBlock;
    expect(complete.previewEnabled, isTrue);
    expect(complete.code, 'graph TD\nA --> B\n');
    expect(
      (splitMarkdownCodeBlocks(source, streaming: true).single
              as MarkdownCodeBlock)
          .previewEnabled,
      isFalse,
    );
    expect(
      (splitMarkdownCodeBlocks('```mermaid\ngraph TD').single
              as MarkdownCodeBlock)
          .previewEnabled,
      isFalse,
    );
  });

  testWidgets('oversized diagrams keep source and copy without a native view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownCodeBlock(
            language: 'mermaid',
            code: 'A' * (MermaidDiagramPreview.maxSourceLength + 1),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Open diagram'), findsNothing);
    expect(find.byTooltip('Copy code'), findsOneWidget);
    expect(find.byType(AndroidView), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'diagram opens on tap and returns to chat at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final nativeCalls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (call) async {
            nativeCalls.add(call);
            if (call.method == 'create') return 1;
            if (call.method == 'resize') {
              final args = call.arguments as Map;
              return {'width': args['width'], 'height': args['height']};
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
        });
        const source = 'graph TD\nA[Plan] --> B[Deliver]\n';
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ProfileMessage(
                  message: {
                    'role': 'assistant',
                    'content': 'A plan\n```mermaid\n$source```',
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nativeCalls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Open diagram'));
        await tester.pumpAndSettle();
        final create = nativeCalls.singleWhere(
          (call) => call.method == 'create',
        );
        final args = create.arguments as Map;
        expect(args['viewType'], MermaidDiagramPreview.viewType);
        expect(
          const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(args['params'] as Uint8List),
          ),
          {'source': source, 'dark': true},
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Show source'));
        await tester.pumpAndSettle();
        expect(find.byType(AndroidView), findsNothing);
        expect(find.byTooltip('Copy code'), findsOneWidget);
        expect(find.byTooltip('Open diagram'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('A plan'), findsOneWidget);
        expect(find.byTooltip('Open diagram'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
