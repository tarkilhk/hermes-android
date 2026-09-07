import 'dart:convert';

/// The same visible-text projection used by the gateway's session.branch.
String answerMessageText(Map<String, dynamic> message) {
  final value = message['content'] ?? message['text'];
  if (value is String) return value;
  if (value is List) {
    return value.whereType<Map>().map((part) => part['text'] ?? '').join('\n');
  }
  return '';
}

bool isBranchMessage(Map<String, dynamic> message) =>
    {'user', 'assistant'}.contains(message['role']) &&
    answerMessageText(message).trim().isNotEmpty;

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
  final int branchCount;
  final int userOrdinal;
  final String prompt;
  const AnswerTarget(
    this.messageIndex,
    this.branchCount,
    this.userOrdinal,
    this.prompt,
  );

  static AnswerTarget? at(List<Map<String, dynamic>> messages, int index) {
    if (index < 0 ||
        index >= messages.length ||
        messages[index]['role'] != 'assistant' ||
        !isBranchMessage(messages[index])) {
      return null;
    }
    var count = 0;
    var ordinal = -1;
    var prompt = '';
    for (final message in messages.take(index + 1)) {
      if (isBranchMessage(message)) count++;
      if (isAnswerPrompt(message)) {
        ordinal++;
        prompt = answerMessageText(message);
      }
    }
    return AnswerTarget(index, count, ordinal, prompt);
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
