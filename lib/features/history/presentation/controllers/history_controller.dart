import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/date_key.dart';
import '../../../../core/ui/ui_message.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../fasting/data/fasting_repository.dart';
import '../../../meals/data/meals_repository.dart';
import '../../../meals/domain/meal.dart';
import '../../data/history_repository.dart';
import '../../domain/daily_summary.dart';
import '../history_strings.dart';

class DailySummaryUi extends Equatable {
  const DailySummaryUi({
    required this.dateKey,
    required this.dateLabel,
    required this.caloriesLabel,
    required this.fastingLabel,
    required this.statusLabel,
    required this.isOnTrack,
  });

  final String dateKey;
  final String dateLabel;
  final String caloriesLabel;
  final String fastingLabel;
  final String statusLabel;
  final bool isOnTrack;

  @override
  List<Object?> get props => [
    dateKey,
    dateLabel,
    caloriesLabel,
    fastingLabel,
    statusLabel,
    isOnTrack,
  ];
}

class DayMealItem extends Equatable {
  const DayMealItem({
    required this.id,
    required this.name,
    required this.caloriesLabel,
    required this.timeLabel,
  });

  final String id;
  final String name;
  final String caloriesLabel;
  final String timeLabel;

  @override
  List<Object?> get props => [id, name, caloriesLabel, timeLabel];
}

class HistoryUiState extends Equatable {
  const HistoryUiState({
    required this.isLoading,
    required this.days,
    required this.selectedMeals,
    this.selectedDay,
    this.screenError,
    this.uiMessage,
  });

  final bool isLoading;
  final List<DailySummaryUi> days;
  final DailySummaryUi? selectedDay;
  final List<DayMealItem> selectedMeals;
  final String? screenError;
  final UiMessage? uiMessage;

  factory HistoryUiState.initial() {
    return const HistoryUiState(
      isLoading: true,
      days: [],
      selectedMeals: [],
    );
  }

  HistoryUiState copyWith({
    bool? isLoading,
    List<DailySummaryUi>? days,
    DailySummaryUi? selectedDay,
    List<DayMealItem>? selectedMeals,
    String? screenError,
    UiMessage? uiMessage,
  }) {
    return HistoryUiState(
      isLoading: isLoading ?? this.isLoading,
      days: days ?? this.days,
      selectedDay: selectedDay ?? this.selectedDay,
      selectedMeals: selectedMeals ?? this.selectedMeals,
      screenError: screenError,
      uiMessage: uiMessage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    days,
    selectedDay,
    selectedMeals,
    screenError,
    uiMessage,
  ];
}

final historyUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) throw StateError('Usuário não autenticado');
  return user.uid;
});

class HistoryController extends Notifier<HistoryUiState> {
  HistoryRepository get _historyRepository => HistoryRepository(
    mealsRepository: ref.read(mealsRepositoryProvider),
    fastingRepository: ref.read(fastingRepositoryProvider),
  );
  FastingRepository get _fastingRepository =>
      ref.read(fastingRepositoryProvider);
  Clock get _clock => ref.read(clockProvider);
  String? get _userIdOrNull =>
      ref.read(firebaseAuthProvider).currentUser?.uid;

  @override
  HistoryUiState build() {
    state = HistoryUiState.initial();
    // On cold start, auth may not be ready; wait for a user before loading.
    ref.listen(authStateChangesProvider, (previous, next) {
      final user = next.asData?.value;
      if (user == null) {
        state = HistoryUiState.initial();
        return;
      }
      _load();
    }, fireImmediately: true);

    ref.listen(mealsChangesProvider, (previous, next) => _load());
    ref.listen(
      fastingSessionsChangesProvider,
      (previous, next) => _load(),
    );
    return state;
  }

  Future<void> refresh() async {
    await _load();
  }

  Future<void> loadDay(String dateKey) async {
    if (HiveBoxes.hasStorageIssue) {
      state = state.copyWith(
        isLoading: false,
        screenError: HiveBoxes.storageErrorMessage,
        uiMessage: null,
      );
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
      final date = dateFromKey(dateKey);

      final summary = await _historyRepository.buildSummaryForDay(
        userId: userId,
        date: date,
        now: now,
        metaCalories: meta.metaCalories,
        metaFasting: meta.metaFasting,
      );

      final meals = await _historyRepository.listMealsForDay(
        userId,
        dateKey,
      );

      state = state.copyWith(
        isLoading: false,
        selectedDay: _mapSummary(summary),
        selectedMeals: meals.map(_mapMeal).toList(),
        screenError: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        screenError: HistoryStrings.errorDay,
      );
    }
  }

  Future<void> openDay(String dateKey) async {
    await loadDay(dateKey);
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

      final summaries = await _historyRepository.listLastDays(
        userId: userId,
        now: now,
        days: 14,
        metaCalories: meta.metaCalories,
        metaFasting: meta.metaFasting,
      );

      state = state.copyWith(
        isLoading: false,
        days: summaries.map(_mapSummary).toList(),
        screenError: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        screenError: HistoryStrings.errorLoad,
      );
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

  DailySummaryUi _mapSummary(DailySummary summary) {
    return DailySummaryUi(
      dateKey: summary.dateKey,
      dateLabel: DateFormat('dd MMM, yyyy').format(summary.date),
      caloriesLabel: '${summary.caloriesTotal} kcal',
      fastingLabel: _formatDuration(summary.fastingTotal),
      statusLabel: summary.isOnTrack
          ? HistoryStrings.statusOnTrack
          : HistoryStrings.statusOffTrack,
      isOnTrack: summary.isOnTrack,
    );
  }

  DayMealItem _mapMeal(Meal meal) {
    return DayMealItem(
      id: meal.id,
      name: meal.name,
      caloriesLabel: '${meal.calories} kcal',
      timeLabel: DateFormat.Hm().format(meal.createdAt),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
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

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryUiState>(
      HistoryController.new,
    );
