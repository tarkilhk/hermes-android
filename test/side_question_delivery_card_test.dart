import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/side_question_delivery.dart';
import 'package:hermes_android/core/widgets/side_question_delivery_card.dart';

void main() {
  testWidgets('renders pending side questions as selectable delivery cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SideQuestionDeliveryCard(
            delivery: SideQuestionDelivery(
              taskId: 'task-1',
              question: 'What changed?',
              state: SideQuestionDeliveryState.pending,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Side question running'), findsOneWidget);
    expect(
      find.widgetWithText(SelectableText, 'What changed?'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(SelectableText, 'Waiting for the Hermes host.'),
      findsOneWidget,
    );
  });

  testWidgets('renders completed side-question result as selectable text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SideQuestionDeliveryCard(
            delivery: SideQuestionDelivery(
              taskId: 'task-1',
              question: 'What changed?',
              state: SideQuestionDeliveryState.completed,
              result: 'The server changed.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Side question answer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      find.widgetWithText(SelectableText, 'The server changed.'),
      findsOneWidget,
    );
  });
}
