import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/history_controller.dart';
import '../history_strings.dart';

class DayDetailPage extends ConsumerStatefulWidget {
  const DayDetailPage({super.key, required this.dateKey});

  final String dateKey;

  @override
  ConsumerState<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends ConsumerState<DayDetailPage> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    await ref
        .read(historyControllerProvider.notifier)
        .loadDay(widget.dateKey);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final summary = state.selectedDay;

    return Scaffold(
      appBar: AppBar(
        title: const Text(HistoryStrings.dayDetailsTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : summary == null
              ? Center(
                  child: Text(
                    state.screenError ?? HistoryStrings.errorDay,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.screenError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          state.screenError!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.dateLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${HistoryStrings.caloriesLabel}: ${summary.caloriesLabel}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${HistoryStrings.fastingLabel}: ${summary.fastingLabel}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              summary.statusLabel,
                              style: TextStyle(
                                color: summary.isOnTrack
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      HistoryStrings.mealsTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: state.selectedMeals.isEmpty
                              ? Center(
                                  child: Text(
                                    HistoryStrings.emptyList,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            )
                              : ListView.separated(
                                  itemCount: state.selectedMeals.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                final meal =
                                    state.selectedMeals[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(meal.name),
                                    subtitle: Text(meal.timeLabel),
                                    trailing: Text(
                                      meal.caloriesLabel,
                                    ),
                                  ),
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
