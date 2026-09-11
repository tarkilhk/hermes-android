import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/attachment_draft.dart';
import 'package:hermes_android/core/services/composer_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory sandbox;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    sandbox = await Directory.systemTemp.createTemp('hermes-composer-draft-');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Future<AttachmentDraft> attachment(String name) async {
    final file = File('${sandbox.path}${Platform.pathSeparator}$name');
    await file.writeAsString('payload');
    return AttachmentDraft(
      id: name,
      cachedPath: file.path,
      name: name,
      byteLength: await file.length(),
      mediaType: 'text/plain',
      kind: AttachmentDraftKind.genericFile,
    );
  }

  test(
    'separates drafts by connection identity, profile, and session',
    () async {
      final first = ComposerDraftStore(
        preferences,
        connectionIdentity: 'host-auth-a',
      );
      final second = ComposerDraftStore(
        preferences,
        connectionIdentity: 'host-auth-b',
      );
      await first.write(
        profileName: 'work',
        sessionId: 'one',
        text: 'first',
        attachments: [await attachment('first.txt')],
      );
      await first.write(
        profileName: 'personal',
        sessionId: 'one',
        text: 'second',
        attachments: const [],
      );
      await second.write(
        profileName: 'work',
        sessionId: 'one',
        text: 'third',
        attachments: const [],
      );

      expect(
        (await first.read(profileName: 'work', sessionId: 'one'))!.text,
        'first',
      );
      expect(
        (await first.read(profileName: 'personal', sessionId: 'one'))!.text,
        'second',
      );
      expect(
        (await second.read(profileName: 'work', sessionId: 'one'))!.text,
        'third',
      );
    },
  );

  test('missing attachment reports failure without losing text', () async {
    final store = ComposerDraftStore(
      preferences,
      connectionIdentity: 'host-auth',
    );
    final file = await attachment('missing.txt');
    await store.write(
      profileName: 'work',
      sessionId: 'chat',
      text: 'keep this text',
      attachments: [file],
    );
    await File(file.cachedPath).delete();

    final restored = await store.read(profileName: 'work', sessionId: 'chat');
    expect(restored!.text, 'keep this text');
    expect(restored.attachments.single.status, AttachmentDraftStatus.failed);
    expect(restored.attachments.single.error, contains('no longer available'));
  });

  test('empty draft removes its durable record', () async {
    final store = ComposerDraftStore(
      preferences,
      connectionIdentity: 'host-auth',
    );
    await store.write(
      profileName: 'work',
      sessionId: 'chat',
      text: 'temporary',
      attachments: const [],
    );
    await store.write(
      profileName: 'work',
      sessionId: 'chat',
      text: '',
      attachments: const [],
    );

    expect(await store.read(profileName: 'work', sessionId: 'chat'), isNull);
    expect(
      preferences.getKeys().where((key) => key.startsWith('composer_drafts')),
      isEmpty,
    );
  });

  test('keeps the lost-acknowledgement marker with its draft', () async {
    final store = ComposerDraftStore(
      preferences,
      connectionIdentity: 'host-auth',
    );
    await store.write(
      profileName: 'work',
      sessionId: 'chat',
      text: 'possibly accepted',
      attachments: const [],
      submissionUncertain: true,
    );

    final restored = await store.read(profileName: 'work', sessionId: 'chat');
    expect(restored!.submissionUncertain, isTrue);
  });
}
