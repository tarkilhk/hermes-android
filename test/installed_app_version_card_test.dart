import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:hermes_android/core/widgets/installed_app_version_card.dart';

void main() {
  testWidgets('shows installed app label, version/build, and package', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Hermes',
      packageName: 'com.example.hermes',
      version: '2.9.0',
      buildNumber: '2158',
      buildSignature: '',
      installerStore: '',
    );

    await tester.pumpWidget(const MaterialApp(home: InstalledAppVersionCard()));
    await tester.pumpAndSettle();

    expect(find.text('Hermes'), findsOneWidget);
    expect(find.textContaining('2.9.0 (2158)'), findsOneWidget);
    expect(find.textContaining('com.example.hermes'), findsOneWidget);
  });

  testWidgets('keeps a compact card layout at large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PackageInfo.setMockInitialValues(
      appName: 'Hermes',
      packageName: 'com.example.hermes',
      version: '2.9.0',
      buildNumber: '2158',
      buildSignature: '',
      installerStore: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const SingleChildScrollView(child: InstalledAppVersionCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hermes'), findsOneWidget);
  });
}
