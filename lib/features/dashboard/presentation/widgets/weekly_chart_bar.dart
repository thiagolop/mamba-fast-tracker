import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/weekly_chart_item.dart';

class WeeklyChartBar {
  const WeeklyChartBar({
    required this.index,
    required this.item,
    required this.color,
  });

  final int index;
  final WeeklyChartItem item;
  final Color color;

  BarChartGroupData toGroupData() {
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: item.value,
          width: 14,
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}
