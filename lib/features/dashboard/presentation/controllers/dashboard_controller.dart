import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/time/date_key.dart';
import '../../../../core/ui/ui_message.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../fasting/data/fasting_repository.dart';
import '../../../fasting/domain/fasting_session.dart';
import '../../../meals/data/meals_repository.dart';
import '../../../meals/domain/meal.dart';
import '../../domain/weekly_chart_item.dart';
import '../../domain/weekly_chart_service.dart';
import '../dashboard_strings.dart';

class DashboardUiState extends Equatable {
  const DashboardUiState({
    required this.isLoading,
    required this.todayCaloriesValue,
    required this.todayFastingValue,
    required this.todayCaloriesLabel,
    required this.todayFastingLabel,
    required this.statusLabel,
    required this.isOnTrack,
    required this.weeklyData,
    required this.recentFastingData,
    this.screenError,
    this.uiMessage,
  });

  final bool isLoading;
  final int todayCaloriesValue;
  final Duration todayFastingValue;
  final String todayCaloriesLabel;
  final String todayFastingLabel;
  final String statusLabel;
  final bool isOnTrack;
  final List<WeeklyChartItem> weeklyData;
  final List<WeeklyChartItem> recentFastingData;
  final String? screenError;
  final UiMessage? uiMessage;

  factory DashboardUiState.initial() {
    return DashboardUiState(
      isLoading: true,
      todayCaloriesValue: 0,
      todayFastingValue: Duration.zero,
      todayCaloriesLabel: '0 kcal',
      todayFastingLabel: '00:00:00',
      statusLabel: DashboardStrings.statusOnTrack,
      isOnTrack: true,
      weeklyData: const [],
      recentFastingData: const [],
    );
  }

  DashboardUiState copyWith({
    bool? isLoading,
    int? todayCaloriesValue,
    Duration? todayFastingValue,
    String? todayCaloriesLabel,
    String? todayFastingLabel,
    String? statusLabel,
    bool? isOnTrack,
    List<WeeklyChartItem>? weeklyData,
    List<WeeklyChartItem>? recentFastingData,
    String? screenError,
    UiMessage? uiMessage,
  }) {
    return DashboardUiState(
      isLoading: isLoading ?? this.isLoading,
      todayCaloriesValue:
          todayCaloriesValue ?? this.todayCaloriesValue,
      todayFastingValue: todayFastingValue ?? this.todayFastingValue,
      todayCaloriesLabel:
          todayCaloriesLabel ?? this.todayCaloriesLabel,
      todayFastingLabel: todayFastingLabel ?? this.todayFastingLabel,
      statusLabel: statusLabel ?? this.statusLabel,
      isOnTrack: isOnTrack ?? this.isOnTrack,
      weeklyData: weeklyData ?? this.weeklyData,
      recentFastingData: recentFastingData ?? this.recentFastingData,
      screenError: screenError,
      uiMessage: uiMessage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    todayCaloriesValue,
    todayFastingValue,
    todayCaloriesLabel,
    todayFastingLabel,
    statusLabel,
    isOnTrack,
    weeklyData,
    recentFastingData,
    screenError,
    uiMessage,
  ];
}

final dashboardUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) throw StateError('Usuário não autenticado');
  return user.uid;
});

class DashboardController extends Notifier<DashboardUiState> {
  _MetaTargets? _metaTargets;
  bool _isRefreshing = false;
  Timer? _ticker;

  MealsRepository get _mealsRepository =>
      ref.read(mealsRepositoryProvider);
  FastingRepository get _fastingRepository =>
      ref.read(fastingRepositoryProvider);
  Clock get _clock => ref.read(clockProvider);
  String get _userId => ref.read(dashboardUserIdProvider);

  @override
  DashboardUiState build() {
    state = DashboardUiState.initial();
    Future.microtask(_load);
    ref.onDispose(_stopTicker);
    ref.listen(mealsChangesProvider, (previous, next) => _load());
    ref.listen(fastingSessionsChangesProvider, (previous, next) => _load());
    return state;
  }

  Future<void> refresh() async {
    await _load();
  }

  void consumeMessage() {
    state = state.copyWith(uiMessage: null);
  }

