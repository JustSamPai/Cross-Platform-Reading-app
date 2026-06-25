import 'package:flutter/material.dart';

import '../../../core/utils/date_keys.dart';

class HabitHeatMap extends StatelessWidget {
  const HabitHeatMap({
    required this.dataset,
    required this.startDate,
    super.key,
  });

  final Map<DateTime, int> dataset;
  final DateTime startDate;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final firstVisibleDay =
        startDate.isAfter(today.subtract(const Duration(days: 34)))
            ? startDate
            : today.subtract(const Duration(days: 34));
    final days = daysBetween(firstVisibleDay, today).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final day in days)
                  _HeatMapDay(day: day, value: dataset[day] ?? 0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatMapDay extends StatelessWidget {
  const _HeatMapDay({
    required this.day,
    required this.value,
  });

  final DateTime day;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alpha = value == 0 ? 0.08 : (0.18 + (value / 10) * 0.72).clamp(0, 1);
    final color = colorScheme.primary.withValues(alpha: alpha.toDouble());

    return Tooltip(
      message: '${convertDateTimeToString(day)}: $value/10',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Text(
              '${day.day}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ),
    );
  }
}
