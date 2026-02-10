import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive_ce.dart';

enum FastingSessionStatus {
  running,
  paused,
  ended,
}

class FastingSession extends Equatable {
  const FastingSession({
    required this.id,
    required this.userId,
    required this.protocolId,
    required this.startAt,
    required this.endAtPlanned,
    required this.pausedTotalSeconds,
    required this.status,
    this.endedAt,
    this.pausedAt,
  });

  final String id;
  final String userId;
  final String protocolId;
  final DateTime startAt;
  final DateTime endAtPlanned;
  final DateTime? endedAt;
  final DateTime? pausedAt;
  final int pausedTotalSeconds;
  final FastingSessionStatus status;

  Duration get totalDuration => endAtPlanned.difference(startAt);

  Duration elapsed(DateTime now) {
    final effectiveEnd = endedAt ?? pausedAt ?? now;
    final rawSeconds =
        effectiveEnd.difference(startAt).inSeconds - pausedTotalSeconds;
    if (rawSeconds <= 0) {
      return Duration.zero;
    }
    return Duration(seconds: rawSeconds);
  }

  Duration remaining(DateTime now) {
    final totalSeconds = totalDuration.inSeconds;
    final elapsedSeconds = elapsed(now).inSeconds;
    final remainingSeconds = totalSeconds - elapsedSeconds;
    if (remainingSeconds <= 0) {
      return Duration.zero;
    }
    return Duration(seconds: remainingSeconds);
  }

  bool isCompleted(DateTime now) => remaining(now) == Duration.zero;

  FastingSession copyWith({
    String? id,
    String? userId,
    String? protocolId,
    DateTime? startAt,
    DateTime? endAtPlanned,
    DateTime? endedAt,
    DateTime? pausedAt,
    int? pausedTotalSeconds,
    FastingSessionStatus? status,
  }) {
    return FastingSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      protocolId: protocolId ?? this.protocolId,
      startAt: startAt ?? this.startAt,
      endAtPlanned: endAtPlanned ?? this.endAtPlanned,
      endedAt: endedAt ?? this.endedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      pausedTotalSeconds: pausedTotalSeconds ?? this.pausedTotalSeconds,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        protocolId,
        startAt,
        endAtPlanned,
        endedAt,
        pausedAt,
        pausedTotalSeconds,
        status,
      ];
}

class FastingSessionAdapter extends TypeAdapter<FastingSession> {
  static const int typeKey = 2;

  @override
  int get typeId => typeKey;

  @override
  FastingSession read(BinaryReader reader) {
    final id = reader.readString();
    final second = reader.readString();
    final third = reader.read();

    if (third is String) {
      final userId = second;
      final protocolId = third;
      final startAtMillis = reader.readInt();
      final endAtPlannedMillis = reader.readInt();
      final endedAtMillis = reader.readInt();
      final pausedAtMillis = reader.readInt();
      final pausedTotalSeconds = reader.readInt();
      final statusIndex = reader.readInt();
      final maxIndex = FastingSessionStatus.values.length - 1;
      final safeIndex = statusIndex < 0
          ? 0
          : statusIndex > maxIndex
              ? maxIndex
              : statusIndex;
      final status = FastingSessionStatus.values[safeIndex];

      return FastingSession(
        id: id,
        userId: userId,
        protocolId: protocolId,
        startAt: DateTime.fromMillisecondsSinceEpoch(startAtMillis),
        endAtPlanned: DateTime.fromMillisecondsSinceEpoch(endAtPlannedMillis),
        endedAt: endedAtMillis == 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(endedAtMillis),
        pausedAt: pausedAtMillis == 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(pausedAtMillis),
        pausedTotalSeconds: pausedTotalSeconds,
        status: status,
      );
    }

    if (third is int || third is num) {
      final protocolId = second;
      final startedAtMillis = third is int ? third : third.toInt();
      final endedAtMillis = reader.readInt();
      final startAt = DateTime.fromMillisecondsSinceEpoch(startedAtMillis);
      final endedAt = endedAtMillis == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endedAtMillis);

      return FastingSession(
        id: id,
        userId: '',
        protocolId: protocolId,
        startAt: startAt,
        endAtPlanned: endedAt ?? startAt,
        endedAt: endedAt,
        pausedAt: null,
        pausedTotalSeconds: 0,
        status: endedAt == null
            ? FastingSessionStatus.running
            : FastingSessionStatus.ended,
      );
    }

    return FastingSession(
      id: 'invalid',
      userId: '',
      protocolId: '',
      startAt: DateTime.fromMillisecondsSinceEpoch(0),
      endAtPlanned: DateTime.fromMillisecondsSinceEpoch(0),
      pausedTotalSeconds: 0,
      status: FastingSessionStatus.ended,
    );
  }

  @override
  void write(BinaryWriter writer, FastingSession obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.userId)
      ..writeString(obj.protocolId)
      ..writeInt(obj.startAt.millisecondsSinceEpoch)
      ..writeInt(obj.endAtPlanned.millisecondsSinceEpoch)
      ..writeInt(obj.endedAt?.millisecondsSinceEpoch ?? 0)
      ..writeInt(obj.pausedAt?.millisecondsSinceEpoch ?? 0)
      ..writeInt(obj.pausedTotalSeconds)
      ..writeInt(obj.status.index);
  }
}
