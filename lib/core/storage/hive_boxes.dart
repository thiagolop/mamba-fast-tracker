import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../features/fasting/domain/fasting_protocol.dart';
import '../../features/fasting/domain/fasting_session.dart';
import '../../features/meals/domain/meal.dart';

class HiveBoxes {
  static const String fastingProtocolsBox = 'fasting_protocols';
  static const String fastingSessionsBox = 'fasting_sessions';
  static const String settingsBox = 'settings';
  static const String mealsBox = 'meals';

  static late Box<FastingProtocol> fastingProtocols;
  static late Box<FastingSession> fastingSessions;
  static late Box<String> settings;
  static late Box<Meal> meals;

  static Future<void> init() async {
    await Hive.initFlutter();
    _registerAdapters();

    fastingProtocols = await _openBoxSafe<FastingProtocol>(
      fastingProtocolsBox,
      validate: true,
    );
    fastingSessions = await _openBoxSafe<FastingSession>(
      fastingSessionsBox,
      validate: true,
    );
    settings = await _openBoxSafe<String>(settingsBox);
    meals = await _openBoxSafe<Meal>(mealsBox, validate: true);
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(FastingProtocolAdapter.typeKey)) {
      Hive.registerAdapter(FastingProtocolAdapter());
    }
    if (!Hive.isAdapterRegistered(FastingSessionAdapter.typeKey)) {
      Hive.registerAdapter(FastingSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(MealAdapter.typeKey)) {
      Hive.registerAdapter(MealAdapter());
    }
  }

  static Future<Box<T>> _openBoxSafe<T>(
    String name, {
    bool validate = false,
  }) async {
    try {
      final box = await Hive.openBox<T>(name);
      if (validate) {
        try {
          // Force a read to catch corrupted data.
          box.values.length;
        } catch (_) {
          await box.close();
          await Hive.deleteBoxFromDisk(name);
          return Hive.openBox<T>(name);
        }
      }
      return box;
    } catch (_) {
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<T>(name);
    }
  }
}
