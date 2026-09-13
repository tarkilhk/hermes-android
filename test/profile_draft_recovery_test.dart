import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/models/queued_prompt_draft.dart';
import 'package:hermes_android/core/screens/profile_workspace_screen.dart';
import 'package:hermes_android/core/services/composer_draft_store.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/services/profiles_repository.dart';
import 'package:hermes_android/core/services/ws_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ColdDraftHost {
  int creates = 0;
  Object resumeError = JsonRpcError(
    'session.resume',
    'session not found',
    code: 4007,
  );
  Completer<void>? resumeStarted;
  Completer<void>? resumeDelay;
  final calls = <(String, Map<String, dynamic>)>[];

  Future<ProfileDiscovery> discover() async => const ProfileDiscovery(
    profiles: [HermesProfile(name: 'default')],
    currentName: 'default',
    activeName: 'default',
  );

  ProfileGateway gateway(WorkspaceScope scope) => ProfileGateway(
    scope: scope,
    discover: discover,
    get: (endpoint, query) async {
      if (endpoint == 'sessions') {
        return {
          'sessions': <Map<String, dynamic>>[],
          'offset': 0,
          'limit': 50,
          'total': 0,
        };
      }
      if (endpoint.endsWith('/messages')) {
        return {
          'session_id': endpoint.split('/')[1],
          'messages': <Map<String, dynamic>>[],
          'pagination': {
            'offset': 0,
            'limit': 50,
            'returned': 0,
            'order': 'latest',
          },
        };
      }
      throw StateError('Unexpected read: $endpoint');
    },
    rpc: (method, params) async {
      calls.add((method, params));
      switch (method) {
        case 'projects.tree':
          return {'projects': <Map<String, dynamic>>[]};
        case 'session.active_list':
          return {'sessions': <Map<String, dynamic>>[]};
        case 'session.create':
          creates++;
          final storedId = creates == 1
              ? 'orphan-draft'
              : creates == 2
              ? 'replacement-draft'
              : 'unexpected-replacement-$creates';
          return {
            'session_id': 'runtime-$storedId',
            'stored_session_id': storedId,
            'messages': <Map<String, dynamic>>[],
            'info': {'profile_name': scope.profileName},
          };
        case 'session.resume':
          if (params['session_id'] == 'orphan-draft') {
            resumeStarted?.complete();
            await resumeDelay?.future;
            throw resumeError;
          }
          throw StateError('Unexpected resume target');
        case 'session.history':
          return {'count': 0, 'messages': <Map<String, dynamic>>[]};
        default:
          return {};
      }
    },
  );
}

void main() {
  testWidgets(
    'ordinary Chats startup double tap recovers an unlisted draft once',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final host = _ColdDraftHost();
      final connection = SavedConnection(
        id: 'host',
        label: 'Host',
        host: 'localhost',
        port: 1,
        apiKey: '',
      );
      ProfileWorkspaceController buildController() =>
          ProfileWorkspaceController(
            connection: connection,
            connectionIdentity: 'verified-host-auth',
            preferences: preferences,
            gatewayFactory: host.gateway,
          );

      var controller = buildController();
      await controller.initialize();
      final original = await controller.createChat();
      await controller.updateDraft(
        original,
        'Ordinary restart draft QA retained',
      );
      await ComposerDraftStore(
        preferences,
        connectionIdentity: 'verified-host-auth',
      ).write(
        profileName: 'default',
        sessionId: original.key.sessionId,
        text: original.draft,
        attachments: const [],
        submissionUncertain: true,
      );
      controller.dispose();

      controller = buildController();
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.current!.visibleSessions, isEmpty);
      expect(
        (await ComposerDraftStore(
          preferences,
          connectionIdentity: 'verified-host-auth',
        ).read(profileName: 'default', sessionId: 'orphan-draft'))?.text,
        'Ordinary restart draft QA retained',
      );

      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ProfileWorkspaceScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved drafts'), findsOneWidget);
      expect(find.text('Ordinary restart draft QA retained'), findsOneWidget);
      host
        ..resumeStarted = Completer<void>()
        ..resumeDelay = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('saved-draft-orphan-draft')));
      await tester.pump();
      await host.resumeStarted!.future;
      await tester.tap(find.byKey(const ValueKey('saved-draft-orphan-draft')));
      await tester.pump();
      host.resumeDelay!.complete();
      await tester.pumpAndSettle();

      expect(host.creates, 2);
      expect(controller.current!.chat!.key.sessionId, 'replacement-draft');
      expect(
        controller.current!.chat!.draft,
        'Ordinary restart draft QA retained',
      );
      expect(controller.current!.chat!.draftSubmissionUncertain, isTrue);
      expect(find.text('Ordinary restart draft QA retained'), findsOneWidget);
      final store = ComposerDraftStore(
        preferences,
        connectionIdentity: 'verified-host-auth',
      );
      expect(
        await store.read(profileName: 'default', sessionId: 'orphan-draft'),
        isNull,
      );
      expect(
        (await store.read(
          profileName: 'default',
          sessionId: 'replacement-draft',
        ))?.text,
        'Ordinary restart draft QA retained',
      );
      expect(host.calls.where((call) => call.$1 == 'prompt.submit'), isEmpty);
    },
  );

  testWidgets(
    'saved drafts stay profile scoped and ambiguous resume preserves the source',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = ComposerDraftStore(
        preferences,
        connectionIdentity: 'verified-host-auth',
      );
      await store.write(
        profileName: 'default',
        sessionId: 'orphan-draft',
        text: 'Keep on ambiguous failure',
        attachments: const [],
      );
      await store.write(
        profileName: 'other',
        sessionId: 'other-draft',
        text: 'Other profile secret draft',
        attachments: const [],
      );
      await store.write(
        profileName: 'default',
        sessionId: 'queued-draft',
        text: '',
        attachments: const [],
        queuedPrompts: [QueuedPromptDraft(text: 'Follow up later')],
      );
      final host = _ColdDraftHost()
        ..creates = 1
        ..resumeError = TimeoutException('lost response');
      final controller = ProfileWorkspaceController(
        connection: SavedConnection(
          id: 'host',
          label: 'Host',
          host: 'localhost',
          port: 1,
          apiKey: '',
        ),
        connectionIdentity: 'verified-host-auth',
        preferences: preferences,
        gatewayFactory: host.gateway,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: ProfileWorkspaceScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keep on ambiguous failure'), findsOneWidget);
      expect(find.text('1 queued message'), findsOneWidget);
      expect(find.text('Other profile secret draft'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('saved-draft-orphan-draft')));
      await tester.pumpAndSettle();

      expect(controller.current!.chat, isNull);
      expect(host.creates, 1);
      expect(
        (await store.read(
          profileName: 'default',
          sessionId: 'orphan-draft',
        ))?.text,
        'Keep on ambiguous failure',
      );
      expect(
        (await store.read(
          profileName: 'other',
          sessionId: 'other-draft',
        ))?.text,
        'Other profile secret draft',
      );
    },
  );
}
