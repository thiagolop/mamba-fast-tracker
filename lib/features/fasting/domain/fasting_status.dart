import 'package:equatable/equatable.dart';

import 'fasting_protocol.dart';
import 'fasting_session.dart';

enum FastingPhase {
  fasting,
  feeding,
}

enum FastingState {
  inactive,
  fasting,
  feeding,
  completed,
}

class FastingStatus extends Equatable {
  const FastingStatus({
    required this.state,
    required this.elapsed,
    required this.remaining,
    required this.total,
    this.phase,
    this.phaseStartedAt,
    this.phaseEndsAt,
    this.session,
    this.protocol,
  });

  final FastingState state;
  final FastingPhase? phase;
  final Duration elapsed;
  final Duration remaining;
  final Duration total;
  final DateTime? phaseStartedAt;
  final DateTime? phaseEndsAt;
  final FastingSession? session;
  final FastingProtocol? protocol;

  bool get isActive => state == FastingState.fasting || state == FastingState.feeding;

  factory FastingStatus.inactive() {
    return const FastingStatus(
      state: FastingState.inactive,
      elapsed: Duration.zero,
      remaining: Duration.zero,
      total: Duration.zero,
    );
  }

  factory FastingStatus.fasting({
    required FastingSession session,
    required FastingProtocol protocol,
    required DateTime phaseStartedAt,
    required DateTime phaseEndsAt,
    required Duration elapsed,
    required Duration remaining,
  }) {
    return FastingStatus(
      state: FastingState.fasting,
      phase: FastingPhase.fasting,
      session: session,
      protocol: protocol,
      phaseStartedAt: phaseStartedAt,
      phaseEndsAt: phaseEndsAt,
      elapsed: elapsed,
      remaining: remaining,
      total: protocol.fastingDuration,
    );
  }

  factory FastingStatus.feeding({
    required FastingSession session,
    required FastingProtocol protocol,
    required DateTime phaseStartedAt,
    required DateTime phaseEndsAt,
    required Duration elapsed,
    required Duration remaining,
  }) {
    return FastingStatus(
      state: FastingState.feeding,
      phase: FastingPhase.feeding,
      session: session,
      protocol: protocol,
      phaseStartedAt: phaseStartedAt,
      phaseEndsAt: phaseEndsAt,
      elapsed: elapsed,
      remaining: remaining,
      total: protocol.feedingDuration,
    );
  }

  factory FastingStatus.completed({
    required FastingSession session,
    required FastingProtocol protocol,
  }) {
    return FastingStatus(
      state: FastingState.completed,
      session: session,
      protocol: protocol,
      elapsed: protocol.totalDuration,
      remaining: Duration.zero,
      total: protocol.totalDuration,
      phaseStartedAt: session.startAt,
      phaseEndsAt: session.startAt.add(protocol.totalDuration),
    );
  }

  @override
  List<Object?> get props => [
        state,
        phase,
        elapsed,
        remaining,
        total,
        phaseStartedAt,
        phaseEndsAt,
        session,
        protocol,
      ];
}
