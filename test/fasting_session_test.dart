import 'package:flutter_test/flutter_test.dart';

import 'package:desafio_maba/features/fasting/domain/fasting_session.dart';

void main() {
  test('FastingSession elapsed and remaining are calculated correctly', () {
    final start = DateTime(2025, 1, 1, 8, 0, 0);
    final plannedEnd = DateTime(2025, 1, 1, 16, 0, 0);
    final session = FastingSession(
      id: 's1',
      userId: 'u1',
      protocolId: 'p1',
      startAt: start,
      endAtPlanned: plannedEnd,
      pausedTotalSeconds: 0,
      status: FastingSessionStatus.running,
    );

    final now = DateTime(2025, 1, 1, 10, 30, 15);
    expect(
      session.elapsed(now),
      const Duration(hours: 2, minutes: 30, seconds: 15),
    );
    expect(
      session.remaining(now),
      const Duration(hours: 5, minutes: 29, seconds: 45),
    );
  });

  test('FastingSession remaining is zero after planned end', () {
    final start = DateTime(2025, 1, 1, 8, 0, 0);
    final plannedEnd = DateTime(2025, 1, 1, 16, 0, 0);
    final session = FastingSession(
      id: 's2',
      userId: 'u1',
      protocolId: 'p1',
      startAt: start,
      endAtPlanned: plannedEnd,
      pausedTotalSeconds: 0,
      status: FastingSessionStatus.running,
    );

    final now = DateTime(2025, 1, 1, 18, 0, 0);
    expect(session.remaining(now), Duration.zero);
  });
}
