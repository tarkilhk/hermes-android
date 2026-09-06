import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/main.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_selection_store.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';

/// Opt-in emulator test against unmodified Hermes Desktop. With RUN_MODEL=true
/// this submits exactly one bounded prompt in the disposable android-qa-a profile.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const port = int.fromEnvironment('HERMES_TEST_PORT');
  const runModel = bool.fromEnvironment('RUN_MODEL');
  const projectPath = String.fromEnvironment('HERMES_TEST_PROJECT');
  testWidgets(
    'emulator profiles, project, attachment, background completion',
    (tester) async {
      expect(port, greaterThan(0), reason: 'Supply the local gateway port');
      final preferences = await SharedPreferences.getInstance();
      final manager = await ConnectionManager.create(preferences);
      final connection = SavedConnection(
        id: 'prestige-local-qa',
        label: 'Prestige local',
        host: '127.0.0.1',
        port: port,
        dashboardPortOverride: port,
        apiKey: '',
      );
      await manager.importConnections([connection], replaceExisting: false);
      await preferences.setString('last_connection_id', connection.id);
      await ProfileSelectionStore(
        preferences,
      ).write(connection.id, 'android-qa-a');
      await tester.pumpWidget(HermesApp(connManager: manager));
      Future<void> until(bool Function() condition, {int seconds = 30}) async {
        final deadline = DateTime.now().add(Duration(seconds: seconds));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(condition(), isTrue);
      }

      await until(
        () => find.byType(ProfileWorkspaceScreen).evaluate().isNotEmpty,
      );
      final screen = tester.widget<ProfileWorkspaceScreen>(
        find.byType(ProfileWorkspaceScreen),
      );
      final controller = screen.controller;
      await until(() => controller.current != null || controller.error != null);
      expect(controller.error, isNull);
      expect(controller.current!.scope.profileName, 'android-qa-a');
      expect(controller.discovery!.named('android-qa-b'), isNotNull);
      if (projectPath.isNotEmpty) {
        String normalize(String path) =>
            path.replaceAll('\\', '/').toLowerCase();
        bool matches(Map<String, dynamic> project) =>
            normalize(project['primary_path']?.toString() ?? '') ==
            normalize(projectPath);
        if (!controller.current!.projects.any(matches)) {
          await controller.createProject(
            'Android QA ${DateTime.now().millisecondsSinceEpoch}',
            projectPath,
          );
        }
        await controller.selectProject(
          controller.current!.projects.singleWhere(matches),
        );
        expect(controller.current!.projectSessionsError, isNull);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('New chat'));
      await until(() => controller.current!.chat != null);
      final a = controller.current!.chat!;
      String? profileAtCompletion;
      void observeCompletion() {
        if (a.status == ProfileTurnStatus.completed) {
          profileAtCompletion ??= controller.current?.scope.profileName;
        }
      }

      controller.addListener(observeCompletion);
      addTearDown(() => controller.removeListener(observeCompletion));
      final directory = await getTemporaryDirectory();
      final attachment = File('${directory.path}/android-qa.txt');
      await attachment.writeAsString('ANDROID_PROFILE_QA');
      await controller.addAttachment(a, attachment.path, 'android-qa.txt');
      await tester.pump();
      expect(find.text('android-qa.txt'), findsOneWidget);
      if (runModel) {
        a.draft =
            'This is one bounded Android integration test. Read the attached text file and reply with its exact contents only. Do not edit files, browse, delegate, or perform any other task.';
        await controller.send(a);
        expect(a.busy, isTrue, reason: a.error);
      }
      await tester.tap(find.byTooltip('Switch profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('android-qa-b').last);
      await until(
        () => controller.current?.scope.profileName == 'android-qa-b',
      );
      expect(controller.current!.chat, isNull);
      expect(find.text('android-qa.txt'), findsNothing);
      if (runModel) {
        await until(() => !a.busy, seconds: 120);
        expect(a.status, ProfileTurnStatus.completed, reason: a.error);
        expect(profileAtCompletion, 'android-qa-b');
        expect(
          a.messages.any(
            (m) =>
                m['role'] == 'assistant' &&
                m['content'].toString().contains('ANDROID_PROFILE_QA'),
          ),
          isTrue,
        );
      }
      await controller.openSession(a.key);
      await tester.pumpAndSettle();
      expect(controller.current!.scope.profileName, 'android-qa-a');
      expect(controller.current!.chat, same(a));
      await controller.reconnect(a.key.workspace);
      expect(controller.error, isNull);
      await attachment.delete();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
