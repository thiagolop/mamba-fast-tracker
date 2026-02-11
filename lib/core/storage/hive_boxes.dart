import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  static const String storageErrorMessage =
      'Falha ao carregar armazenamento local. Reinicie o app.';
  static bool allowDestructiveRecovery = false;
  static bool hasStorageIssue = false;
  static bool isRecoveryMode = false;
  static String? lastStorageError;
  static final List<String> _diagnostics = [];
  static final Map<String, String> _boxNameOverrides = {};
  static String? _hiveDir;
  static String? _backupDir;

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

    fastingProtocols = await _ensureOpen(
      fastingProtocolsBox,
      fastingProtocols,
      validate: true,
    );
    fastingSessions = await _ensureOpen(
      fastingSessionsBox,
      fastingSessions,
      validate: true,
    );
    settings = await _ensureOpen(settingsBox, settings);
    meals = await _ensureOpen(mealsBox, meals, validate: true);

    await _restoreEmptyBoxesOnBoot();

    _log(
      'HIVE: boxes opened (protocols=${fastingProtocols.length}, sessions=${fastingSessions.length}, meals=${meals.length}, settings=${settings.length})',
    );
    _log('HIVE: dir=$_hiveDir backupDir=$_backupDir');
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
    if (Hive.isBoxOpen(name)) {
      final alreadyOpen = Hive.box<T>(name);
      _log('HIVE: reuse open box $name (len=${alreadyOpen.length})');
      _setHiveDirFromBox(alreadyOpen);
      return alreadyOpen;
    }
    final backoffs = [150, 300, 600];
    Object? lastError;

    for (var attempt = 0; attempt < backoffs.length; attempt++) {
      try {
        final box = await Hive.openBox<T>(name);
        if (validate) {
          try {
            // Force a read to catch corrupted data.
            box.values.length;
          } catch (_) {
            _log('HIVE: validation failed for $name (keeping data)');
          }
        }
        _log('HIVE: opened $name (len=${box.length})');
        _setHiveDirFromBox(box);
        return box;
      } catch (e) {
        lastError = e;
        lastStorageError = e.toString();
        _log('HIVE: open failed for $name (attempt ${attempt + 1}) -> $e');
        await Hive.close();
        await Future.delayed(Duration(milliseconds: backoffs[attempt]));
      }
    }

    final error = lastError ?? Exception('Unknown Hive error');
    final isCorruption = _isCorruptionError(error);

    if (kDebugMode && allowDestructiveRecovery && isCorruption) {
      _log('HIVE: destructive recovery enabled for $name');
      try {
        await Hive.deleteBoxFromDisk(name);
        _log('HIVE: deleted corrupted box $name');
        final recovered = await Hive.openBox<T>(name);
        _log('HIVE: recovered $name (len=${recovered.length})');
        return recovered;
      } catch (e) {
        lastStorageError = e.toString();
        _log('HIVE: destructive recovery failed for $name -> $e');
      }
    }

    isRecoveryMode = true;
    var restoredSnapshot = false;
    final recoveryName = '${name}_recovery';
    _boxNameOverrides[name] = recoveryName;
    _log('HIVE: opening recovery box for $name');
    final recoveryBox = await _openRecoveryBox<T>(recoveryName);
    restoredSnapshot =
        await _restoreSnapshotIntoBox<T>(recoveryBox, name);
    if (!restoredSnapshot) {
      hasStorageIssue = true;
    }
    return recoveryBox;
  }

  static Future<Box<T>> _ensureOpen<T>(
    String name,
    Box<T> box, {
    bool validate = false,
  }) async {
    if (box.isOpen) return box;
    final effectiveName = _boxNameOverrides[name] ?? name;
    if (Hive.isBoxOpen(effectiveName)) {
      final alreadyOpen = Hive.box<T>(effectiveName);
      _log('HIVE: reuse open box $effectiveName (len=${alreadyOpen.length})');
      _setHiveDirFromBox(alreadyOpen);
      return alreadyOpen;
    }
    final reopened = await Hive.openBox<T>(effectiveName);
    if (validate) {
      try {
        reopened.values.length;
      } catch (_) {
        _log('HIVE: validation failed for reopened $effectiveName');
      }
    }
    _log('HIVE: reopened $effectiveName (len=${reopened.length})');
    _setHiveDirFromBox(reopened);
    return reopened;
  }

  static bool _isCorruptionError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('rangeerror') ||
        message.contains('not enough bytes') ||
        message.contains('invalid') && message.contains('frame') ||
        message.contains('corrupt');
  }

  static void _setHiveDirFromBox(BoxBase<dynamic> box) {
    if (_hiveDir != null && _backupDir != null) {
      return;
    }
    final path = box.path;
    if (path == null) return;
    final dir = File(path).parent.path;
    _hiveDir = dir;
    _backupDir = '$dir${Platform.pathSeparator}hive_backups';
    Directory(_backupDir!).createSync(recursive: true);
    _log('HIVE: resolved dir=$_hiveDir backupDir=$_backupDir');
  }

  static void _log(String message) {
    _diagnostics.add(message);
    if (_diagnostics.length > 200) {
      _diagnostics.removeAt(0);
    }
  }

  static void addDiagnostic(String message) {
    _log(message);
  }

  static Future<void> _restoreEmptyBoxesOnBoot() async {
    await restoreSnapshotIfEmpty<FastingSession>(fastingSessionsBox);
    await restoreSnapshotIfEmpty<Meal>(mealsBox);
    await restoreSnapshotIfEmpty<String>(settingsBox);
  }

  static Future<bool> restoreSnapshotIfEmpty<T>(String name) async {
    final backupDir = _backupDir;
    if (backupDir == null) return false;
    final effectiveName = _boxNameOverrides[name] ?? name;
    if (!Hive.isBoxOpen(effectiveName)) return false;
    final box = Hive.box<T>(effectiveName);
    if (box.isNotEmpty) return false;
    final restored = await _restoreSnapshotIntoBox<T>(box, name);
    if (restored) {
      await box.flush();
      _log('HIVE: snapshot restored into empty $name');
    }
    return restored;
  }

  static Future<Box<T>> _openRecoveryBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      final alreadyOpen = Hive.box<T>(name);
      _log('HIVE: reuse open recovery box $name (len=${alreadyOpen.length})');
      return alreadyOpen;
    }
    try {
      final box = await Hive.openBox<T>(name);
      _log('HIVE: opened recovery box $name (len=${box.length})');
      _setHiveDirFromBox(box);
      return box;
    } catch (e) {
      lastStorageError = e.toString();
      _log('HIVE: open recovery failed for $name -> $e');
      try {
        await Hive.deleteBoxFromDisk(name);
        _log('HIVE: deleted recovery box $name');
      } catch (deleteError) {
        _log('HIVE: delete recovery failed for $name -> $deleteError');
      }
      try {
        final box = await Hive.openBox<T>(
          name,
          bytes: Uint8List(0),
        );
        _log('HIVE: opened in-memory recovery box $name');
        return box;
      } catch (memoryError) {
        lastStorageError = memoryError.toString();
        _log('HIVE: open in-memory recovery failed -> $memoryError');
        rethrow;
      }
    }
  }

  static Future<void> backupBox<T>(String name) async {
    final backupDir = _backupDir;
    if (backupDir == null) return;
    final effectiveName = _boxNameOverrides[name] ?? name;
    if (!Hive.isBoxOpen(effectiveName)) return;
    final box = Hive.box<T>(effectiveName);
    if (name == fastingSessionsBox && T == FastingSession) {
      await _writeSnapshot(
        name,
        box.toMap().entries.map((entry) {
          final session = entry.value as FastingSession;
          return {
            'key': entry.key.toString(),
            'value': _fastingSessionToMap(session),
          };
        }).toList(),
      );
      return;
    }
    if (name == mealsBox && T == Meal) {
      await _writeSnapshot(
        name,
        box.toMap().entries.map((entry) {
          final meal = entry.value as Meal;
          return {
            'key': entry.key.toString(),
            'value': _mealToMap(meal),
          };
        }).toList(),
      );
      return;
    }
    if (name == settingsBox && T == String) {
      await _writeSnapshot(
        name,
        box.toMap().entries.map((entry) {
          return {
            'key': entry.key.toString(),
            'value': entry.value,
          };
        }).toList(),
      );
      return;
    }
  }

  static String diagnosticsReport() {
    final buffer = StringBuffer();
    buffer.writeln('hasStorageIssue=$hasStorageIssue');
    if (lastStorageError != null) {
      buffer.writeln('lastStorageError=$lastStorageError');
    }
    buffer.writeln('logs:');
    for (final line in _diagnostics) {
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  static Future<bool> _restoreSnapshotIntoBox<T>(
    Box<T> box,
    String name,
  ) async {
    final backupDir = _backupDir;
    if (backupDir == null) {
      return false;
    }
    final backupPath =
        '$backupDir${Platform.pathSeparator}$name.json';
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      return false;
    }
    try {
      final content = await backupFile.readAsString();
      if (content.trim().isEmpty) {
        _log('HIVE: snapshot empty for $name');
        return false;
      }
      final decoded = jsonDecode(content);
      if (decoded is! List) return false;
      var restoredCount = 0;
      if (name == fastingSessionsBox && T == FastingSession) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final key = item['key']?.toString() ?? '';
          final value = item['value'];
          if (key.isEmpty || value is! Map) continue;
          final session = _fastingSessionFromMap(
            Map<String, dynamic>.from(value),
          );
          await box.put(key, session as T);
          restoredCount += 1;
        }
      } else if (name == mealsBox && T == Meal) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final key = item['key']?.toString() ?? '';
          final value = item['value'];
          if (key.isEmpty || value is! Map) continue;
          final meal = _mealFromMap(
            Map<String, dynamic>.from(value),
          );
          await box.put(key, meal as T);
          restoredCount += 1;
        }
      } else if (name == settingsBox && T == String) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final key = item['key']?.toString() ?? '';
          final value = item['value'];
          if (key.isEmpty || value is! String) continue;
          await box.put(key, value as T);
          restoredCount += 1;
        }
      }
      if (restoredCount == 0) {
        _log('HIVE: snapshot restore empty for $name');
        return false;
      }
      _log('HIVE: restored $name from snapshot ($restoredCount items)');
      return true;
    } catch (e) {
      lastStorageError = e.toString();
      _log('HIVE: snapshot restore failed for $name -> $e');
      return false;
    }
  }

  static Future<void> _writeSnapshot(
    String name,
    List<Map<String, dynamic>> entries,
  ) async {
    final backupDir = _backupDir;
    if (backupDir == null) return;
    final backupPath =
        '$backupDir${Platform.pathSeparator}$name.json';
    try {
      final content = jsonEncode(entries);
      await File(backupPath).writeAsString(content);
      _log('HIVE: snapshot ok for $name (items=${entries.length})');
    } catch (e) {
      lastStorageError = e.toString();
      _log('HIVE: snapshot failed for $name -> $e');
    }
  }

  static Map<String, dynamic> _fastingSessionToMap(
    FastingSession session,
  ) {
    return {
      'id': session.id,
      'userId': session.userId,
      'protocolId': session.protocolId,
      'startAt': session.startAt.millisecondsSinceEpoch,
      'endAtPlanned': session.endAtPlanned.millisecondsSinceEpoch,
      'endedAt': session.endedAt?.millisecondsSinceEpoch,
      'pausedAt': session.pausedAt?.millisecondsSinceEpoch,
      'pausedTotalSeconds': session.pausedTotalSeconds,
      'status': session.status.index,
    };
  }

  static FastingSession _fastingSessionFromMap(
    Map<String, dynamic> map,
  ) {
    final statusIndex = map['status'] is int ? map['status'] as int : 0;
    final maxIndex = FastingSessionStatus.values.length - 1;
    final safeIndex = statusIndex < 0
        ? 0
        : statusIndex > maxIndex
            ? maxIndex
            : statusIndex;
    return FastingSession(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      protocolId: map['protocolId']?.toString() ?? '',
      startAt: DateTime.fromMillisecondsSinceEpoch(
        map['startAt'] as int,
      ),
      endAtPlanned: DateTime.fromMillisecondsSinceEpoch(
        map['endAtPlanned'] as int,
      ),
      endedAt: map['endedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int),
      pausedAt: map['pausedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['pausedAt'] as int),
      pausedTotalSeconds:
          map['pausedTotalSeconds'] as int? ?? 0,
      status: FastingSessionStatus.values[safeIndex],
    );
  }

  static Map<String, dynamic> _mealToMap(Meal meal) {
    return {
      'id': meal.id,
      'userId': meal.userId,
      'name': meal.name,
      'calories': meal.calories,
      'createdAt': meal.createdAt.millisecondsSinceEpoch,
      'dateKey': meal.dateKey,
    };
  }

  static Meal _mealFromMap(Map<String, dynamic> map) {
    final createdAtMillis = map['createdAt'] as int? ?? 0;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      createdAtMillis,
    );
    final dateKey = map['dateKey']?.toString() ??
        DateTime(createdAt.year, createdAt.month, createdAt.day)
            .toIso8601String()
            .split('T')
            .first;
    return Meal(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      calories: map['calories'] as int? ?? 0,
      createdAt: createdAt,
      dateKey: dateKey,
    );
  }
}
