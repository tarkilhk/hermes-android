import 'package:flutter/material.dart';

import '../models/side_question_delivery.dart';

class SideQuestionDeliveryCard extends StatelessWidget {
  final SideQuestionDelivery delivery;

  const SideQuestionDeliveryCard({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final pending = delivery.state == SideQuestionDeliveryState.pending;
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pending ? Icons.schedule : Icons.call_split,
                  size: 18,
                  color: colors.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pending ? 'Side question running' : 'Side question answer',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (delivery.question.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(delivery.question),
            ],
            const SizedBox(height: 8),
            SelectableText(
              pending ? 'Waiting for the Hermes host.' : delivery.result,
            ),
          ],
        ),
      ),
    );
  }
}
