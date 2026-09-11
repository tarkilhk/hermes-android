import 'package:flutter/material.dart';

import '../models/context_occupancy.dart';

/// A compact, non-animated context occupancy indicator.
class ContextFuse extends StatelessWidget {
  final ContextOccupancy? occupancy;

  const ContextFuse({super.key, this.occupancy});

  @override
  Widget build(BuildContext context) {
    final value = occupancy;
    final label = value == null
        ? 'Context usage unknown'
        : '${value.estimated ? 'Approximately ' : ''}${value.used} of ${value.max} tokens, ${value.percent.round()} percent used';
    final color = value == null
        ? Theme.of(context).colorScheme.outlineVariant
        : value.percent >= 85
        ? Theme.of(context).colorScheme.error
        : value.percent >= 65
        ? Colors.amber.shade700
        : Colors.green.shade700;

    return Semantics(
      container: true,
      label: label,
      child: Tooltip(
        message: label,
        child: SizedBox(
          height: 8,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double progress = value == null
                  ? 0.0
                  : (value.percent.clamp(0, 100) / 100).toDouble();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 4,
                        width: double.infinity,
                        child: value == null
                            ? ColoredBox(color: color)
                            : LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: color.withValues(alpha: .16),
                                color: color,
                              ),
                      ),
                    ),
                  ),
                  if (value != null)
                    Positioned(
                      left: (constraints.maxWidth * progress - 4).clamp(
                        0,
                        constraints.maxWidth - 8,
                      ),
                      top: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1,
                          ),
                        ),
                        child: const SizedBox(
                          key: ValueKey('context-fuse-dot'),
                          width: 8,
                          height: 8,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
