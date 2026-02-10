import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/time/date_key.dart';
import '../../../../core/ui/ui_message.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/meals_repository.dart';
import '../../domain/meal.dart';
import '../meals_strings.dart';

class MealUiItem extends Equatable {
  const MealUiItem({
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

class MealsUiState extends Equatable {
  const MealsUiState({
    required this.isLoading,
    required this.isSaving,
    required this.dateKey,
    required this.dateLabel,
    required this.totalCalories,
    required this.totalCaloriesLabel,
    required this.items,
    this.formNameError,
    this.formCaloriesError,
    this.screenError,
    this.uiMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final String dateKey;
  final String dateLabel;
  final int totalCalories;
  final String totalCaloriesLabel;
  final List<MealUiItem> items;
  final String? formNameError;
  final String? formCaloriesError;
  final String? screenError;
  final UiMessage? uiMessage;

  factory MealsUiState.initial() {
    return MealsUiState(
      isLoading: true,
      isSaving: false,
      dateKey: '',
      dateLabel: '',
      totalCalories: 0,
      totalCaloriesLabel: '0 kcal',
      items: const [],
    );
  }

  MealsUiState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? dateKey,
    String? dateLabel,
    int? totalCalories,
    String? totalCaloriesLabel,
    List<MealUiItem>? items,
    String? formNameError,
    String? formCaloriesError,
    String? screenError,
    UiMessage? uiMessage,
  }) {
    return MealsUiState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      dateKey: dateKey ?? this.dateKey,
      dateLabel: dateLabel ?? this.dateLabel,
      totalCalories: totalCalories ?? this.totalCalories,
      totalCaloriesLabel: totalCaloriesLabel ?? this.totalCaloriesLabel,
      items: items ?? this.items,
      formNameError: formNameError,
      formCaloriesError: formCaloriesError,
      screenError: screenError,
      uiMessage: uiMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        dateKey,
        dateLabel,
        totalCalories,
        totalCaloriesLabel,
        items,
        formNameError,
        formCaloriesError,
        screenError,
        uiMessage,
      ];
}

final currentMealsUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) throw StateError('Usuário não autenticado');
  return user.uid;
});

class MealsController extends Notifier<MealsUiState> {
  MealsRepository get _repository => ref.read(mealsRepositoryProvider);
  Clock get _clock => ref.read(clockProvider);
  String get _userId => ref.read(currentMealsUserIdProvider);

  @override
  MealsUiState build() {
    state = MealsUiState.initial();
    Future.microtask(_loadToday);
    ref.listen(mealsChangesProvider, (_, __) {
      _loadForDate(DateTime.now());
    });
    return state;
  }

  Future<void> loadMealsForDay(DateTime date) async {
    await _loadForDate(date);
  }

  Future<void> _loadToday() async {
    await _loadForDate(_clock.now());
  }

  Future<void> _loadForDate(DateTime date) async {
    try {
      state = state.copyWith(isLoading: true, screenError: null);

      final dateKey = dateKeyFromDate(date);
      final items = await _repository.listMealsForDay(_userId, dateKey);
      final totalCalories = items.fold<int>(
        0,
        (total, item) => total + item.calories,
      );

      state = state.copyWith(
        isLoading: false,
        dateKey: dateKey,
        dateLabel: _formatDate(date),
        totalCalories: totalCalories,
        totalCaloriesLabel: '${totalCalories} kcal',
        items: items.map(_mapMeal).toList(),
        screenError: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        screenError: MealsStrings.errorLoad,
      );
    }
  }

  Future<bool> addMeal({
    required String name,
    required String caloriesText,
  }) async {
    final calories = int.tryParse(caloriesText.trim());
    final validationOk = _validateForm(name, calories);
    if (!validationOk) return false;

    state = state.copyWith(isSaving: true, uiMessage: null);
    try {
      await _repository.addMeal(
        userId: _userId,
        name: name.trim(),
        calories: calories!,
        createdAt: _clock.now(),
      );
      await _loadForDate(_clock.now());
      state = state.copyWith(
        isSaving: false,
        uiMessage: null,
        formNameError: null,
        formCaloriesError: null,
        screenError: null,
      );
      return true;
    } catch (_) {
      _emitError(MealsStrings.errorSave);
      return false;
    }
  }

  Future<bool> updateMeal({
    required String mealId,
    required String name,
    required String caloriesText,
  }) async {
    final calories = int.tryParse(caloriesText.trim());
    final validationOk = _validateForm(name, calories);
    if (!validationOk) return false;

    state = state.copyWith(isSaving: true, uiMessage: null);
    try {
      await _repository.updateMeal(
        userId: _userId,
        mealId: mealId,
        name: name.trim(),
        calories: calories!,
      );
      await _loadForDate(_clock.now());
      state = state.copyWith(
        isSaving: false,
        uiMessage: null,
        formNameError: null,
        formCaloriesError: null,
        screenError: null,
      );
      return true;
    } catch (_) {
      _emitError(MealsStrings.errorSave);
      return false;
    }
  }

  Future<void> deleteMeal(String mealId) async {
    try {
      await _repository.deleteMeal(_userId, mealId);
      await _loadForDate(_clock.now());
    } catch (_) {
      _emitError(MealsStrings.errorDelete);
    }
  }

  Future<Meal?> getMealById(String mealId) async {
    return _repository.getMeal(_userId, mealId);
  }

  void resetFormErrors() {
    state = state.copyWith(
      formNameError: null,
      formCaloriesError: null,
      uiMessage: null,
    );
  }

  void consumeMessage() {
    state = state.copyWith(uiMessage: null);
  }

  bool _validateForm(String name, int? calories) {
    final trimmed = name.trim();
    String? nameError;
    String? caloriesError;

    if (trimmed.isEmpty) {
      nameError = MealsStrings.validationName;
    }

    if (calories == null || calories <= 0) {
      caloriesError = MealsStrings.validationCalories;
    }

    state = state.copyWith(
      formNameError: nameError,
      formCaloriesError: caloriesError,
    );

    return nameError == null && caloriesError == null;
  }

  MealUiItem _mapMeal(Meal meal) {
    return MealUiItem(
      id: meal.id,
      name: meal.name,
      caloriesLabel: '${meal.calories} kcal',
      timeLabel: DateFormat.Hm().format(meal.createdAt),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM, yyyy').format(date);
  }

  void _emitError(String message) {
    state = state.copyWith(
      isSaving: false,
      uiMessage: UiMessage(type: UiMessageType.error, text: message),
    );
  }
}

final mealsControllerProvider =
    NotifierProvider<MealsController, MealsUiState>(MealsController.new);
