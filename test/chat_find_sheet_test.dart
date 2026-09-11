import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_android/core/widgets/chat_find_sheet.dart';

void main() {
  testWidgets('loads once and filters message text locally', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatFindSheet(
          loadHistory: () async {
            calls++;
            return [
              {'role': 'user', 'content': 'Need the deployment checklist'},
              {'role': 'assistant', 'content': 'Here is the checklist'},
            ];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
    await tester.enterText(find.byType(TextField), 'deployment');
    await tester.pump();
    expect(find.text('Need the deployment checklist'), findsOneWidget);
    expect(find.text('Here is the checklist'), findsNothing);
    expect(find.text('1 matching messages'), findsOneWidget);
  });

  testWidgets('shows no matches and load failures clearly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatFindSheet(loadHistory: () async => throw StateError('offline')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('expands a match into selectable full text and counts capped results', (
    tester,
  ) async {
    final longText = List.filled(12, 'needle line').join('\n');
    await tester.pumpWidget(
      MaterialApp(
        home: ChatFindSheet(
          loadHistory: () async => [
            {'role': 'assistant', 'content': longText},
            ...List.generate(
              100,
              (_) => {'role': 'user', 'content': 'needle'},
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pump();
    expect(find.textContaining('Showing first 100 of 101'), findsOneWidget);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pump();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text(longText), findsOneWidget);
  });

  testWidgets('retry reloads after a history failure', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatFindSheet(
          loadHistory: () async {
            attempts++;
            if (attempts == 1) throw StateError('temporary failure');
            return [
              {'role': 'user', 'content': 'needle is back'},
            ];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('needle is back'), findsOneWidget);
  });
}
