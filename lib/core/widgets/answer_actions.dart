import 'package:flutter/material.dart';

class AnswerActions extends StatelessWidget {
  final VoidCallback? onBranch;
  final VoidCallback? onRegenerate;
  final VoidCallback? onPreviousVersion;
  final VoidCallback? onNextVersion;
  final int? currentVersion;
  final int? versionCount;
  final bool busy;

  const AnswerActions({
    super.key,
    this.onBranch,
    this.onRegenerate,
    this.onPreviousVersion,
    this.onNextVersion,
    this.currentVersion,
    this.versionCount,
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
      if (currentVersion != null &&
          versionCount != null &&
          versionCount! >= 2) ...[
        IconButton(
          tooltip: 'Previous answer',
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          onPressed: onPreviousVersion,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('${currentVersion! + 1} / $versionCount'),
        IconButton(
          tooltip: 'Next answer',
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          onPressed: onNextVersion,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
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
