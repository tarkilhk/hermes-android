import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/android_share_intent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AndroidShareIntentService.channelName);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'initializes from a cold-start mixed share and consumes it once',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getInitialShare');
            return {
              'text': '  https://example.com/article  ',
              'files': [
                {
                  'path': '/cache/shared/photo.jpg',
                  'name': 'photo.jpg',
                  'mediaType': 'image/jpeg',
                  'byteLength': 123,
                },
              ],
            };
          });

      final service = AndroidShareIntentService();
      await service.initialize();

      final payload = service.pendingShare.value;
      expect(payload?.text, 'https://example.com/article');
      expect(payload?.files.single.name, 'photo.jpg');
      expect(payload?.files.single.byteLength, 123);
      expect(service.acknowledgeShare(payload!), isTrue);
      expect(service.pendingShare.value, isNull);
      expect(service.acknowledgeShare(payload), isFalse);
    },
  );

  test('receives a warm multiple-file share from Android', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    final service = AndroidShareIntentService();
    await service.initialize();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('sharePayload', {
              'text': 'Review these',
              'files': [
                {
                  'path': '/cache/shared/one.pdf',
                  'name': 'one.pdf',
                  'mediaType': 'application/pdf',
                  'byteLength': 10,
                },
                {
                  'path': '/cache/shared/two.txt',
                  'name': 'two.txt',
                  'mediaType': 'text/plain',
                  'byteLength': 20,
                },
              ],
            }),
          ),
          (_) {},
        );

    final payload = service.pendingShare.value;
    expect(payload?.text, 'Review these');
    expect(payload?.files.map((file) => file.name), ['one.pdf', 'two.txt']);
    expect(service.acknowledgeShare(payload!), isTrue);
    expect(service.pendingShare.value, isNull);
  });

  test(
    'a later share waits until the exact reviewed payload is acknowledged',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      final service = AndroidShareIntentService();
      await service.initialize();
      for (final text in ['First share', 'Second share']) {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              channel.name,
              channel.codec.encodeMethodCall(
                MethodCall('sharePayload', {'text': text}),
              ),
              (_) {},
            );
      }
      final first = service.pendingShare.value!;
      expect(first.text, 'First share');
      expect(
        service.acknowledgeShare(
          const AndroidSharePayload(text: 'First share'),
        ),
        isFalse,
      );
      expect(service.pendingShare.value, same(first));
      expect(service.acknowledgeShare(first), isTrue);
      final second = service.pendingShare.value!;
      expect(second.text, 'Second share');
      expect(service.acknowledgeShare(first), isFalse);
      expect(service.pendingShare.value, same(second));
      expect(service.acknowledgeShare(second), isTrue);
      expect(service.pendingShare.value, isNull);
      service.dispose();
    },
  );
}
