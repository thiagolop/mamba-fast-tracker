import '../../../core/time/date_key.dart';
import 'meal.dart';

class CaloriesAggregator {
  static int totalForDay(List<Meal> meals, DateTime date) {
    final key = dateKeyFromDate(date);
    return meals
        .where((meal) => meal.dateKey == key)
        .fold<int>(0, (total, meal) => total + meal.calories);
  }

  static Map<String, int> totalsByDateKey(List<Meal> meals) {
    final totals = <String, int>{};
    for (final meal in meals) {
      totals.update(
        meal.dateKey,
        (value) => value + meal.calories,
        ifAbsent: () => meal.calories,
      );
    }
    return totals;
  }
}
