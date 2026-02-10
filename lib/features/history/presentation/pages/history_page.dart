import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/history_controller.dart';
import '../history_strings.dart';
import '../widgets/widgets.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(HistoryStrings.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
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
                    : state.days.isEmpty
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
                        itemCount: state.days.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = state.days[index];
                          return DaySummaryTile(
                            dateLabel: item.dateLabel,
                            caloriesLabel: item.caloriesLabel,
                            fastingLabel: item.fastingLabel,
                            statusLabel: item.statusLabel,
                            isOnTrack: item.isOnTrack,
                            onTap: () => context.push(
                              '/history/${item.dateKey}',
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
