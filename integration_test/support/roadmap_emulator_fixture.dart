import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/ws_client.dart';

import '../../test/support/profile_history_fixture.dart';

/// In-memory gateway data for the roadmap emulator suite.
///
/// Every transport boundary is replaced. The widgets and workspace controller
/// are the production implementations, but this fixture cannot reach a Hermes
/// host or submit work to a model.
class RoadmapEmulatorFixture extends ProfileHistoryFixture {
  final gateways = <String, ProfileGateway>{};
  final configWrites = <Map<String, dynamic>>[];
  final approvalResponses = <Map<String, dynamic>>[];
  final commandDispatches = <Map<String, dynamic>>[];
  final projectCreates = <Map<String, dynamic>>[];
  final createdProjects = <String, List<Map<String, dynamic>>>{};

  @override
  List<Map<String, dynamic>> projects(String profile) => [
    ...super.projects(profile),
    ...createdProjects[profile] ?? const [],
  ];

  @override
  List<Map<String, dynamic>> historyRows(String profile, String id) => [
    for (var i = 1; i <= messageCount; i++)
      {
        'id': i,
        'role': i.isEven ? 'assistant' : 'user',
        'content': i == 618
            ? 'Roadmap needle: the emulator found this saved answer.'
            : i == 616
            ? 'Saved /tmp/roadmap-notes.md for the emulator review.'
            : '$profile message $i',
        'display_content': i == 618
            ? 'Roadmap needle: the emulator found this saved answer.'
            : i == 616
            ? 'Saved /tmp/roadmap-notes.md for the emulator review.'
            : '$profile message $i',
      },
  ];

  @override
  ProfileGateway gateway(WorkspaceScope scope) {
    final base = super.gateway(scope);
    late final ProfileGateway fixtureGateway;
    fixtureGateway = ProfileGateway(
      scope: scope,
      discover: base.discover,
      connect: base.connect,
      close: base.close,
      get: (path, query) async {
        if (path == 'model/info') {
          return {'model': 'gpt-6-astra', 'provider': 'openai-codex'};
        }
        if (path == 'model/options') {
          return {
            'providers': [
              {
                'slug': 'openai-codex',
                'name': 'OpenAI subscription',
                'models': ['gpt-6-astra', 'gpt-5.6-sol'],
              },
            ],
          };
        }
        return base.read(path, query);
      },
      rpc: (method, params) async {
        switch (method) {
          case 'session.context_breakdown':
            return {
              'context_used': 32768,
              'context_max': 131072,
              'context_percent': 25,
            };
          case 'config.get':
            return {'value': 'high'};
          case 'config.set':
            configWrites.add(Map<String, dynamic>.from(params));
            return {'status': 'ok'};
          case 'commands.catalog':
            return {
              'pairs': [
                ['/roadmap-check', 'Run the isolated roadmap check'],
              ],
              'canon': <String, String>{},
              'categories': [
                {
                  'name': 'Checks',
                  'pairs': [
                    ['/roadmap-check', 'Run the isolated roadmap check'],
                  ],
                },
              ],
            };
          case 'complete.slash':
            return {'items': <Map<String, dynamic>>[], 'replace_from': 0};
          case 'command.dispatch':
            commandDispatches.add(Map<String, dynamic>.from(params));
            return {
              'type': 'exec',
              'output': 'Roadmap fixture command complete',
            };
          case 'approval.respond':
            approvalResponses.add(Map<String, dynamic>.from(params));
            return {'status': 'ok'};
          case 'projects.discover_repos':
            return {
              'repos': const [
                {'root': '/srv/hermes-android', 'label': 'Hermes Android'},
              ],
            };
          case 'projects.create':
            projectCreates.add(Map<String, dynamic>.from(params));
            createdProjects.putIfAbsent(scope.profileName, () => []).add({
              'id': 'roadmap-created',
              'label': params['name'],
              'path': params['primary_path'],
              'lastActive': now + 1,
            });
            return {
              'project': {'id': 'roadmap-created'},
            };
          case 'session.resume':
          case 'session.create':
            final response = await base.call(method, params);
            return {
              ...response,
              'info': {
                'profile_name': scope.profileName,
                'model': 'gpt-6-astra',
                'provider': 'openai-codex',
                'reasoning_effort': 'high',
              },
            };
          default:
            return base.call(method, params);
        }
      },
    );
    gateways[scope.profileName] = fixtureGateway;
    return fixtureGateway;
  }

  void requestApproval(String profile, String runtimeId) {
    gateways[profile]!.onEvent!(
      StreamEvent(
        type: 'approval.request',
        sessionId: runtimeId,
        data: const {
          'request_id': 'roadmap-approval',
          'command': 'echo isolated-roadmap-check',
          'choices': ['once', 'session', 'deny'],
        },
      ),
    );
  }

  void deliverReview(String profile, String runtimeId) {
    gateways[profile]!.onEvent!(
      StreamEvent(
        type: 'review.summary',
        sessionId: runtimeId,
        data: const {'text': 'Roadmap review needs a human check.'},
      ),
    );
  }

  void requestVaultUnlock(String profile, String runtimeId) {
    gateways[profile]!.onEvent!(
      StreamEvent(
        type: 'vault.unlock.request',
        sessionId: runtimeId,
        data: const {
          'request_id': 'roadmap-vault-unlock',
          'backend': 'roadmap-vault',
          'display_name': 'Roadmap Vault',
        },
      ),
    );
  }
}

class RoadmapMemoryCredentialStore implements CredentialStore {
  final _values = <String, String>{};
  final _cache = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
    _cache.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    final value = _values[key];
    if (value == null) {
      _cache.remove(key);
    } else {
      _cache[key] = value;
    }
    return value;
  }

  @override
  String? readCached(String key) => _cache[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
    _cache[key] = value;
  }
}
