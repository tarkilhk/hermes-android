import 'package:flutter/material.dart';

import '../models/gateway_insight.dart';

class ProfileReviewNoticeCard extends StatelessWidget {
  final GatewayNotice notice;

  const ProfileReviewNoticeCard({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.tertiaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 18,
                  color: colors.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notice.title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(notice.text),
          ],
        ),
      ),
    );
  }
}
