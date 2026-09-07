import 'dart:convert';

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

/// Each version has its own server session, including any later conversation.
/// Only links are stored on the phone; transcripts remain on the Hermes host.
class AnswerVersionGroup {
  final int userOrdinal;
  final List<String> sessions;
  final Map<String, int> selections;
  final Map<String, int> answerIds;
  AnswerVersionGroup(
    this.userOrdinal,
    this.sessions,
    this.selections, [
    Map<String, int>? answerIds,
  ]) : answerIds = answerIds ?? {};

  Map<String, dynamic> toJson() => {
    'turn': userOrdinal,
    'sessions': sessions,
    'selections': selections,
    'answer_ids': answerIds,
  };

  static List<AnswerVersionGroup> decode(String? raw) {
    if (raw == null) return [];
    final values = jsonDecode(raw) as List;
    return values.map((value) {
      final sessions = (value['sessions'] as List).cast<String>();
      final selections = Map<String, int>.from(value['selections'] as Map);
      final ordinal = value['turn'] as int;
      if (ordinal < 0 ||
          sessions.isEmpty ||
          sessions.any((id) => id.isEmpty) ||
          selections.values.any(
            (index) => index < 0 || index >= sessions.length,
          )) {
        throw const FormatException('Invalid answer version links');
      }
      return AnswerVersionGroup(
        ordinal,
        sessions,
        selections,
        Map<String, int>.from(value['answer_ids'] as Map? ?? {}),
      );
    }).toList();
  }
}
