import 'fasting_protocol.dart';
import 'fasting_session.dart';

class FastingEngine {
  const FastingEngine();

  FastingSession start({
    required String id,
    required String userId,
    required FastingProtocol protocol,
    required DateTime now,
  }) {
    final endAtPlanned = now.add(protocol.fastingDuration);
    return FastingSession(
      id: id,
      userId: userId,
      protocolId: protocol.id,
      startAt: now,
      endAtPlanned: endAtPlanned,
      pausedTotalSeconds: 0,
      status: FastingSessionStatus.running,
    );
  }

  FastingSession pause({
    required FastingSession session,
    required DateTime now,
  }) {
    if (session.status != FastingSessionStatus.running) {
      return session;
    }
    return session.copyWith(
      pausedAt: now,
      status: FastingSessionStatus.paused,
    );
  }

  FastingSession resume({
    required FastingSession session,
    required DateTime now,
  }) {
    if (session.status != FastingSessionStatus.paused) {
      return session;
    }

    final pausedAt = session.pausedAt;
    final rawPausedSeconds =
        pausedAt == null ? 0 : now.difference(pausedAt).inSeconds;
    final additionalPausedSeconds = rawPausedSeconds < 0 ? 0 : rawPausedSeconds;
    final totalPaused = session.pausedTotalSeconds + additionalPausedSeconds;

    return session.copyWith(
      pausedAt: null,
      pausedTotalSeconds: totalPaused,
      status: FastingSessionStatus.running,
    );
  }

  FastingSession end({
    required FastingSession session,
    required DateTime now,
  }) {
    if (session.status == FastingSessionStatus.ended) {
      return session;
    }

    final pausedAt = session.pausedAt;
    final rawPausedSeconds =
        pausedAt == null ? 0 : now.difference(pausedAt).inSeconds;
    final additionalPausedSeconds = rawPausedSeconds < 0 ? 0 : rawPausedSeconds;
    final totalPaused = session.pausedTotalSeconds + additionalPausedSeconds;

    return session.copyWith(
      endedAt: now,
      pausedAt: null,
      pausedTotalSeconds: totalPaused,
      status: FastingSessionStatus.ended,
    );
  }
}
