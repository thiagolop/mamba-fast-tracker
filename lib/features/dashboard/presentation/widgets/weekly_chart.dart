import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/weekly_chart_item.dart';
import 'weekly_chart_bar.dart';

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, required this.points});

  final List<WeeklyChartItem> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(height: 160);
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
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
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.grey.shade600),
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
