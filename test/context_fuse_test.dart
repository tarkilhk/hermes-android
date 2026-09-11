import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_android/core/models/context_occupancy.dart';
import 'package:hermes_android/core/widgets/context_fuse.dart';

void main() {
  test('parses and clamps server occupancy', () {
    final value = ContextOccupancy.fromJson({
      'context_used': 1200,
      'context_max': 1000,
      'context_percent': 125.5,
      'context_estimated': true,
    });
    expect(value, isNotNull);
    expect(value!.used, 1200);
    expect(value.max, 1000);
    expect(value.percent, 100);
    expect(value.estimated, isTrue);
  });

  test('returns unknown for missing, zero, or nonfinite server values', () {
    expect(ContextOccupancy.fromJson(null), isNull);
    expect(ContextOccupancy.fromJson({'context_used': 1, 'context_max': 0, 'context_percent': 1}), isNull);
    expect(ContextOccupancy.fromJson({'context_used': 1, 'context_max': 10, 'context_percent': double.nan}), isNull);
  });

  testWidgets('renders an accessible unknown fuse without animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ContextFuse()));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Context usage unknown'), findsOneWidget);
  });

  testWidgets('renders estimated usage and a filled fuse', (tester) async {
    const occupancy = ContextOccupancy(
      used: 800,
      max: 1000,
      percent: 80,
      estimated: true,
    );
    await tester.pumpWidget(const MaterialApp(home: ContextFuse(occupancy: occupancy)));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Approximately 800 of 1000 tokens, 80 percent used'), findsOneWidget);
  });
}
