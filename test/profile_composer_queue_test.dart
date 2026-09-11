import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/models/attachment_draft.dart';
import 'package:hermes_android/core/services/composer_draft_store.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'profile_workspace_controller_test.dart' show Host;

Future<void> until(bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(ready(), isTrue);
}

void main() {
  late Host host;
  late SharedPreferences prefs;
  late ProfileWorkspaceController controller;
  late ProfileChat chat;
  ProfileWorkspaceController makeController() => ProfileWorkspaceController(
    connection: SavedConnection(
      id: 'host',
      label: 'Host',
      host: 'localhost',
      port: 1,
      apiKey: '',
    ),
    connectionIdentity: 'queue-test',
    preferences: prefs,
    gatewayFactory: host.gateway,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    host = Host();
    controller = makeController();
    await controller.initialize();
    chat = await controller.createChat();
    chat.status = ProfileTurnStatus.running;
  });
  tearDown(() => controller.dispose());
  int sends() => host.calls.where((call) => call.$2 == 'prompt.submit').length;
  void finish() => host.event('a', 'turn.end', {'status': 'completed'});
  Future<ComposerDraftSnapshot?> saved() => ComposerDraftStore(
    prefs,
    connectionIdentity: 'queue-test',
  ).read(profileName: 'a', sessionId: chat.key.sessionId);

  test(
    'two queued messages send exactly once and leave a separate draft alone',
    () async {
      await controller.queuePrompt(chat, 'First');
      await controller.queuePrompt(chat, 'Second');
      await controller.updateDraft(chat, 'Still composing');
      final file = AttachmentDraft(
        id: 'draft-file',
        cachedPath: 'unused.txt',
        name: 'unused.txt',
        byteLength: 1,
        mediaType: 'text/plain',
        kind: AttachmentDraftKind.genericFile,
      );
      chat.attachments.add(file);
      finish();
      await until(() => sends() == 1 && !chat.queueDraining);
      expect(chat.queuedPrompts, ['Second']);
      expect(chat.draft, 'Still composing');
      expect(chat.attachments, [file]);
      finish();
      await until(() => sends() == 2 && !chat.queueDraining);
      expect(chat.queuedPrompts, isEmpty);
      expect(host.calls.where((call) => call.$2 == 'file.attach'), isEmpty);
      finish();
      await until(() => chat.status == ProfileTurnStatus.completed);
      expect(sends(), 2);
      expect(chat.draft, 'Still composing');
    },
  );

  test(
    'lost acknowledgement survives restart as a paused queue without resending',
    () async {
      await controller.queuePrompt(chat, 'Send once');
      host.promptSubmitFails = true;
      finish();
      await until(() => sends() == 1 && !chat.queueDraining);
      expect(chat.queuePaused, isTrue);
      expect(chat.queuedPrompts, ['Send once']);
      expect((await saved())!.queuePaused, isTrue);
      final key = chat.key;
      controller.dispose();
      host.running = false;
      controller = makeController();
      await controller.initialize();
      await controller.openSession(key);
      chat = controller.current!.chat!;
      expect(chat.queuePaused, isTrue);
      expect(chat.queuedPrompts, ['Send once']);
      expect(sends(), 1);
    },
  );

  test(
    'reopening refreshes Hermes before draining a saved unsent queue',
    () async {
      await controller.queuePrompt(chat, 'After the running turn');
      final key = chat.key;
      controller.dispose();
      host.running = false;
      controller = makeController();
      await controller.initialize();
      await controller.openSession(key);
      chat = controller.current!.chat!;
      expect(sends(), 1);
      expect(chat.queuedPrompts, isEmpty);
      final methods = host.calls.map((call) => call.$2).toList();
      expect(
        methods.indexOf('session.resume'),
        lessThan(methods.indexOf('prompt.submit')),
      );
    },
  );

  test(
    'the pending head is saved paused before its acknowledgement arrives',
    () async {
      await controller.queuePrompt(chat, 'First');
      await controller.queuePrompt(chat, 'Second');
      host.promptSubmitDelay = Completer<void>();
      finish();
      await until(() => sends() == 1);
      final snapshot = (await saved())!;
      expect(snapshot.queuePaused, isTrue);
      expect(snapshot.queuedPrompts, ['First', 'Second']);
      await controller.removeQueuedPrompt(chat, 0);
      expect(chat.queuedPrompts, ['First', 'Second']);
      await controller.stop(chat);
      host.promptSubmitDelay!.complete();
      await until(() => !chat.queueDraining);
      expect(chat.queuePaused, isTrue);
      expect(chat.queuedPrompts, ['Second']);
      finish();
      await until(() => chat.status == ProfileTurnStatus.completed);
      expect(sends(), 1);
    },
  );

  test(
    'a failed turn pauses remaining messages until explicitly resumed',
    () async {
      await controller.queuePrompt(chat, 'Follow-up');
      host.event('a', 'turn.end', {'status': 'error'});
      await until(() => chat.status == ProfileTurnStatus.failed);
      expect(chat.queuePaused, isTrue);
      expect(sends(), 0);
      host.running = false;
      await Future.wait([
        controller.resumeQueue(chat),
        controller.resumeQueue(chat),
      ]);
      expect(
        host.calls.where((call) => call.$2 == 'session.resume'),
        hasLength(1),
      );
      expect(sends(), 1);
      expect(chat.queuedPrompts, isEmpty);
    },
  );
}
