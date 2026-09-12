enum GatewaySensitivePromptKind {
  sudo,
  secret,
  vaultUnlock,
  vaultSaveLogin,
  vaultCode,
}

/// A request-ID keyed sensitive prompt emitted by Hermes.
///
/// Values entered by the user are intentionally not part of this model so they
/// cannot be retained alongside chat or connection state.
class GatewaySensitivePromptRequest {
  final GatewaySensitivePromptKind kind;
  final String requestId;
  final String title;
  final String description;
  final String fieldLabel;

  const GatewaySensitivePromptRequest({
    required this.kind,
    required this.requestId,
    required this.title,
    required this.description,
    required this.fieldLabel,
  });

  /// Parses the authoritative `pending_sensitive` session snapshot.
  /// Invalid snapshots are treated as no pending request.
  static GatewaySensitivePromptRequest? fromPendingSnapshot(Object? value) {
    if (value is! Map) return null;
    if (value.keys.any((key) => key is! String)) return null;
    final envelope = Map<String, dynamic>.from(value);
    if (envelope.keys.any((key) => key != 'type' && key != 'payload')) {
      return null;
    }
    final type = envelope['type'];
    final rawPayload = envelope['payload'];
    if (type is! String || rawPayload is! Map) return null;
    if (rawPayload.keys.any((key) => key is! String)) return null;
    final payload = Map<String, dynamic>.from(rawPayload);
    final kind = switch (type) {
      'sudo.request' => GatewaySensitivePromptKind.sudo,
      'secret.request' => GatewaySensitivePromptKind.secret,
      'vault.unlock.request' => GatewaySensitivePromptKind.vaultUnlock,
      'vault.save_login.request' => GatewaySensitivePromptKind.vaultSaveLogin,
      'vault.code.request' => GatewaySensitivePromptKind.vaultCode,
      _ => null,
    };
    if (kind == null) return null;
    final optional = switch (kind) {
      GatewaySensitivePromptKind.sudo => const <String>{},
      GatewaySensitivePromptKind.secret => const {'prompt', 'env_var'},
      GatewaySensitivePromptKind.vaultUnlock => const {
        'backend',
        'display_name',
      },
      GatewaySensitivePromptKind.vaultSaveLogin => const {'origin', 'site'},
      GatewaySensitivePromptKind.vaultCode => const {'site', 'hint'},
    };
    if (payload.keys.any(
      (key) => key != 'request_id' && !optional.contains(key),
    )) {
      return null;
    }
    final requestId = payload['request_id'];
    if (requestId is! String || requestId.trim().isEmpty) return null;
    for (final key in optional) {
      if (payload.containsKey(key) && !_validSnapshotString(payload[key])) {
        return null;
      }
    }
    return fromEventData(kind: kind, data: payload);
  }

  static bool _validSnapshotString(Object? value) {
    if (value is! String) return false;
    return value.isNotEmpty && value.length <= 512 && value.trim() == value;
  }

  static GatewaySensitivePromptRequest? fromEventData({
    required GatewaySensitivePromptKind kind,
    required Map<String, dynamic> data,
  }) {
    final requestId = data['request_id']?.toString().trim() ?? '';
    if (requestId.isEmpty) return null;

    String metadata(String key) => data[key]?.toString().trim() ?? '';
    switch (kind) {
      case GatewaySensitivePromptKind.sudo:
        return GatewaySensitivePromptRequest(
          kind: kind,
          requestId: requestId,
          title: 'Administrator password needed',
          description:
              'Hermes needs a sudo password for the pending terminal command.',
          fieldLabel: 'Sudo password',
        );
      case GatewaySensitivePromptKind.secret:
        final envVar = metadata('env_var');
        final prompt = metadata('prompt');
        return GatewaySensitivePromptRequest(
          kind: kind,
          requestId: requestId,
          title: envVar.isEmpty ? 'Secret needed' : envVar,
          description: prompt.isEmpty
              ? 'Hermes needs a secret for the pending skill.'
              : prompt,
          fieldLabel: envVar.isEmpty ? 'Secret value' : envVar,
        );
      case GatewaySensitivePromptKind.vaultUnlock:
        final backend = metadata('backend');
        final displayName = metadata('display_name');
        final unlockOwner = displayName.isNotEmpty
            ? displayName
            : backend.isNotEmpty
            ? backend
            : 'password manager';
        return GatewaySensitivePromptRequest(
          kind: kind,
          requestId: requestId,
          title: 'Unlock $unlockOwner',
          description: 'Enter the master password for $unlockOwner.',
          fieldLabel: 'Master password',
        );
      case GatewaySensitivePromptKind.vaultSaveLogin:
        final origin = metadata('origin');
        final siteMetadata = metadata('site');
        final saveSite = siteMetadata.isNotEmpty ? siteMetadata : origin;
        final saveTarget = saveSite.isEmpty ? 'this site' : saveSite;
        return GatewaySensitivePromptRequest(
          kind: kind,
          requestId: requestId,
          title: 'Save login for $saveTarget',
          description: origin.isEmpty
              ? 'Save this login in the encrypted vault.'
              : 'Save a login for $origin in the encrypted vault.',
          fieldLabel: 'Identifier',
        );
      case GatewaySensitivePromptKind.vaultCode:
        final codeSite = metadata('site');
        final hint = metadata('hint');
        final codeTarget = codeSite.isEmpty ? 'this site' : codeSite;
        return GatewaySensitivePromptRequest(
          kind: kind,
          requestId: requestId,
          title: 'Enter code for $codeTarget',
          description: hint.isEmpty
              ? 'Enter the one-time code for $codeTarget.'
              : hint,
          fieldLabel: 'One-time code',
        );
    }
  }
}
