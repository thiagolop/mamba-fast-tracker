import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/time/date_key.dart';
import '../../../core/storage/hive_boxes.dart';
import '../domain/meal.dart';

class MealsRepository {
  MealsRepository({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<List<Meal>> listMealsForUser(String userId) async {
    final items = HiveBoxes.meals.values
        .where((meal) => meal.userId == userId)
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<Meal>> listMealsForDay(String userId, String dateKey) async {
    final items = HiveBoxes.meals.values
        .where(
          (meal) => meal.userId == userId && meal.dateKey == dateKey,
        )
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<Meal> addMeal({
    required String userId,
    required String name,
    required int calories,
    required DateTime createdAt,
  }) async {
    final entry = Meal.create(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      calories: calories,
      createdAt: createdAt,
    );
    await HiveBoxes.meals.put(_key(userId, entry.id), entry);
    return entry;
  }

  Future<Meal?> getMeal(String userId, String mealId) async {
    var value = HiveBoxes.meals.get(_key(userId, mealId));
    value ??= HiveBoxes.meals.get(mealId);
    if (value == null) {
      for (final meal in HiveBoxes.meals.values) {
        if (meal.id == mealId) {
          value = meal;
          break;
        }
      }
    }
    if (value == null) return null;
    if (value.userId.isEmpty) {
      return value.copyWith(userId: userId);
    }
    return value;
  }

  Future<Meal> updateMeal({
    required String userId,
    required String mealId,
    required String name,
    required int calories,
  }) async {
    final current = await getMeal(userId, mealId);
    if (current == null) {
      throw StateError('Meal not found');
    }

    final updated = current.copyWith(
      userId: userId,
      name: name,
      calories: calories,
      dateKey: dateKeyFromDate(current.createdAt),
    );
    await HiveBoxes.meals.put(_key(userId, updated.id), updated);
    return updated;
  }

  Future<void> deleteMeal(String userId, String mealId) async {
    await HiveBoxes.meals.delete(_key(userId, mealId));
    await HiveBoxes.meals.delete(mealId);
  }

  static String _key(String userId, String mealId) => '$userId:$mealId';
}

final mealsRepositoryProvider = Provider<MealsRepository>((ref) {
  return MealsRepository();
});

final mealsChangesProvider = StreamProvider<int>((ref) async* {
  yield DateTime.now().millisecondsSinceEpoch;
  await for (final _ in HiveBoxes.meals.watch()) {
    yield DateTime.now().millisecondsSinceEpoch;
  }
});
