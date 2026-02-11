import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/hive_boxes.dart';
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
    required this.metaLabel,
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
  final String metaLabel;
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
      metaLabel: '',
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
    String? metaLabel,
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
      metaLabel: metaLabel ?? this.metaLabel,
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
    metaLabel,
    isOnTrack,
    weeklyData,
    recentFastingData,
    screenError,
    uiMessage,
  ];

  String formatFastingChartValue(WeeklyChartItem item) {
    final seconds = (item.value * 3600).round();
    final duration = Duration(seconds: seconds);
    if (duration.inHours == 0) {
      final minutes = duration.inMinutes;
      final secs = duration.inSeconds.remainder(60);
      return '${minutes}m ${secs}s';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
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
  String? get _userIdOrNull =>
      ref.read(firebaseAuthProvider).currentUser?.uid;

  @override
  DashboardUiState build() {
    state = DashboardUiState.initial();
    // On cold start, auth may not be ready; wait for a user before loading.
    ref.listen(
      authStateChangesProvider,
      (previous, next) {
        final user = next.asData?.value;
        if (user == null) {
          state = DashboardUiState.initial();
          return;
        }
        _load();
      },
      fireImmediately: true,
    );
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
    if (HiveBoxes.hasStorageIssue) {
      state = state.copyWith(
        isLoading: false,
        screenError: HiveBoxes.storageErrorMessage,
        uiMessage: null,
      );
      _stopTicker();
      return;
    }
    final userId = _userIdOrNull;
    if (userId == null) {
      state = state.copyWith(isLoading: true, screenError: null);
      return;
    }
    try {
      state = state.copyWith(isLoading: true, screenError: null);
      final now = _clock.now();
      final meta = await _resolveMeta();
      _metaTargets = meta;
      final metaLabel = _formatMetaLabel(meta);

      final todayKey = dateKeyFromDate(now);
      final todayMeals = await _mealsRepository.listMealsForDay(
        userId,
        todayKey,
      );
      final todayCalories = _sumCalories(todayMeals);
      final activeSession =
          await _fastingRepository.getActiveSession(userId);
      final todayFastingTotal = await _fastingDurationForDay(
        now,
        activeSession: activeSession,
      );
      final todayFastingDisplay = _displayFastingDuration(
        now,
        activeSession: activeSession,
        dailyTotal: todayFastingTotal,
      );


      final isOnTrack =
          todayCalories <= meta.metaCalories &&
          todayFastingTotal >= meta.metaFasting;

      final weekly = await _weeklyCalories(now);
      final recentFasting = await _recentFastingSeries(
        now,
        activeSession: activeSession,
      );

      state = state.copyWith(
        isLoading: false,
        todayCaloriesValue: todayCalories,
        todayFastingValue: todayFastingDisplay,
        todayCaloriesLabel: '$todayCalories kcal',
        todayFastingLabel:
            DashboardUiState.formatDuration(todayFastingDisplay),
        statusLabel: isOnTrack
            ? DashboardStrings.statusOnTrack
            : DashboardStrings.statusOffTrack,
        metaLabel: metaLabel,
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
      final now = _clock.now();
      final meta = _metaTargets ?? await _resolveMeta();
      _metaTargets ??= meta;
      final metaLabel = _formatMetaLabel(meta);

      final active = await _findRunningSession();
      if (active == null) {
        final dailyTotal =
            await _fastingDurationForDay(now, activeSession: null);
        final isOnTrack =
            state.todayCaloriesValue <= meta.metaCalories &&
                dailyTotal >= meta.metaFasting;
        state = state.copyWith(
          todayFastingValue: dailyTotal,
          todayFastingLabel:
              DashboardUiState.formatDuration(dailyTotal),
          statusLabel: isOnTrack
              ? DashboardStrings.statusOnTrack
              : DashboardStrings.statusOffTrack,
          metaLabel: metaLabel,
          isOnTrack: isOnTrack,
        );
        _stopTicker();
        return;
      }

      final todayFastingTotal = await _fastingDurationForDay(
        now,
        activeSession: active,
      );
      final todayFastingDisplay = _displayFastingDuration(
        now,
        activeSession: active,
        dailyTotal: todayFastingTotal,
      );
      final isOnTrack =
          state.todayCaloriesValue <= meta.metaCalories &&
          todayFastingTotal >= meta.metaFasting;

      final recentFasting = await _recentFastingSeries(
        now,
        activeSession: active,
      );

      state = state.copyWith(
        todayFastingValue: todayFastingDisplay,
        todayFastingLabel:
            DashboardUiState.formatDuration(todayFastingDisplay),
        statusLabel: isOnTrack
            ? DashboardStrings.statusOnTrack
            : DashboardStrings.statusOffTrack,
        metaLabel: metaLabel,
        isOnTrack: isOnTrack,
        recentFastingData: recentFasting,
      );
    } finally {
      _isRefreshing = false;
    }
  }

  Future<_MetaTargets> _resolveMeta() async {
    final userId = _userIdOrNull;
    if (userId == null) {
      return _MetaTargets(
        metaCalories: 2000,
        metaFasting: const Duration(hours: 16),
      );
    }
    final protocol = await _fastingRepository.getSelectedProtocol(
      userId,
    );
    final metaFasting =
        protocol?.fastingDuration ?? const Duration(hours: 16);
    return _MetaTargets(metaCalories: 2000, metaFasting: metaFasting);
  }

  Future<List<WeeklyChartItem>> _weeklyCalories(DateTime now) async {
    final userId = _userIdOrNull;
    if (userId == null) return const [];
    final meals = await _mealsRepository.listMealsForUser(userId);
    return WeeklyChartService.buildCaloriesSeries(now: now, meals: meals);
  }

  Future<FastingSession?> _findRunningSession() async {
    final userId = _userIdOrNull;
    if (userId == null) return null;
    final sessions =
        await _fastingRepository.listSessionsForUser(userId);
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
    final userId = _userIdOrNull;
    if (userId == null) return const [];
    final sessions = await _fastingRepository.listSessionsForUser(userId);
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
            final hours = duration.inSeconds / 3600.0;
            return WeeklyChartItem(
              date: session.startAt,
              label: DateFormat('dd/MM').format(session.startAt),
              value: hours,
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
    final userId = _userIdOrNull;
    if (userId == null) return Duration.zero;
    final sessions = await _fastingRepository.listSessionsForUser(
      userId,
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

  Duration _displayFastingDuration(
    DateTime now, {
    required FastingSession? activeSession,
    required Duration dailyTotal,
  }) {
    if (activeSession != null &&
        activeSession.status == FastingSessionStatus.running) {
      return activeSession.elapsed(now);
    }
    return dailyTotal;
  }

  String _formatMetaLabel(_MetaTargets meta) {
    final calories = '${meta.metaCalories} kcal';
    final fasting = _formatMetaFasting(meta.metaFasting);
    return '${DashboardStrings.metaLabelPrefix}: $calories • $fasting';
  }

  String _formatMetaFasting(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
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
