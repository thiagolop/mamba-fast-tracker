import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../../core/time/date_key.dart';

class Meal extends Equatable {
  const Meal({
    required this.id,
    required this.userId,
    required this.name,
    required this.calories,
    required this.createdAt,
    required this.dateKey,
  });

  final String id;
  final String userId;
  final String name;
  final int calories;
  final DateTime createdAt;
  final String dateKey;

  Meal copyWith({
    String? id,
    String? userId,
    String? name,
    int? calories,
    DateTime? createdAt,
    String? dateKey,
  }) {
    return Meal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      createdAt: createdAt ?? this.createdAt,
      dateKey: dateKey ?? this.dateKey,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    calories,
    createdAt,
    dateKey,
  ];

  static Meal create({
    required String id,
    required String userId,
    required String name,
    required int calories,
    required DateTime createdAt,
  }) {
    return Meal(
      id: id,
      userId: userId,
      name: name,
      calories: calories,
      createdAt: createdAt,
      dateKey: dateKeyFromDate(createdAt),
    );
  }
}

class MealAdapter extends TypeAdapter<Meal> {
  static const int typeKey = 3;

  @override
  int get typeId => typeKey;

  @override
  Meal read(BinaryReader reader) {
    final id = reader.readString();
    final userIdOrName = reader.readString();
    final caloriesOrName = reader.read();

    if (caloriesOrName is int) {
      final calories = caloriesOrName;
      final createdAtMillis = reader.readInt();
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        createdAtMillis,
      );
      final dateKey = dateKeyFromDate(createdAt);

      return Meal(
        id: id,
        userId: '',
        name: userIdOrName,
        calories: calories,
        createdAt: createdAt,
        dateKey: dateKey,
      );
    }

    if (caloriesOrName is String) {
      final userId = userIdOrName;
      final name = caloriesOrName;
      final calories = reader.readInt();
      final createdAtMillis = reader.readInt();
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        createdAtMillis,
      );
      String? dateKey;
      try {
        dateKey = reader.readString();
      } catch (_) {
        dateKey = dateKeyFromDate(createdAt);
      }

      return Meal(
        id: id,
        userId: userId,
        name: name,
        calories: calories,
        createdAt: createdAt,
        dateKey: dateKey,
      );
    }

    return Meal(
      id: id,
      userId: '',
      name: userIdOrName,
      calories: 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      dateKey: '1970-01-01',
    );
  }

  @override
  void write(BinaryWriter writer, Meal obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.userId)
      ..writeString(obj.name)
      ..writeInt(obj.calories)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeString(obj.dateKey);
  }
}
