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
    final items = HiveBoxes.fastingProtocols.values.toList();
    items.sort((a, b) => a.fastingMinutes.compareTo(b.fastingMinutes));
    return items;
  }

  Future<void> _seedProtocolsIfNeeded() async {
    if (HiveBoxes.fastingProtocols.isNotEmpty) {
      return;
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

  Future<void> setSelectedProtocol(String userId, String protocolId) async {
    await HiveBoxes.settings.put(_protocolKey(userId), protocolId);
  }

  Future<FastingSession?> getActiveSession(String userId) async {
    final sessionRef = HiveBoxes.settings.get(_activeKey(userId));
    if (sessionRef == null || sessionRef.isEmpty) {
      return null;
    }
    var session = HiveBoxes.fastingSessions.get(sessionRef);
    session ??= HiveBoxes.fastingSessions.get(_sessionKey(userId, sessionRef));
    if (session == null) {
      return null;
    }
    if (session.userId.isEmpty) {
      return session.copyWith(userId: userId);
    }
    if (session.userId != userId) {
      return null;
    }
    return session;
  }

  Future<void> saveActiveSession(String userId, FastingSession session) async {
    final key = _sessionKey(userId, session.id);
    await HiveBoxes.fastingSessions.put(key, session);
    await HiveBoxes.settings.put(_activeKey(userId), key);
  }

  Future<void> clearActiveSession(String userId) async {
    await HiveBoxes.settings.delete(_activeKey(userId));
  }

  Future<List<FastingSession>> listSessionsForUser(String userId) async {
    final items = <FastingSession>[];
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
          key.startsWith('$userId:')) {
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

final fastingSessionsChangesProvider = StreamProvider<int>((ref) async* {
  yield DateTime.now().millisecondsSinceEpoch;
  await for (final _ in HiveBoxes.fastingSessions.watch()) {
    yield DateTime.now().millisecondsSinceEpoch;
  }
});
