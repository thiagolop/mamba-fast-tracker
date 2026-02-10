import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/meals_controller.dart';
import '../meals_strings.dart';
import '../widgets/widgets.dart';

class MealsPage extends ConsumerWidget {
  const MealsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealsControllerProvider);
    final controller = ref.read(mealsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(MealsStrings.title),
        leading: IconButton(
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.home_outlined),
          tooltip: MealsStrings.goHome,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isSaving
            ? null
            : () => context.push('/meals/form'),
        label: const Text(MealsStrings.addMeal),
        icon: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MealsStrings.todayTotal,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.totalCaloriesLabel,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Text(
                        state.dateLabel,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (state.screenError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.screenError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.items.isEmpty
                        ? Center(
                            child: Text(
                              MealsStrings.emptyList,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.separated(
                            itemCount: state.items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = state.items[index];
                              return MealListTile(
                                title: item.name,
                                subtitle: item.timeLabel,
                                trailing: item.caloriesLabel,
                                onTap: () => context.push(
                                  '/meals/form/${item.id}',
                                ),
                                onDelete: () =>
                                    controller.deleteMeal(item.id),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
