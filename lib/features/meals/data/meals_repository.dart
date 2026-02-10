import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/hive_boxes.dart';
import '../domain/meal_entry.dart';

class MealsRepository {
  MealsRepository({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  List<MealEntry> getAll() {
    final items = HiveBoxes.meals.values.toList();
    items.sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
    return items;
  }

  Future<MealEntry> addMeal({
    required String title,
    required int calories,
    required DateTime consumedAt,
  }) async {
    final entry = MealEntry(
      id: _uuid.v4(),
      title: title,
      calories: calories,
      consumedAt: consumedAt,
    );
    await HiveBoxes.meals.put(entry.id, entry);
    return entry;
  }

  Future<void> deleteMeal(String id) async {
    await HiveBoxes.meals.delete(id);
  }
}

final mealsRepositoryProvider = Provider<MealsRepository>((ref) {
  return MealsRepository();
});
