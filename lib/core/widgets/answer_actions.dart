import 'package:flutter/material.dart';

class AnswerActions extends StatelessWidget {
  final VoidCallback? onBranch;
  final VoidCallback? onRegenerate;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int version;
  final int count;
  final bool busy;

  const AnswerActions({
    super.key,
    this.onBranch,
    this.onRegenerate,
    this.onPrevious,
    this.onNext,
    this.version = 1,
    this.count = 1,
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
      if (count > 1) ...[
        IconButton(
          tooltip: 'Previous answer',
          onPressed: version > 1 ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Semantics(
          label: 'Answer $version of $count',
          excludeSemantics: true,
          child: Text('$version / $count'),
        ),
        IconButton(
          tooltip: 'Next answer',
          onPressed: version < count ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ],
  );
}
