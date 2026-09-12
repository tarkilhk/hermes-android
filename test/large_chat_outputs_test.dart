import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';

import 'support/profile_history_fixture.dart';

class _LargeChat extends ProfileHistoryFixture {
  @override
  List<Map<String, dynamic>> historyRows(String profile, String id) => [
    for (var i = 1; i <= 10000; i++)
      {
        'id': i,
        'role': 'assistant',
        'content': i == 10000
            ? 'Saved /srv/latest.pdf'
            : i == 9500
            ? 'Saved /srv/earlier.pdf'
            : i == 1
            ? 'Saved /srv/oldest.pdf'
            : 'Message $i',
      },
  ];
}

void main() {
  testWidgets(
    'Outputs opens a large chat without loading its entire transcript',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final host = _LargeChat();
      final controller = ProfileWorkspaceController(
        connection: SavedConnection(
          id: 'host',
          label: 'Test',
          host: 'localhost',
          port: 1,
          apiKey: '',
        ),
        connectionIdentity: 'test',
        preferences: await SharedPreferences.getInstance(),
        gatewayFactory: host.gateway,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.openSession(
        ProfileSessionKey(controller.current!.scope, 'chat-0'),
      );
      await tester.pumpWidget(
        MaterialApp(home: ProfileWorkspaceScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      host.reads.clear();
      await tester.tap(find.byTooltip('Chat actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outputs'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This chat is too large to load here. Use the paginated conversation view.',
        ),
        findsNothing,
      );
      expect(find.text('latest.pdf'), findsOneWidget);
      expect(
        host.reads.where((read) => read.$1.endsWith('/messages')),
        hasLength(1),
      );
      host.failHistory = true;
      await tester.tap(find.text('Load older outputs'));
      await tester.pumpAndSettle();
      expect(find.text('latest.pdf'), findsOneWidget);
      expect(
        find.textContaining('Your current results are still here'),
        findsOneWidget,
      );
      expect(find.text('History offline'), findsNothing);

      host.failHistory = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('earlier.pdf'), findsOneWidget);
      expect(find.text('latest.pdf'), findsOneWidget);
      final reads = host.reads
          .where((read) => read.$1.endsWith('/messages'))
          .toList();
      expect(reads.map((read) => read.$2['offset']), ['0', '500', '500']);
      expect(
        reads.every(
          (read) =>
              read.$2['profile'] == 'personal' && read.$2['limit'] == '500',
        ),
        isTrue,
      );

      for (var i = 0; i < 19; i++) {
        await tester.tap(find.text('Load older outputs'));
        await tester.pumpAndSettle();
      }
      expect(find.text('oldest.pdf'), findsOneWidget);
      expect(find.text('Load older outputs'), findsNothing);
      expect(find.text('latest.pdf'), findsOneWidget);
    },
  );
}
