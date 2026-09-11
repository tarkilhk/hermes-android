import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profiles_repository.dart';

void main() {
  final reads = <Map<String, String>>[];
  var repeatPage = false;
  var wrongChat = false;
  late ProfileGateway gateway;
  setUp(() {
    reads.clear();
    repeatPage = wrongChat = false;
    gateway = ProfileGateway(
      scope: WorkspaceScope(connectionId: 'host', profileName: 'work'),
      discover: () async => const ProfileDiscovery(
        profiles: [HermesProfile(name: 'work')],
        currentName: 'work',
        activeName: 'work',
      ),
      rpc: (_, _) async => {},
      get: (path, query) async {
        expect(path, 'sessions/chat/messages');
        reads.add(query);
        final offset = int.parse(query['offset']!);
        return {
          'session_id': wrongChat ? 'different' : 'chat',
          'messages': List.generate(
            offset == 0 || repeatPage ? 500 : 2,
            (i) => {
              'id': (repeatPage ? 0 : offset) + i + 1,
              'role': 'assistant',
              'content': 'Result $i',
            },
          ),
        };
      },
    );
  });
  test(
    'Find and Outputs receive all saved pages in original profile order',
    () async {
      final messages = await gateway.savedHistory('chat');
      expect(messages, hasLength(502));
      expect(messages.last['id'], 502);
      expect(reads, [
        {
          'profile': 'work',
          'limit': '500',
          'offset': '0',
          'order': 'oldest',
          'include_compacted': 'true',
        },
        {
          'profile': 'work',
          'limit': '500',
          'offset': '500',
          'order': 'oldest',
          'include_compacted': 'true',
        },
      ]);
    },
  );
  test(
    'repeated pages and a different chat fail instead of returning incomplete history',
    () async {
      repeatPage = true;
      await expectLater(gateway.savedHistory('chat'), throwsFormatException);
      repeatPage = false;
      wrongChat = true;
      await expectLater(gateway.savedHistory('chat'), throwsFormatException);
    },
  );
}
