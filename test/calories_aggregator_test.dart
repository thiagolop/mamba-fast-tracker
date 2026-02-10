import 'package:flutter_test/flutter_test.dart';

import 'package:desafio_maba/features/meals/domain/calories_aggregator.dart';
import 'package:desafio_maba/features/meals/domain/meal.dart';

void main() {
  test('CaloriesAggregator totals calories for a given day', () {
    final meals = [
      Meal.create(
        id: '1',
        userId: 'u1',
        name: 'Meal 1',
        calories: 350,
        createdAt: DateTime(2025, 1, 2, 9, 0),
      ),
      Meal.create(
        id: '2',
        userId: 'u1',
        name: 'Meal 2',
        calories: 450,
        createdAt: DateTime(2025, 1, 2, 13, 0),
      ),
      Meal.create(
        id: '3',
        userId: 'u1',
        name: 'Other day',
        calories: 200,
        createdAt: DateTime(2025, 1, 1, 20, 0),
      ),
    ];

    final total = CaloriesAggregator.totalForDay(
      meals,
      DateTime(2025, 1, 2),
    );

    expect(total, 800);
  });
}
