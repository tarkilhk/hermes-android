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
          height: 12,
          width: double.infinity,
          child: Align(
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 4,
                width: double.infinity,
                child: value == null
                    ? ColoredBox(color: color)
                    : LinearProgressIndicator(
                        value: value.percent / 100,
                        minHeight: 4,
                        backgroundColor: color.withValues(alpha: .16),
                        color: color,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
