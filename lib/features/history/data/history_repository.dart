import '../../../core/time/date_key.dart';
import '../../fasting/data/fasting_repository.dart';
import '../../fasting/domain/fasting_session.dart';
import '../../meals/data/meals_repository.dart';
import '../../meals/domain/meal.dart';
import '../domain/daily_summary.dart';

class HistoryRepository {
  HistoryRepository({
    required MealsRepository mealsRepository,
    required FastingRepository fastingRepository,
  })  : _mealsRepository = mealsRepository,
        _fastingRepository = fastingRepository;

  final MealsRepository _mealsRepository;
  final FastingRepository _fastingRepository;

  Future<List<DailySummary>> listLastDays({
    required String userId,
    required DateTime now,
    required int days,
    required int metaCalories,
    required Duration metaFasting,
  }) async {
    final summaries = <DailySummary>[];
    for (var i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(
        Duration(days: i),
      );
      final summary = await buildSummaryForDay(
        userId: userId,
        date: date,
        now: now,
        metaCalories: metaCalories,
        metaFasting: metaFasting,
      );
      summaries.add(summary);
    }
    return summaries;
  }

  Future<DailySummary> buildSummaryForDay({
    required String userId,
    required DateTime date,
    required DateTime now,
    required int metaCalories,
    required Duration metaFasting,
  }) async {
    final dateKey = dateKeyFromDate(date);
    final meals = await _mealsRepository.listMealsForDay(userId, dateKey);
    final caloriesTotal = meals.fold<int>(
      0,
      (total, meal) => total + meal.calories,
    );
    final fastingTotal = await _fastingDurationForDay(
      userId: userId,
      date: date,
      now: now,
    );
    final isOnTrack = caloriesTotal <= metaCalories && fastingTotal >= metaFasting;

    return DailySummary(
      dateKey: dateKey,
      date: date,
      caloriesTotal: caloriesTotal,
      fastingTotal: fastingTotal,
      isOnTrack: isOnTrack,
    );
  }

  Future<List<Meal>> listMealsForDay(
    String userId,
    String dateKey,
  ) async {
    return _mealsRepository.listMealsForDay(userId, dateKey);
  }

  Future<Duration> _fastingDurationForDay({
    required String userId,
    required DateTime date,
    required DateTime now,
  }) async {
    final sessions = await _fastingRepository.listSessionsForUser(userId);
    if (sessions.isEmpty) return Duration.zero;

    final dayStart = startOfDay(date);
    final dayEnd = dayStart.add(const Duration(days: 1));

    var totalSeconds = 0;
    for (final session in sessions) {
      totalSeconds += _overlapSeconds(session, dayStart, dayEnd, now);
    }

    return Duration(seconds: totalSeconds);
  }

  int _overlapSeconds(
    FastingSession session,
    DateTime rangeStart,
    DateTime rangeEnd,
    DateTime now,
  ) {
    final start = session.startAt;
    final end = session.endedAt ?? now;

    if (end.isBefore(rangeStart) || start.isAfter(rangeEnd)) {
      return 0;
    }

    final effectiveStart = start.isAfter(rangeStart) ? start : rangeStart;
    final effectiveEnd = end.isBefore(rangeEnd) ? end : rangeEnd;

    if (!effectiveEnd.isAfter(effectiveStart)) {
      return 0;
    }

    return effectiveEnd.difference(effectiveStart).inSeconds;
  }
}
