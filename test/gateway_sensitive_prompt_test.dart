import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_sensitive_prompt.dart';

void main() {
  group('GatewaySensitivePromptRequest', () {
    test('parses an official sudo request', () {
      final request = GatewaySensitivePromptRequest.fromEventData(
        kind: GatewaySensitivePromptKind.sudo,
        data: {'request_id': 'sudo-123'},
      );

      expect(request, isNotNull);
      expect(request!.requestId, 'sudo-123');
      expect(request.kind, GatewaySensitivePromptKind.sudo);
      expect(request.fieldLabel, 'Sudo password');
    });

    test('parses the secret label and prompt without retaining a value', () {
      final request = GatewaySensitivePromptRequest.fromEventData(
        kind: GatewaySensitivePromptKind.secret,
        data: {
          'request_id': 'secret-123',
          'env_var': 'FIXTURE_API_TOKEN',
          'prompt': 'Enter a synthetic token',
        },
      );

      expect(request, isNotNull);
      expect(request!.title, 'FIXTURE_API_TOKEN');
      expect(request.description, 'Enter a synthetic token');
    });

    test('ignores a request without request_id', () {
      expect(
        GatewaySensitivePromptRequest.fromEventData(
          kind: GatewaySensitivePromptKind.secret,
          data: {'env_var': 'MISSING_ID'},
        ),
        isNull,
      );
    });

    test('parses vault request metadata without response values', () {
      final unlock = GatewaySensitivePromptRequest.fromEventData(
        kind: GatewaySensitivePromptKind.vaultUnlock,
        data: {
          'request_id': 'unlock-1',
          'backend': 'onepassword',
          'display_name': '1Password',
        },
      );
      final save = GatewaySensitivePromptRequest.fromEventData(
        kind: GatewaySensitivePromptKind.vaultSaveLogin,
        data: {
          'request_id': 'save-1',
          'origin': 'https://example.test',
          'site': 'Example',
        },
      );
      final code = GatewaySensitivePromptRequest.fromEventData(
        kind: GatewaySensitivePromptKind.vaultCode,
        data: {
          'request_id': 'code-1',
          'site': 'Example',
          'hint': 'Use your authenticator app.',
        },
      );

      expect(unlock!.title, 'Unlock 1Password');
      expect(unlock.fieldLabel, 'Master password');
      expect(save!.title, 'Save login for Example');
      expect(save.fieldLabel, 'Identifier');
      expect(code!.title, 'Enter code for Example');
      expect(code.description, 'Use your authenticator app.');
    });

    test('parses each authoritative pending-sensitive request family', () {
      const cases = [
        ('sudo.request', 'sudo-1', GatewaySensitivePromptKind.sudo),
        ('secret.request', 'secret-1', GatewaySensitivePromptKind.secret),
        (
          'vault.unlock.request',
          'unlock-1',
          GatewaySensitivePromptKind.vaultUnlock,
        ),
        (
          'vault.save_login.request',
          'save-1',
          GatewaySensitivePromptKind.vaultSaveLogin,
        ),
        ('vault.code.request', 'code-1', GatewaySensitivePromptKind.vaultCode),
      ];
      for (final value in cases) {
        final request = GatewaySensitivePromptRequest.fromPendingSnapshot({
          'type': value.$1,
          'payload': {'request_id': value.$2},
        });
        expect(request?.requestId, value.$2);
        expect(request?.kind, value.$3);
      }
    });

    test('fails closed on malformed pending-sensitive snapshots', () {
      final malformed = <Object?>[
        null,
        const {},
        const {
          'type': 'unknown.request',
          'payload': {'request_id': 'id'},
        },
        const {'type': 'sudo.request', 'payload': 'not-an-object'},
        const {'type': 'sudo.request', 'payload': {}},
        const {
          'type': 'sudo.request',
          'payload': {'request_id': 7},
        },
        const {
          'type': 'secret.request',
          'payload': {'request_id': 'id', 'prompt': 7},
        },
        const {
          'type': 'sudo.request',
          'payload': {'request_id': 'id', 'password': 'must-not-appear'},
        },
      ];
      for (final value in malformed) {
        expect(
          GatewaySensitivePromptRequest.fromPendingSnapshot(value),
          isNull,
        );
      }
    });
  });
}
