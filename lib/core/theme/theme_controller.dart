import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/hive_boxes.dart';

class ThemeController extends Notifier<ThemeMode> {
  static const _storageKey = 'theme_mode';

  @override
  ThemeMode build() {
    final stored = HiveBoxes.settings.get(_storageKey);
    switch (stored) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  void toggleMode() {
    switch (state) {
      case ThemeMode.system:
        state = ThemeMode.dark;
        _persist('dark');
        break;
      case ThemeMode.dark:
        state = ThemeMode.light;
        _persist('light');
        break;
      case ThemeMode.light:
        state = ThemeMode.system;
        _persist('system');
        break;
    }
  }

  void _persist(String value) {
    try {
      HiveBoxes.settings.put(_storageKey, value);
    } catch (_) {}
  }
}

final themeModeProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
