import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/meals_controller.dart';
import '../meals_strings.dart';

class MealFormPage extends ConsumerStatefulWidget {
  const MealFormPage({super.key, this.mealId});

  final String? mealId;

  @override
  ConsumerState<MealFormPage> createState() => _MealFormPageState();
}

class _MealFormPageState extends ConsumerState<MealFormPage> {
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mealsControllerProvider.notifier).resetFormErrors();
      if (widget.mealId != null) {
        _loadMeal();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _loadMeal() async {
    if (_loaded) return;
    final mealId = widget.mealId;
    if (mealId == null) return;
    final meal = await ref.read(mealsControllerProvider.notifier).getMealById(
          mealId,
        );
    if (meal == null) return;

    setState(() {
      _nameController.text = meal.name;
      _caloriesController.text = meal.calories.toString();
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final controller = ref.read(mealsControllerProvider.notifier);
    final name = _nameController.text;
    final calories = _caloriesController.text;

    final ok = widget.mealId == null
        ? await controller.addMeal(name: name, caloriesText: calories)
        : await controller.updateMeal(
            mealId: widget.mealId!,
            name: name,
            caloriesText: calories,
          );

    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealsControllerProvider);
    final isEditing = widget.mealId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? MealsStrings.editMeal : MealsStrings.addMeal),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: MealsStrings.mealNameLabel,
                  hintText: MealsStrings.mealNameHint,
                  errorText: state.formNameError,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: MealsStrings.caloriesLabel,
                  hintText: MealsStrings.caloriesHint,
                  errorText: state.formCaloriesError,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: state.isSaving ? null : _save,
                child: state.isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(MealsStrings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
