import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.completedCount,
    required this.pendingCount,
  });

  final int completedCount;
  final int pendingCount;

  /// Visualizes completed versus pending tasks in a compact progress ring.
  @override
  Widget build(BuildContext context) {
    final int total = completedCount + pendingCount;
    final double percent = total == 0 ? 0 : completedCount / total;

    return CircularPercentIndicator(
      radius: 68,
      lineWidth: 14,
      percent: percent.clamp(0, 1),
      animation: true,
      circularStrokeCap: CircularStrokeCap.round,
      progressColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.12),
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${(percent * 100).round()}%',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text('Done', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
