enum SideQuestionDeliveryState { pending, completed }

enum SideQuestionDeliveryKind { sideQuestion, backgroundTask }

class SideQuestionDelivery {
  final SideQuestionDeliveryKind kind;
  final String? taskId;
  final String question;
  final SideQuestionDeliveryState state;
  final String result;

  const SideQuestionDelivery({
    this.kind = SideQuestionDeliveryKind.sideQuestion,
    required this.taskId,
    required this.question,
    required this.state,
    this.result = '',
  });

  SideQuestionDelivery complete({required String result, String? question}) =>
      SideQuestionDelivery(
        kind: kind,
        taskId: taskId,
        question: question?.isNotEmpty == true ? question! : this.question,
        state: SideQuestionDeliveryState.completed,
        result: result,
      );
}
