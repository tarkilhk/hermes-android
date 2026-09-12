import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/screens/app_settings_content.dart';
import 'package:hermes_android/core/services/turn_notification_service.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Hermes',
      packageName: 'asia.hollinger.hermes',
      version: '2.9.0',
      buildNumber: '2158',
      buildSignature: '',
      installerStore: '',
    );
  });

  testWidgets('notification controls persist independently on this device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var permissionRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSettingsContent(
            preferences: preferences,
            onChanged: () {},
            enableNotifications: () async {
              permissionRequests++;
            },
          ),
        ),
      ),
    );
    final completion = find.widgetWithText(SwitchListTile, 'Completed work');
    await tester.scrollUntilVisible(completion, 300);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(completion);
    await tester.pumpAndSettle();
    expect(preferences.getBool(completionNotificationsKey), isFalse);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Needs attention'),
          )
          .value,
      isTrue,
    );
    expect(permissionRequests, 0);
    final previews = find.widgetWithText(
      SwitchListTile,
      'Show chat titles in alerts',
    );
    await tester.scrollUntilVisible(previews, 250);
    expect(tester.widget<SwitchListTile>(previews).value, isFalse);
    await tester.tap(previews);
    await tester.pumpAndSettle();
    expect(preferences.getBool(notificationTitlesKey), isTrue);
    final permission = find.text('Enable and test notifications');
    await tester.scrollUntilVisible(permission, 250);
    await tester.tap(permission);
    await tester.pumpAndSettle();
    expect(permissionRequests, 1);
    expect(preferences.getBool(completionNotificationsKey), isFalse);
  });
}
