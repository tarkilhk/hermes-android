import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/hermes_profile.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/profile_gateway.dart';
import 'package:hermes_android/core/services/profile_workspace_controller.dart';
import 'package:hermes_android/core/services/ws_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_workspace_controller_test.dart' show Host;

class SensitivePromptHost extends Host {
  Completer<void>? responseDelay;
  Object? responseError;
  String? resumedRuntime;
  Object? pendingSensitive;
  bool includePendingSensitive = true;

  @override
  ProfileGateway gateway(WorkspaceScope scope) {
    final base = super.gateway(scope);
    final wrapped = ProfileGateway(
      scope: scope,
      discover: discover,
      connect: base.connect,
      close: base.close,
      get: base.read,
      rpc: (method, params) async {
        final response = base.call(method, params);
        if ({
          'sudo.respond',
          'secret.respond',
          'vault.unlock.respond',
          'vault.save_login.respond',
          'vault.code.respond',
        }.contains(method)) {
          await responseDelay?.future;
          final error = responseError;
          if (error != null) throw error;
        }
        final result = await response;
        if (method == 'session.resume' && resumedRuntime != null) {
          return {
            ...result,
            'session_id': resumedRuntime,
            if (includePendingSensitive) 'pending_sensitive': pendingSensitive,
          };
        }
        if (method == 'session.resume') {
          return {
            ...result,
            if (includePendingSensitive) 'pending_sensitive': pendingSensitive,
          };
        }
        return result;
      },
    );
    gateways[scope.profileName] = wrapped;
    return wrapped;
  }
}

