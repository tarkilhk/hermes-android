import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/attachment_draft.dart';

class ComposerDraftSnapshot {
  final String text;
  final List<AttachmentDraft> attachments;
  final bool submissionUncertain;

  const ComposerDraftSnapshot({
    required this.text,
    required this.attachments,
    required this.submissionUncertain,
  });
}

/// Stores only work that has not been accepted by Hermes yet.
class ComposerDraftStore {
  final SharedPreferences _preferences;
  final String connectionIdentity;

  ComposerDraftStore(this._preferences, {required this.connectionIdentity}) {
    if (connectionIdentity.isEmpty) {
      throw ArgumentError('A verified connection identity is required');
    }
  }

  String get _key => 'composer_drafts_v1_$connectionIdentity';

  Future<ComposerDraftSnapshot?> read({
    required String profileName,
    required String sessionId,
  }) async {
    final records = _readRecords();
    final record = records.where((value) {
      return value['profile'] == profileName && value['session'] == sessionId;
    }).firstOrNull;
    if (record == null) return null;

    final text = record['text'];
    final rawAttachments = record['attachments'];
    if (text is! String || rawAttachments is! List) return null;
    final attachments = <AttachmentDraft>[];
    for (final value in rawAttachments) {
      try {
        final draft = _decodeAttachment(
          Map<String, dynamic>.from(value as Map),
        );
        final hasReusableReference =
            draft.status == AttachmentDraftStatus.attached &&
            draft.refText?.isNotEmpty == true;
        if (!hasReusableReference && !await File(draft.cachedPath).exists()) {
          draft
            ..status = AttachmentDraftStatus.failed
            ..error =
                'This staged file is no longer available. Remove it and attach it again.';
        } else if (draft.status == AttachmentDraftStatus.uploading) {
          draft.status = AttachmentDraftStatus.ready;
        }
        attachments.add(draft);
      } catch (_) {
        // One damaged attachment record must not discard the user's text.
      }
    }
    return ComposerDraftSnapshot(
      text: text,
      attachments: attachments,
      submissionUncertain: record['submission_uncertain'] == true,
    );
  }

  Future<void> write({
    required String profileName,
    required String sessionId,
    required String text,
    required Iterable<AttachmentDraft> attachments,
    bool submissionUncertain = false,
  }) async {
    final records = _readRecords()
      ..removeWhere(
        (value) =>
            value['profile'] == profileName && value['session'] == sessionId,
      );
    final files = attachments.toList(growable: false);
    if (text.isNotEmpty || files.isNotEmpty) {
      records.add({
        'profile': profileName,
        'session': sessionId,
        'text': text,
        'submission_uncertain': submissionUncertain,
        'attachments': files.map(_encodeAttachment).toList(),
      });
    }
    if (records.isEmpty) {
      await _preferences.remove(_key);
    } else {
      await _preferences.setString(_key, jsonEncode(records));
    }
  }

  List<Map<String, dynamic>> _readRecords() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final value in decoded)
          if (value is Map) Map<String, dynamic>.from(value),
      ];
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _encodeAttachment(AttachmentDraft draft) => {
    'id': draft.id,
    'path': draft.cachedPath,
    'name': draft.name,
    'bytes': draft.byteLength,
    'media_type': draft.mediaType,
    'kind': draft.kind.name,
    'source_image_format': draft.sourceImageFormat?.name,
    'sanitized': draft.sanitized,
    'status': draft.status.name,
    'ref_text': draft.refText,
    'error': draft.error,
    'atlas_intake_accepted': draft.atlasIntakeAccepted,
  };

  AttachmentDraft _decodeAttachment(Map<String, dynamic> value) {
    T enumValue<T extends Enum>(List<T> values, Object? name) =>
        values.singleWhere((candidate) => candidate.name == name);

    final id = value['id'];
    final path = value['path'];
    final name = value['name'];
    final bytes = value['bytes'];
    final mediaType = value['media_type'];
    if (id is! String ||
        id.isEmpty ||
        path is! String ||
        path.isEmpty ||
        name is! String ||
        name.isEmpty ||
        bytes is! int ||
        bytes <= 0 ||
        mediaType is! String ||
        mediaType.isEmpty) {
      throw const FormatException('Invalid attachment draft');
    }
    final sourceFormat = value['source_image_format'];
    return AttachmentDraft(
      id: id,
      cachedPath: path,
      name: name,
      byteLength: bytes,
      mediaType: mediaType,
      kind: enumValue(AttachmentDraftKind.values, value['kind']),
      sourceImageFormat: sourceFormat == null
          ? null
          : enumValue(AttachmentImageFormat.values, sourceFormat),
      sanitized: value['sanitized'] == true,
      status: enumValue(AttachmentDraftStatus.values, value['status']),
      refText: value['ref_text'] as String?,
      error: value['error'] as String?,
      atlasIntakeAccepted: value['atlas_intake_accepted'] as bool?,
    );
  }
}
