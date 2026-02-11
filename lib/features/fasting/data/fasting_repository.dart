import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/hive_boxes.dart';
import '../domain/fasting_protocol.dart';
import '../domain/fasting_session.dart';

class FastingRepository {
  static String _protocolKey(String userId) => 'protocol:$userId';
  static String _activeKey(String userId) => 'active:$userId';
  static String _sessionKey(String userId, String sessionId) =>
      '$userId:$sessionId';

  Future<List<FastingProtocol>> listProtocols() async {
    await _seedProtocolsIfNeeded();
    var items = HiveBoxes.fastingProtocols.values.toList();
    if (items.isEmpty) {
      await _seedProtocolsIfNeeded(force: true);
      items = HiveBoxes.fastingProtocols.values.toList();
    }
    items.sort(
      (a, b) => a.fastingMinutes.compareTo(b.fastingMinutes),
    );
    return items;
  }

  Future<void> _seedProtocolsIfNeeded({bool force = false}) async {
    if (!force && HiveBoxes.fastingProtocols.isNotEmpty) {
      return;
    }
    if (force) {
      await HiveBoxes.fastingProtocols.clear();
    }
    for (final protocol in FastingProtocol.defaults) {
      await HiveBoxes.fastingProtocols.put(protocol.id, protocol);
    }
  }

  Future<FastingProtocol?> getSelectedProtocol(String userId) async {
    final protocols = await listProtocols();
    final selectedId = HiveBoxes.settings.get(_protocolKey(userId));
    if (selectedId == null || selectedId.isEmpty) {
      if (protocols.isEmpty) {
        return null;
      }
      final fallback = protocols.first;
      await setSelectedProtocol(userId, fallback.id);
      return fallback;
    }
    return HiveBoxes.fastingProtocols.get(selectedId);
  }

  Future<void> setSelectedProtocol(
    String userId,
    String protocolId,
  ) async {
    await HiveBoxes.settings.put(_protocolKey(userId), protocolId);
    await HiveBoxes.settings.flush();
    await HiveBoxes.backupBox<String>(HiveBoxes.settingsBox);
  }

  Future<FastingSession?> getActiveSession(String userId) async {
    await HiveBoxes.restoreSnapshotIfEmpty<String>(
      HiveBoxes.settingsBox,
    );
    await HiveBoxes.restoreSnapshotIfEmpty<FastingSession>(
      HiveBoxes.fastingSessionsBox,
    );
    final sessionRef = HiveBoxes.settings.get(_activeKey(userId));
    if (sessionRef == null || sessionRef.isEmpty) {
      return _findRunningFallback(userId);
    }
    FastingSession? session;
    try {
      session = HiveBoxes.fastingSessions.get(sessionRef);
      session ??= HiveBoxes.fastingSessions.get(
        _sessionKey(userId, sessionRef),
      );
    } catch (e) {
      HiveBoxes.addDiagnostic(
        'FASTING_REPO: read active session failed -> $e',
      );
      HiveBoxes.lastStorageError = e.toString();
      await HiveBoxes.restoreSnapshotIfEmpty<FastingSession>(
        HiveBoxes.fastingSessionsBox,
      );
      try {
        session = HiveBoxes.fastingSessions.get(sessionRef);
        session ??= HiveBoxes.fastingSessions.get(
          _sessionKey(userId, sessionRef),
        );
      } catch (retryError) {
        HiveBoxes.addDiagnostic(
          'FASTING_REPO: retry read active session failed -> $retryError',
        );
        HiveBoxes.lastStorageError = retryError.toString();
      }
    }
    if (session == null) {
      return _findRunningFallback(userId);
    }
    if (session.userId.isEmpty) {
      return session.copyWith(userId: userId);
    }
    if (session.userId != userId) {
      return _findRunningFallback(userId);
    }
    return session;
  }

  Future<FastingSession?> _findRunningFallback(String userId) async {
    FastingSession? latest;
    String? latestKey;

    Future<void> scanEntries() async {
      final entries = HiveBoxes.fastingSessions.toMap().entries;
      for (final entry in entries) {
        final key = entry.key;
        final session = entry.value;
        final matchesUser =
            session.userId == userId ||
            (session.userId.isEmpty &&
                key is String &&
                key.startsWith('$userId:'));
        if (!matchesUser) continue;
        if (session.status != FastingSessionStatus.running) continue;
        if (latest == null ||
            session.startAt.isAfter(
              latest?.startAt ?? DateTime.now(),
            )) {
          latest = session.userId.isEmpty
              ? session.copyWith(userId: userId)
              : session;
          latestKey = key is String ? key : null;
        }
      }
    }

    try {
      await scanEntries();
    } catch (e) {
      HiveBoxes.addDiagnostic(
        'FASTING_REPO: scan sessions failed -> $e',
      );
      HiveBoxes.lastStorageError = e.toString();
      await HiveBoxes.restoreSnapshotIfEmpty<FastingSession>(
        HiveBoxes.fastingSessionsBox,
      );
      try {
        latest = null;
        latestKey = null;
        await scanEntries();
      } catch (retryError) {
        HiveBoxes.addDiagnostic(
          'FASTING_REPO: retry scan sessions failed -> $retryError',
        );
        HiveBoxes.lastStorageError = retryError.toString();
      }
    }
    if (latestKey != null) {
      await HiveBoxes.settings.put(
        _activeKey(userId),
        latestKey ?? '',
      );
    }
    return latest;
  }

  Future<void> saveActiveSession(
    String userId,
    FastingSession session,
  ) async {
    final key = _sessionKey(userId, session.id);
    await HiveBoxes.fastingSessions.put(key, session);
    await HiveBoxes.settings.put(_activeKey(userId), key);
    await HiveBoxes.fastingSessions.flush();
    await HiveBoxes.settings.flush();
    await HiveBoxes.backupBox<FastingSession>(
      HiveBoxes.fastingSessionsBox,
    );
    await HiveBoxes.backupBox<String>(HiveBoxes.settingsBox);
  }

  Future<void> clearActiveSession(String userId) async {
    await HiveBoxes.settings.delete(_activeKey(userId));
    await HiveBoxes.settings.flush();
    await HiveBoxes.backupBox<String>(HiveBoxes.settingsBox);
  }

  Future<List<FastingSession>> listSessionsForUser(
    String userId,
  ) async {
    await HiveBoxes.restoreSnapshotIfEmpty<FastingSession>(
      HiveBoxes.fastingSessionsBox,
    );
    final items = <FastingSession>[];
    final activeRef = HiveBoxes.settings.get(_activeKey(userId));
    final entries = HiveBoxes.fastingSessions.toMap().entries;
    for (final entry in entries) {
      final key = entry.key;
      final session = entry.value;
      if (session.userId == userId) {
        items.add(session);
        continue;
      }
      if (session.userId.isEmpty &&
          key is String &&
          (key.startsWith('$userId:') ||
              key == activeRef ||
              session.id == activeRef)) {
        items.add(session.copyWith(userId: userId));
      }
    }
    items.sort((a, b) => b.startAt.compareTo(a.startAt));
    return items;
  }
}

final fastingRepositoryProvider = Provider<FastingRepository>((ref) {
  return FastingRepository();
});

final fastingSessionsChangesProvider = StreamProvider<int>((
  ref,
) async* {
  yield DateTime.now().millisecondsSinceEpoch;
  await for (final _ in HiveBoxes.fastingSessions.watch()) {
    yield DateTime.now().millisecondsSinceEpoch;
  }
});
