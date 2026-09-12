import 'package:flutter/material.dart';

class AnswerActions extends StatelessWidget {
  final VoidCallback? onBranch;
  final VoidCallback? onRegenerate;
  final bool busy;

  const AnswerActions({
    super.key,
    this.onBranch,
    this.onRegenerate,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (busy)
        const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      IconButton(
        tooltip: 'Branch in new session',
        onPressed: onBranch,
        icon: const Icon(Icons.fork_right),
      ),
      IconButton(
        tooltip: 'Regenerate response',
        onPressed: onRegenerate,
        icon: const Icon(Icons.refresh),
      ),
    ],
  );
}
