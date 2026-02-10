import 'package:flutter_test/flutter_test.dart';

import 'package:desafio_maba/features/dashboard/domain/weekly_chart_service.dart';
import 'package:desafio_maba/features/meals/domain/meal.dart';

void main() {
  test('WeeklyChartService builds 7 points including today', () {
    final now = DateTime(2025, 1, 8, 10, 0);
    final meals = [
      Meal.create(
        id: '1',
        userId: 'u1',
        name: 'Today',
        calories: 300,
        createdAt: DateTime(2025, 1, 8, 9, 30),
      ),
      Meal.create(
        id: '2',
        userId: 'u1',
        name: 'Two days ago',
        calories: 500,
        createdAt: DateTime(2025, 1, 6, 12, 0),
      ),
    ];

    final points = WeeklyChartService.buildCaloriesSeries(
      now: now,
      meals: meals,
    );

    expect(points.length, 7);
    expect(points.last.date, DateTime(2025, 1, 8));
    expect(points.last.value, 300);
    expect(points[4].date, DateTime(2025, 1, 6));
    expect(points[4].value, 500);
  });
}
