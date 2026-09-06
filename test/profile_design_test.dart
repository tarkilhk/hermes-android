import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/core/theme/profile_workspace_theme.dart';
import 'package:hermes_android/core/widgets/profile_tool_activity.dart';
import 'support/profile_actions_fixture.dart';
import 'profile_connection_identity_test.dart' show identityTestConnection;

void main() {
  late ProfileActionsFixture host;
  late ProfileWorkspaceController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    host = ProfileActionsFixture();
    controller = ProfileWorkspaceController(
      connection: identityTestConnection(),
      connectionIdentity: 'design',
      preferences: await SharedPreferences.getInstance(),
      gatewayFactory: host.gateway,
    );
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  Future<void> show(WidgetTester tester, {double scale = 1, Key? key}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: hermesTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ProfileWorkspaceScreen(key: key, controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'all accents retain text, action and user-bubble contrast in both themes',
    () {
      for (final brightness in Brightness.values) {
        for (final accent in WorkspaceAccent.values) {
          final theme = profileWorkspaceTheme(
            hermesTheme(brightness),
            accent: accent,
          );
          final c = theme.colorScheme;
          for (final pair in [
            (c.onSurface, c.surface),
            (c.onSurfaceVariant, c.surface),
            (c.onSurfaceVariant, c.surfaceContainerLow),
            (c.onPrimary, c.primary),
            (c.primary, c.surface),
            (c.onPrimaryContainer, c.primaryContainer),
          ]) {
            expect(
              contrastRatio(pair.$1, pair.$2),
              greaterThanOrEqualTo(4.5),
              reason: '${brightness.name}/${accent.name}',
            );
          }
          expect(
            theme.extension<HermesTokens>()!.running,
            HermesTokens.forBrightness(brightness).running,
          );
        }
      }
    },
  );

  testWidgets(
    'visible project overflow opens a compact menu, Back does not create',
    (tester) async {
      await show(tester);
      final row = find.byKey(const ValueKey('project-p2'));
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Project actions')),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('action-new'));
      expect(tester.getSize(action).width, lessThan(320));
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(find.text('New chat in project'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(host.calls.where((call) => call.$2 == 'session.create'), isEmpty);
      expect(controller.current!.chat, isNull);
    },
  );

  testWidgets(
    'accent selection is local, persists and survives profile changes',
    (tester) async {
      await show(tester);
      await tester.tap(find.byTooltip('Workspace options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accent color'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('accent-iris')));
      await tester.pumpAndSettle();
      expect(
        controller.preferences.getString(WorkspaceAccent.preferenceKey),
        'iris',
      );
      await controller.navigateProfile('work');
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.colorScheme.primary, WorkspaceAccent.iris.light);
      await show(tester, key: const ValueKey('recreated'));
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary,
        WorkspaceAccent.iris.light,
      );
      expect(host.updates, isEmpty);
      expect(host.deletes, isEmpty);
    },
  );

  testWidgets('large-text workspace and menus fit a narrow screen', (
    tester,
  ) async {
    await show(tester, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.longPress(find.byKey(const ValueKey('project-p2')));
    await tester.pumpAndSettle();
    expect(find.text('New chat in project'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final bounds = tester.getRect(find.byKey(const ValueKey('action-new')));
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(360));
    expect(bounds.bottom, lessThanOrEqualTo(800));
  });

  test(
    'tool grouping preserves chronology, non-tools and newest anchor IDs',
    () {
      final rows = <Map<String, dynamic>>[
        {'id': 1, 'role': 'user'},
        {'id': 2, 'role': 'tool'},
        {'id': 3, 'role': 'tool'},
        {'id': 4, 'role': 'assistant'},
        {'id': 5, 'role': 'tool'},
        {'id': 6, 'role': 'system'},
      ];
      final groups = groupTranscriptRows(rows);
      expect(groups.map((group) => group.map((row) => row['id']).toList()), [
        [1],
        [2, 3],
        [4],
        [5],
        [6],
      ]);
      expect(rows.length, 6);
      final extended = groupTranscriptRows([
        {'id': 0, 'role': 'tool'},
        ...rows.skip(1),
      ]);
      expect(extended.first.last['id'], 3);
    },
  );

  testWidgets(
    'conversation groups contiguous tools without hiding the answer',
    (tester) async {
      final chat = await controller.createChat();
      chat.messages.addAll([
        {'id': 1, 'role': 'user', 'content': 'Check the project'},
        {
          'id': 2,
          'role': 'tool',
          'tool_name': 'Read',
          'content': 'Private tool detail A',
        },
        {
          'id': 3,
          'role': 'tool',
          'tool_name': 'Search',
          'content': 'Private tool detail B',
        },
        {'id': 4, 'role': 'assistant', 'content': 'Here is the answer.'},
      ]);
      await show(tester);
      expect(find.text('2 tool results'), findsOneWidget);
      expect(find.text('Private tool detail A'), findsNothing);
      expect(find.text('Here is the answer.'), findsOneWidget);
      await tester.tap(find.text('2 tool results'));
      await tester.pumpAndSettle();
      expect(find.text('Private tool detail A'), findsOneWidget);
      expect(find.text('Private tool detail B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
