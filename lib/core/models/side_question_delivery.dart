enum SideQuestionDeliveryState { pending, completed }

class SideQuestionDelivery {
  final String? taskId;
  final String question;
  final SideQuestionDeliveryState state;
  final String result;

  const SideQuestionDelivery({
    required this.taskId,
    required this.question,
    required this.state,
    this.result = '',
  });

  SideQuestionDelivery complete({required String result, String? question}) =>
      SideQuestionDelivery(
        taskId: taskId,
        question: question?.isNotEmpty == true ? question! : this.question,
        state: SideQuestionDeliveryState.completed,
        result: result,
      );
}
