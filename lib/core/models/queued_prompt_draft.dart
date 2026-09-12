import 'attachment_draft.dart';

class QueuedPromptDraft {
  final String text;
  final List<AttachmentDraft> attachments;

  QueuedPromptDraft({
    required this.text,
    Iterable<AttachmentDraft> attachments = const [],
  }) : attachments = List.unmodifiable(attachments);
}
