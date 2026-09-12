import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/services/ws_client.dart';
import 'package:hermes_android/core/widgets/profile_review_notice_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_connection_identity_test.dart' show identityTestConnection;
import 'support/profile_history_fixture.dart';

class _ReviewFixture extends ProfileHistoryFixture {
  final gateways = <String, ProfileGateway>{};
  final runtimeOverrides = <String, String>{};

  @override
  ProfileGateway gateway(WorkspaceScope scope) {
    final base = super.gateway(scope);
    final gateway = ProfileGateway(
      scope: scope,
      discover: base.discover,
      connect: base.connect,
      close: base.close,
      get: base.read,
      rpc: (method, params) async {
        if (method == 'session.resume') {
          final sessionId = params['session_id'] as String;
          return {
            'session_id': runtimeOverrides[sessionId] ?? '$sessionId-runtime',
            'stored_session_id': sessionId,
            'messages': const [],
            'info': {'profile_name': scope.profileName},
          };
        }
        return base.call(method, params);
      },
    );
    gateways[scope.profileName] = gateway;
    return gateway;
  }

  void event(String profile, String sessionId, Map<String, dynamic> data) {
    gateways[profile]!.onEvent!(
      StreamEvent(type: 'review.summary', data: data, sessionId: sessionId),
    );
  }
}

void main() {
  late _ReviewFixture fixture;
  late SharedPreferences preferences;
  late ProfileWorkspaceController controller;

  Future<ProfileWorkspaceController> makeController() async {
    final next = ProfileWorkspaceController(
      connection: identityTestConnection(),
      connectionIdentity: 'review-notices',
      preferences: preferences,
      gatewayFactory: fixture.gateway,
    );
    await next.initialize();
    return next;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    fixture = _ReviewFixture()..messageCount = 0;
    controller = await makeController();
  });

  tearDown(() => controller.dispose());

  testWidgets('routes review summaries to the owning chat and renders a card', (
    tester,
  ) async {
    final scope = controller.current!.scope;
    await controller.openSession(ProfileSessionKey(scope, 'chat-0'));
    final owner = controller.current!.chat!;
    await controller.openSession(ProfileSessionKey(scope, 'chat-1'));

    fixture.event('personal', owner.runtimeId, {
      'text': 'Two changes need a closer look.',
    });

    expect(owner.reviewNotices.single.text, 'Two changes need a closer look.');
    expect(controller.current!.chat!.reviewNotices, isEmpty);

    await controller.openSession(owner.key);
    await tester.pumpWidget(
      MaterialApp(home: ProfileWorkspaceScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileReviewNoticeCard), findsOneWidget);
    expect(find.text('Hermes review'), findsOneWidget);
    expect(find.text('Two changes need a closer look.'), findsOneWidget);
  });

  test(
    'ignores malformed summaries and keeps only the newest bounded set',
    () async {
      final scope = controller.current!.scope;
      await controller.openSession(ProfileSessionKey(scope, 'chat-0'));
      final chat = controller.current!.chat!;

      fixture.event('personal', chat.runtimeId, const {});
      fixture.event('personal', chat.runtimeId, {'text': '   '});
      fixture.event('personal', chat.runtimeId, {'text': 7});
      fixture.event('personal', chat.runtimeId, {
        'text': ['review'],
      });
      fixture.event('personal', chat.runtimeId, {
        'text': {'summary': 'review'},
      });
      fixture.event('personal', chat.runtimeId, {'text': 'Review 0'});
      for (var i = 0; i <= 20; i++) {
        fixture.event('personal', chat.runtimeId, {'text': 'Review $i'});
      }

      expect(chat.reviewNotices, hasLength(20));
      expect(chat.reviewNotices.first.text, 'Review 1');
      expect(chat.reviewNotices.last.text, 'Review 20');
    },
  );

  test(
    'review summaries have no durability across a runtime or controller reset',
    () async {
      final scope = controller.current!.scope;
      await controller.openSession(ProfileSessionKey(scope, 'chat-0'));
      final chat = controller.current!.chat!;
      fixture.event('personal', chat.runtimeId, {'text': 'Transient review'});

      await controller.reconnect(scope);
      expect(chat.reviewNotices.single.text, 'Transient review');

      fixture.runtimeOverrides['chat-0'] = 'chat-0-replaced-runtime';
      await controller.reconnect(scope);
      expect(chat.reviewNotices, isEmpty);

      fixture.event('personal', chat.runtimeId, {'text': 'Another review'});
      controller.dispose();
      controller = await makeController();
      await controller.openSession(ProfileSessionKey(scope, 'chat-0'));
      expect(controller.current!.chat!.reviewNotices, isEmpty);
    },
  );
}
