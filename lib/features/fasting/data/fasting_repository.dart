import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/hive_boxes.dart';
import '../domain/fasting_protocol.dart';
import '../domain/fasting_session.dart';

class FastingRepository {
  static String _protocolKey(String userId) => 'protocol:$userId';
  static String _activeKey(String userId) => 'active:$userId';

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
    final sessionId = HiveBoxes.settings.get(_activeKey(userId));
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }
    final session = HiveBoxes.fastingSessions.get(sessionId);
    if (session == null || session.userId != userId) {
      return null;
    }
    return session;
  }

  Future<void> saveActiveSession(String userId, FastingSession session) async {
    await HiveBoxes.fastingSessions.put(session.id, session);
    await HiveBoxes.settings.put(_activeKey(userId), session.id);
  }

  Future<void> clearActiveSession(String userId) async {
    await HiveBoxes.settings.delete(_activeKey(userId));
  }
}

final fastingRepositoryProvider = Provider<FastingRepository>((ref) {
  return FastingRepository();
});
