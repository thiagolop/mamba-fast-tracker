import '../../../core/time/date_key.dart';
import '../../meals/domain/calories_aggregator.dart';
import '../../meals/domain/meal.dart';
import 'weekly_chart_item.dart';

class WeeklyChartService {
  static List<WeeklyChartItem> buildCaloriesSeries({
    required DateTime now,
    required List<Meal> meals,
  }) {
    final totalsByKey = CaloriesAggregator.totalsByDateKey(meals);
    final points = <WeeklyChartItem>[];
    final today = startOfDay(now);

    for (var i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final key = dateKeyFromDate(date);
      final value = (totalsByKey[key] ?? 0).toDouble();
      points.add(
        WeeklyChartItem(
          date: date,
          label: weekdayLabel(date.weekday),
          value: value,
        ),
      );
    }

    return points;
  }

  static String weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'S';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'Q';
      case DateTime.thursday:
        return 'Q';
      case DateTime.friday:
        return 'S';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'D';
      default:
        return '';
    }
  }
}
