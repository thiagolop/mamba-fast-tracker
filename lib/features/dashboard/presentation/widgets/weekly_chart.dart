import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/weekly_chart_item.dart';
import 'weekly_chart_bar.dart';

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({
    super.key,
    required this.points,
    this.valueFormatter,
  });

  final List<WeeklyChartItem> points;
  final String Function(WeeklyChartItem item)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(height: 160);
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final index = group.x.toInt();
                if (index < 0 || index >= points.length) {
                  return null;
                }
                final item = points[index];
                final valueLabel = valueFormatter != null
                    ? valueFormatter!(item)
                    : item.value.toStringAsFixed(0);
                return BarTooltipItem(
                  '${item.label} • $valueLabel',
                  Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      points[index].label,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(points.length, (index) {
            return WeeklyChartBar(
              index: index,
              item: points[index],
              color: Theme.of(context).colorScheme.primary,
            ).toGroupData();
          }),
        ),
      ),
    );
  }
}
