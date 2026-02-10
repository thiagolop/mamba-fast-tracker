import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive_ce.dart';

class MealEntry extends Equatable {
  const MealEntry({
    required this.id,
    required this.title,
    required this.calories,
    required this.consumedAt,
  });

  final String id;
  final String title;
  final int calories;
  final DateTime consumedAt;

  MealEntry copyWith({
    String? id,
    String? title,
    int? calories,
    DateTime? consumedAt,
  }) {
    return MealEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      calories: calories ?? this.calories,
      consumedAt: consumedAt ?? this.consumedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, calories, consumedAt];
}

class MealEntryAdapter extends TypeAdapter<MealEntry> {
  static const int typeKey = 3;

  @override
  int get typeId => typeKey;

  @override
  MealEntry read(BinaryReader reader) {
    final id = reader.readString();
    final title = reader.readString();
    final calories = reader.readInt();
    final consumedAtMillis = reader.readInt();

    return MealEntry(
      id: id,
      title: title,
      calories: calories,
      consumedAt: DateTime.fromMillisecondsSinceEpoch(consumedAtMillis),
    );
  }

  @override
  void write(BinaryWriter writer, MealEntry obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.title)
      ..writeInt(obj.calories)
      ..writeInt(obj.consumedAt.millisecondsSinceEpoch);
  }
}
