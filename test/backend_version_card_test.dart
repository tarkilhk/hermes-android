import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_android/core/widgets/backend_version_card.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profiles_repository.dart';

ProfileGateway gateway(
  Future<Map<String, dynamic>> Function(String, Map<String, String>) get,
) {
  return ProfileGateway(
    scope: WorkspaceScope(connectionId: 'c1', profileName: 'default'),
    get: get,
    rpc: (_, _) async => <String, dynamic>{},
    discover: () async => const ProfileDiscovery(
      profiles: [],
      currentName: null,
      activeName: null,
    ),
  );
}

void main() {
  testWidgets('shows backend identity and update status without initial RPC', (
    tester,
  ) async {
    var calls = 0;
    final scoped = gateway((endpoint, query) async {
      calls++;
      expect(endpoint, 'hermes/update/check');
      expect(query, {'force': 'true', 'profile': 'default'});
      return const {
        'current_version': '1.2.3',
        'install_method': 'pipx',
        'behind': 0,
        'update_available': false,
      };
    });
    await tester.pumpWidget(
      MaterialApp(home: BackendVersionCard(gateway: scoped)),
    );
    expect(calls, 0);
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('1.2.3'), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget);
  });

  testWidgets('manual check reports updates and cannot apply guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackendVersionCard(
          gateway: gateway(
            (_, _) async => const {
              'current_version': '1.2.3',
              'behind': 2,
              'update_available': true,
              'can_apply': false,
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Update available · 2 commits behind'), findsOneWidget);
    expect(
      find.text('Updates must be applied from the server host.'),
      findsOneWidget,
    );
  });

  testWidgets('does not claim current when server update distance is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackendVersionCard(
          gateway: gateway(
            (_, _) async => const {
              'current_version': 'unknown',
              'behind': -1,
              'update_available': false,
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Update status unavailable.'), findsOneWidget);
    expect(find.text('Up to date'), findsNothing);
  });

  testWidgets('treats a malformed update flag as unknown', (tester) async {
    final scoped = gateway(
      (_, _) async => const {
        'current_version': '1.2.3',
        'behind': 0,
        'update_available': 'false',
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: BackendVersionCard(gateway: scoped)),
    );
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Update status unavailable.'), findsOneWidget);
    expect(find.text('Up to date'), findsNothing);
  });

  testWidgets('keeps the action usable at narrow large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scoped = gateway(
      (_, _) async => const {
        'current_version': '1.2.3',
        'behind': 0,
        'update_available': false,
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: SingleChildScrollView(
            child: BackendVersionCard(gateway: scoped),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Check for updates'), findsOneWidget);
  });

  testWidgets('late response does not cross gateway ownership', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final first = gateway((_, _) => pending.future);
    final second = gateway(
      (_, _) async => const {
        'current_version': 'new-owner',
        'behind': 0,
        'update_available': false,
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: BackendVersionCard(gateway: first)),
    );
    await tester.tap(find.text('Check for updates'));
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(home: BackendVersionCard(gateway: second)),
    );
    pending.complete({
      'current_version': 'old-owner',
      'behind': 0,
      'update_available': false,
    });
    await tester.pump();

    expect(find.text('old-owner'), findsNothing);
    expect(find.text('Update status unavailable.'), findsOneWidget);
  });

  testWidgets('disposed card ignores a late response', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: BackendVersionCard(gateway: gateway((_, _) => pending.future)),
      ),
    );
    await tester.tap(find.text('Check for updates'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    pending.complete({
      'current_version': 'late',
      'behind': 0,
      'update_available': false,
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
