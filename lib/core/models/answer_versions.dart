/// Text projection for gateway display messages and stored multimodal content.
String answerMessageText(Map<String, dynamic> message) {
  final value = message['content'] ?? message['text'];
  if (value is List) {
    return value.map((part) {
      if (part is String) return part;
      if (part is! Map) return '';
      if (part['text'] is String) return part['text'] as String;
      if (part['type'] == null) return '';
      final text = _structuredText(part);
      return {'text', 'input_text', 'output_text'}.contains(part['type'])
          ? text
          : '\n$text';
    }).join();
  }
  return value is Map ? _structuredText(value) : value?.toString() ?? '';
}

String _structuredText(Map part) {
  final kind = part['type'];
  if ({'text', 'input_text', 'output_text'}.contains(kind)) {
    return (part['text'] ?? part['content'] ?? '').toString();
  }
  if ({'image_url', 'input_image', 'image'}.contains(kind)) {
    final image = part['image_url'];
    final url = image is Map ? image['url'] : image;
    return url is String && url.isNotEmpty ? url : '[image]';
  }
  if ({'audio', 'input_audio'}.contains(kind)) return '[audio]';
  if (kind != null && kind != '') return '[$kind]';
  if (part.containsKey('text')) return part['text']?.toString() ?? '';
  return '[structured content]';
}

bool isBranchMessage(Map<String, dynamic> message) =>
    {'user', 'assistant'}.contains(message['role']) &&
    answerMessageText(message).trim().isNotEmpty;

bool isHiddenAnswerMessage(Map<String, dynamic> message) =>
    message['display_kind'] == 'hidden' ||
    (message['role'] == 'user' &&
        answerMessageText(message).trimLeft().startsWith('[System:'));

bool isAnswerPrompt(Map<String, dynamic> message) =>
    message['role'] == 'user' &&
    message['display_kind'] == null &&
    isBranchMessage(message);

int? answerMessageId(Map<String, dynamic> message) =>
    (message['row_id'] ?? message['id']) as int?;

List<Map<String, dynamic>> answerHistoryRows(
  List<Map<String, dynamic>> messages,
) => messages
    .map(
      (m) => {...m, 'id': answerMessageId(m), 'content': answerMessageText(m)},
    )
    .toList();

class AnswerTarget {
  final int messageIndex;
  final int userOrdinal;
  final String prompt;
  const AnswerTarget(this.messageIndex, this.userOrdinal, this.prompt);

  static AnswerTarget? at(List<Map<String, dynamic>> messages, int index) {
    if (index < 0 ||
        index >= messages.length ||
        messages[index]['role'] != 'assistant' ||
        !isBranchMessage(messages[index])) {
      return null;
    }
    var ordinal = -1;
    var prompt = '';
    for (final message in messages.take(index + 1)) {
      if (isAnswerPrompt(message)) {
        ordinal++;
        prompt = answerMessageText(message);
      }
    }
    return AnswerTarget(index, ordinal, prompt);
  }
}

class AnswerVersionRef {
  final String sessionId;
  final int answerRowId;
  final int position;

  const AnswerVersionRef({
    required this.sessionId,
    required this.answerRowId,
    required this.position,
  });

  factory AnswerVersionRef.fromJson(Map<String, dynamic> value) {
    final sessionId = value['session_id'];
    final answerRowId = value['answer_row_id'];
    final position = value['position'];
    if (sessionId is! String ||
        sessionId.isEmpty ||
        answerRowId is! int ||
        answerRowId <= 0 ||
        position is! int ||
        position < 0) {
      throw const FormatException('Invalid answer version');
    }
    return AnswerVersionRef(
      sessionId: sessionId,
      answerRowId: answerRowId,
      position: position,
    );
  }
}

class AnswerVersionSource {
  final String sessionId;
  final int answerRowId;

  const AnswerVersionSource({
    required this.sessionId,
    required this.answerRowId,
  });

  factory AnswerVersionSource.fromJson(Map<String, dynamic> value) {
    final sessionId = value['session_id'];
    final answerRowId = value['answer_row_id'];
    if (sessionId is! String ||
        sessionId.isEmpty ||
        answerRowId is! int ||
        answerRowId <= 0) {
      throw const FormatException('Invalid answer version source');
    }
    return AnswerVersionSource(sessionId: sessionId, answerRowId: answerRowId);
  }
}

class AnswerVersions {
  final AnswerVersionSource? source;
  final List<AnswerVersionRef> versions;

  const AnswerVersions({required this.source, required this.versions});

  factory AnswerVersions.fromJson(Map<String, dynamic> value) {
    final rawSource = value['source'];
    final rawVersions = value['versions'];
    if (rawSource != null && rawSource is! Map || rawVersions is! List) {
      throw const FormatException('Invalid answer versions response');
    }
    final versions = rawVersions
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid answer version');
          }
          return AnswerVersionRef.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
    if (versions.isEmpty ||
        versions.map((item) => item.position).toSet().length !=
            versions.length) {
      throw const FormatException('Invalid answer versions response');
    }
    return AnswerVersions(
      source: rawSource == null
          ? null
          : AnswerVersionSource.fromJson(Map<String, dynamic>.from(rawSource)),
      versions: versions,
    );
  }

  int indexOf(String sessionId, int answerRowId) => versions.indexWhere(
    (item) => item.sessionId == sessionId && item.answerRowId == answerRowId,
  );
}
