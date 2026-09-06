import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';

import 'profile_connection_identity_test.dart' show identityTestConnection;
import 'profile_workspace_controller_test.dart' show Host;

void main() {
  testWidgets(
    'batch question renders and Reply closes without disposed-controller errors',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final host = Host();
      final controller = ProfileWorkspaceController(
        connection: identityTestConnection(),
        connectionIdentity: 'test-identity',
        preferences: await SharedPreferences.getInstance(),
        gatewayFactory: host.gateway,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final chat = await controller.createChat();
      chat.status = ProfileTurnStatus.attention;
      chat.clarification = {
        'request_id': 'recovered-request',
        'questions': [
          {'qid': 'q0', 'question': 'What is the recovery marker?'},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(home: ProfileWorkspaceScreen(controller: controller)),
      );
      expect(find.text('What is the recovery marker?'), findsOneWidget);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Answer'),
        'PROCESS_RECOVERY_QA',
      );
      await tester.tap(find.text('Continue'));
      // Reply resumes work; let the dialog finish closing without waiting for
      // the ongoing runtime indicator to stop animating.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Reply to Hermes'), findsNothing);
      expect(host.calls.last.$3['question_id'], 'q0');
      expect(host.calls.last.$3['answer'], 'PROCESS_RECOVERY_QA');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