void main() {
  late SensitivePromptHost host;
  late ProfileWorkspaceController controller;
  late SharedPreferences preferences;
  late ProfileChat chat;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    host = SensitivePromptHost();
    controller = ProfileWorkspaceController(
      connectionIdentity: 'sensitive-prompt-test',
      connection: SavedConnection(
        id: 'host',
        label: 'Host',
        host: 'localhost',
        port: 1,
        apiKey: '',
      ),
      preferences: preferences,
      gatewayFactory: host.gateway,
    );
    await controller.initialize();
    chat = await controller.createChat();
  });

  tearDown(() => controller.dispose());

  test(
    'routes sudo and secret responses through their exact profile owner',
    () async {
      chat.draft = 'composer marker';
      const cases = [
        (
          event: 'sudo.request',
          id: 'sudo-1',
          method: 'sudo.respond',
          field: 'password',
        ),
        (
          event: 'secret.request',
          id: 'secret-1',
          method: 'secret.respond',
          field: 'value',
        ),
      ];

      for (final value in cases) {
        host.event('a', value.event, {
          'request_id': value.id,
          'env_var': 'FIXTURE_TOKEN',
          'prompt': 'Enter the fixture token',
        });
        final request = chat.sensitivePrompt!;

        await controller.respondSensitivePrompt(
          chat,
          'synthetic-secret',
          expectedRequest: request,
        );

        expect(host.calls.last.$2, value.method);
        expect(host.calls.last.$3, {
          'request_id': value.id,
          value.field: 'synthetic-secret',
          'profile': 'a',
        });
        expect(chat.sensitivePrompt, isNull);
      }

      expect(chat.draft, 'composer marker');
      expect(chat.messages.toString(), isNot(contains('synthetic-secret')));
      expect(chat.error, isNull);
      expect(
        [
          for (final key in preferences.getKeys()) preferences.get(key),
        ].toString(),
        isNot(contains('synthetic-secret')),
      );
    },
  );

  test('cancel sends the official empty value', () async {
    host.event('a', 'secret.request', {
      'request_id': 'secret-cancel',
      'env_var': 'FIXTURE_TOKEN',
    });
    final request = chat.sensitivePrompt!;

    await controller.respondSensitivePrompt(chat, '', expectedRequest: request);

    expect(host.calls.last.$3, {
      'request_id': 'secret-cancel',
      'value': '',
      'profile': 'a',
    });
  });

  test(
    'routes the three vault response contracts and normalizes codes',
    () async {
      final login = jsonEncode({
        'identifier': 'person@example.test',
        'password': 'synthetic-password',
      });
      final cases = [
        (
          event: 'vault.unlock.request',
          data: <String, dynamic>{
            'request_id': 'unlock-1',
            'backend': 'onepassword',
            'display_name': '1Password',
          },
          method: 'vault.unlock.respond',
          field: 'password',
          input: 'synthetic-password',
          output: 'synthetic-password',
        ),
        (
          event: 'vault.code.request',
          data: <String, dynamic>{
            'request_id': 'code-1',
            'site': 'Example',
            'hint': 'Authenticator code',
          },
          method: 'vault.code.respond',
          field: 'code',
          input: '123 456-78',
          output: '12345678',
        ),
        (
          event: 'vault.save_login.request',
          data: <String, dynamic>{
            'request_id': 'save-1',
            'origin': 'https://example.test',
            'site': 'Example',
          },
          method: 'vault.save_login.respond',
          field: 'login',
          input: login,
          output: login,
        ),
      ];

      for (final value in cases) {
        host.event('a', value.event, value.data);
        final request = chat.sensitivePrompt!;

        await controller.respondSensitivePrompt(
          chat,
          value.input,
          expectedRequest: request,
        );

        expect(host.calls.last.$2, value.method);
        expect(host.calls.last.$3, {
          'request_id': value.data['request_id'],
          value.field: value.output,
          'profile': 'a',
        });
      }

      expect(chat.messages.toString(), isNot(contains('synthetic-password')));
      expect(
        [
          for (final key in preferences.getKeys()) preferences.get(key),
        ].toString(),
        isNot(contains('synthetic-password')),
      );
    },
  );

  test('vault cancel values are explicit empty strings', () async {
    const cases = [
      (
        event: 'vault.unlock.request',
        method: 'vault.unlock.respond',
        field: 'password',
      ),
      (
        event: 'vault.code.request',
        method: 'vault.code.respond',
        field: 'code',
      ),
      (
        event: 'vault.save_login.request',
        method: 'vault.save_login.respond',
        field: 'login',
      ),
    ];

    for (final value in cases) {
      host.event('a', value.event, {'request_id': value.event});
      final request = chat.sensitivePrompt!;
      await controller.respondSensitivePrompt(
        chat,
        '',
        expectedRequest: request,
      );

      expect(host.calls.last.$2, value.method);
      expect(host.calls.last.$3[value.field], '');
    }
  });

  test('vault expiry clears only its matching request ID and kind', () {
    host.event('a', 'vault.code.request', {
      'request_id': 'current-code',
      'site': 'Example',
    });

    host.event('a', 'vault.code.expire', {'request_id': 'older-code'});
    expect(chat.sensitivePrompt?.requestId, 'current-code');

    host.event('a', 'vault.unlock.expire', {'request_id': 'current-code'});
    expect(chat.sensitivePrompt?.requestId, 'current-code');

    host.event('a', 'vault.code.expire', {'request_id': 'current-code'});
    expect(chat.sensitivePrompt, isNull);
    expect(chat.sensitivePromptResponding, isFalse);
  });

  test('an older response cannot clear a newer pending request', () async {
    host.responseDelay = Completer<void>();
    host.event('a', 'sudo.request', {'request_id': 'old'});
    final old = chat.sensitivePrompt!;
    final response = controller.respondSensitivePrompt(
      chat,
      'synthetic-password',
      expectedRequest: old,
    );
    await Future<void>.delayed(Duration.zero);

    host.event('a', 'secret.request', {
      'request_id': 'new',
      'env_var': 'NEW_TOKEN',
    });
    host.responseDelay!.complete();
    await response;

    expect(chat.sensitivePrompt?.requestId, 'new');
    expect(chat.sensitivePromptResponding, isFalse);
  });

  test('disconnect retains metadata but disables response state', () {
    host.event('a', 'sudo.request', {'request_id': 'waiting'});

    host.gateways['a']!.onConnectionChanged!(false);

    expect(chat.sensitivePrompt?.requestId, 'waiting');
    expect(chat.sensitivePromptResponding, isFalse);
    expect(chat.status, ProfileTurnStatus.reconnecting);
  });

  test('resume authoritatively clears a request with explicit null', () async {
    host.event('a', 'sudo.request', {'request_id': 'same-runtime'});

    await controller.reconnect(chat.key.workspace);
    expect(chat.sensitivePrompt, isNull);
  });

  test(
    'same-runtime resume preserves a request when the field is absent',
    () async {
      host.includePendingSensitive = false;
      host.event('a', 'sudo.request', {'request_id': 'same-runtime'});

      await controller.reconnect(chat.key.workspace);

      expect(chat.sensitivePrompt?.requestId, 'same-runtime');
      expect(chat.status, ProfileTurnStatus.attention);
    },
  );

  test(
    'changed-runtime resume clears a request when the field is absent',
    () async {
      host.includePendingSensitive = false;
      host.resumedRuntime = 'replacement-runtime';
      host.event('a', 'sudo.request', {'request_id': 'old-runtime'});

      await controller.reconnect(chat.key.workspace);

      expect(chat.sensitivePrompt, isNull);
      expect(chat.sensitivePromptResponding, isFalse);
    },
  );

  test(
    'resume restores a valid request and clears it on replacement',
    () async {
      host.pendingSensitive = {
        'type': 'secret.request',
        'payload': {
          'request_id': 'recovered-secret',
          'env_var': 'FIXTURE_TOKEN',
          'prompt': 'Enter the fixture token',
        },
      };
      await controller.reconnect(chat.key.workspace);
      expect(chat.sensitivePrompt?.requestId, 'recovered-secret');
      expect(chat.sensitivePrompt?.title, 'FIXTURE_TOKEN');
      expect(chat.status, ProfileTurnStatus.attention);

      host.pendingSensitive = null;
      host.resumedRuntime = 'replacement-runtime';
      await controller.reconnect(chat.key.workspace);
      expect(chat.sensitivePrompt, isNull);
    },
  );

  test('session info replaces and clears the authoritative request', () {
    host.event('a', 'session.info', {
      'pending_sensitive': {
        'type': 'vault.code.request',
        'payload': {'request_id': 'code-1', 'site': 'Example'},
      },
    });
    expect(chat.sensitivePrompt?.requestId, 'code-1');
    expect(chat.status, ProfileTurnStatus.attention);

    chat.sensitivePromptResponding = true;
    host.event('a', 'session.info', {
      'pending_sensitive': {
        'type': 'vault.code.request',
        'payload': {'request_id': 'code-1', 'site': 'Updated Example'},
      },
    });
    expect(chat.sensitivePromptResponding, isTrue);

    host.event('a', 'session.info', {
      'pending_sensitive': null,
      'running': false,
    });
    expect(chat.sensitivePrompt, isNull);
    expect(chat.sensitivePromptResponding, isFalse);
    expect(chat.status, ProfileTurnStatus.completed);
  });

  test('partial session info leaves a live request untouched', () {
    host.event('a', 'secret.request', {
      'request_id': 'live-secret',
      'env_var': 'FIXTURE_TOKEN',
    });

    host.event('a', 'session.info', {'model': 'fixture-model'});

    expect(chat.sensitivePrompt?.requestId, 'live-secret');
    expect(chat.status, ProfileTurnStatus.attention);
  });

  test('session info keeps running after clearing resolved input', () {
    host.event('a', 'sudo.request', {'request_id': 'resolved'});

    host.event('a', 'session.info', {
      'pending_sensitive': null,
      'running': true,
    });

    expect(chat.sensitivePrompt, isNull);
    expect(chat.status, ProfileTurnStatus.running);
  });

  test('malformed session info clears stale metadata without persistence', () {
    host.event('a', 'secret.request', {
      'request_id': 'stale',
      'env_var': 'FIXTURE_TOKEN',
    });
    host.event('a', 'session.info', {
      'pending_sensitive': {
        'type': 'secret.request',
        'payload': {
          'request_id': 'bad',
          'value': 'synthetic-secret-must-not-persist',
        },
      },
    });

    expect(chat.sensitivePrompt, isNull);
    expect(
      [
        for (final key in preferences.getKeys()) preferences.get(key),
      ].toString(),
      isNot(contains('synthetic-secret-must-not-persist')),
    );
  });

  test('the official missing-pending error expires the request', () async {
    host.responseError = JsonRpcError(
      'secret.respond',
      'no pending value request',
    );
    host.event('a', 'secret.request', {
      'request_id': 'expired',
      'env_var': 'FIXTURE_TOKEN',
    });
    final request = chat.sensitivePrompt!;

    await controller.respondSensitivePrompt(
      chat,
      'synthetic-secret',
      expectedRequest: request,
    );

    expect(chat.sensitivePrompt, isNull);
    expect(chat.sensitivePromptResponding, isFalse);
  });

  test(
    'a transport failure retains metadata without storing its error',
    () async {
      host.responseError = StateError('server echoed synthetic-secret');
      host.event('a', 'secret.request', {
        'request_id': 'retry',
        'env_var': 'FIXTURE_TOKEN',
      });
      final request = chat.sensitivePrompt!;

      await expectLater(
        controller.respondSensitivePrompt(
          chat,
          'synthetic-secret',
          expectedRequest: request,
        ),
        throwsStateError,
      );

      expect(chat.sensitivePrompt, same(request));
      expect(chat.sensitivePromptResponding, isFalse);
      expect(chat.error, isNull);
      expect(chat.messages.toString(), isNot(contains('synthetic-secret')));
    },
  );
}