  Future<void> _load() async {
    try {
      state = state.copyWith(isLoading: true, screenError: null);
      final now = _clock.now();
      final meta = await _resolveMeta();
      _metaTargets = meta;

      final todayKey = dateKeyFromDate(now);
      final todayMeals = await _mealsRepository.listMealsForDay(
        _userId,
        todayKey,
      );
      final todayCalories = _sumCalories(todayMeals);
      final activeSession =
          await _fastingRepository.getActiveSession(_userId);
      final todayFasting = await _fastingDurationForDay(
        now,
        activeSession: activeSession,
      );

      final isOnTrack =
          todayCalories <= meta.metaCalories &&
          todayFasting >= meta.metaFasting;

      final weekly = await _weeklyCalories(now);
      final recentFasting = await _recentFastingSeries(
        now,
        activeSession: activeSession,
      );

      state = state.copyWith(
        isLoading: false,
        todayCaloriesValue: todayCalories,
        todayFastingValue: todayFasting,
        todayCaloriesLabel: '$todayCalories kcal',
        todayFastingLabel: _formatDuration(todayFasting),
        statusLabel: isOnTrack
            ? DashboardStrings.statusOnTrack
            : DashboardStrings.statusOffTrack,
        isOnTrack: isOnTrack,
        weeklyData: weekly,
        recentFastingData: recentFasting,
        screenError: null,
      );

      await _syncTicker();
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        screenError: DashboardStrings.errorLoad,
      );
    }
  }

  Future<void> _syncTicker() async {
    final active = await _findRunningSession();
    if (active != null) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshFastingNow(),
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _refreshFastingNow() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final active = await _findRunningSession();
      if (active == null) {
        _stopTicker();
        return;
      }

      final now = _clock.now();
      final meta = _metaTargets ?? await _resolveMeta();
      _metaTargets ??= meta;

      final todayFasting = await _fastingDurationForDay(
        now,
        activeSession: active,
      );
      final isOnTrack =
          state.todayCaloriesValue <= meta.metaCalories &&
          todayFasting >= meta.metaFasting;

      final recentFasting = await _recentFastingSeries(
        now,
        activeSession: active,
      );

      state = state.copyWith(
        todayFastingValue: todayFasting,
        todayFastingLabel: _formatDuration(todayFasting),
        statusLabel: isOnTrack
            ? DashboardStrings.statusOnTrack
            : DashboardStrings.statusOffTrack,
        isOnTrack: isOnTrack,
        recentFastingData: recentFasting,
      );
    } finally {
      _isRefreshing = false;
    }
  }

  Future<_MetaTargets> _resolveMeta() async {
    final protocol = await _fastingRepository.getSelectedProtocol(
      _userId,
    );
    final metaFasting =
        protocol?.fastingDuration ?? const Duration(hours: 16);
    return _MetaTargets(metaCalories: 2000, metaFasting: metaFasting);
  }

  Future<List<WeeklyChartItem>> _weeklyCalories(DateTime now) async {
    final meals = await _mealsRepository.listMealsForUser(_userId);
    return WeeklyChartService.buildCaloriesSeries(now: now, meals: meals);
  }

  Future<FastingSession?> _findRunningSession() async {
    final sessions =
        await _fastingRepository.listSessionsForUser(_userId);
    for (final session in sessions) {
      if (session.status == FastingSessionStatus.running) {
        return session;
      }
    }
    return null;
  }

  Future<List<WeeklyChartItem>> _recentFastingSeries(
    DateTime now, {
    FastingSession? activeSession,
  }) async {
    final sessions = await _fastingRepository.listSessionsForUser(_userId);
    final active = activeSession;
    if (active != null && !sessions.any((item) => item.id == active.id)) {
      sessions.add(active);
    }
    if (sessions.isEmpty) return const [];

    sessions.sort((a, b) => b.startAt.compareTo(a.startAt));
    final recent = sessions.take(7).toList().reversed;

    return recent
        .map(
          (session) {
            final duration = session.elapsed(now);
            final hours = duration.inMinutes / 60.0;
            return WeeklyChartItem(
              date: session.startAt,
              label: DateFormat('dd/MM').format(session.startAt),
              value: double.parse(hours.toStringAsFixed(1)),
            );
          },
        )
        .toList();
  }

  int _sumCalories(List<Meal> meals) {
    return meals.fold<int>(0, (total, item) => total + item.calories);
  }

  Future<Duration> _fastingDurationForDay(
    DateTime date, {
    FastingSession? activeSession,
  }) async {
    final sessions = await _fastingRepository.listSessionsForUser(
      _userId,
    );
    final active = activeSession;
    if (active != null && !sessions.any((item) => item.id == active.id)) {
      sessions.add(active);
    }
    if (sessions.isEmpty) return Duration.zero;

    final dayStart = startOfDay(date);
    final dayEnd = dayStart.add(const Duration(days: 1));
    var totalSeconds = 0;
    final now = _clock.now();

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

    final effectiveStart = start.isAfter(rangeStart)
        ? start
        : rangeStart;
    final effectiveEnd = end.isBefore(rangeEnd) ? end : rangeEnd;

    if (!effectiveEnd.isAfter(effectiveStart)) {
      return 0;
    }

    return effectiveEnd.difference(effectiveStart).inSeconds;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

}

class _MetaTargets {
  const _MetaTargets({
    required this.metaCalories,
    required this.metaFasting,
  });

  final int metaCalories;
  final Duration metaFasting;
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardUiState>(
      DashboardController.new,
    );
