import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meals_repository.dart';
import '../domain/meal_entry.dart';

class MealsState extends Equatable {
  const MealsState({
    required this.items,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<MealEntry> items;
  final bool isLoading;
  final String? errorMessage;

  factory MealsState.initial() => const MealsState(items: []);

  MealsState copyWith({
    List<MealEntry>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MealsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [items, isLoading, errorMessage];
}

class MealsController extends Notifier<MealsState> {
  @override
  MealsState build() {
    // Carrega imediatamente (sem async)
    final repo = ref.read(mealsRepositoryProvider);
    final items = repo.getAll();
    return MealsState(items: items);
  }

  MealsRepository get _repo => ref.read(mealsRepositoryProvider);

  void reload() {
    final items = _repo.getAll();
    state = state.copyWith(
      items: items,
      isLoading: false,
      errorMessage: null,
    );
  }
}

final mealsControllerProvider =
    NotifierProvider<MealsController, MealsState>(
      MealsController.new,
    );
