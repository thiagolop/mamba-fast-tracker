import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/fasting_controller.dart';
import '../fasting_strings.dart';
import '../widgets/widgets.dart';

class FastingPage extends ConsumerStatefulWidget {
  const FastingPage({super.key});

  @override
  ConsumerState<FastingPage> createState() => _FastingPageState();
}

class _FastingPageState extends ConsumerState<FastingPage> {
  final GlobalKey _protocolSectionKey = GlobalKey();

  Future<void> _scrollToProtocol() async {
    final context = _protocolSectionKey.currentContext;
    if (context == null) {
      return;
    }
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fastingControllerProvider);
    final controller = ref.read(fastingControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(FastingStrings.title),
        leading: IconButton(
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.home_outlined),
          tooltip: FastingStrings.goHome,
        ),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        StatusChip(label: state.statusLabel),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.protocolLabel,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TimerText(text: state.elapsedLabel),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MetricText(
                          label: FastingStrings.elapsedLabel,
                          value: state.elapsedLabel,
                        ),
                        MetricText(
                          label: FastingStrings.remainingLabel,
                          value: state.remainingLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ProgressRing(progress: state.progress),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/meals'),
                icon: const Icon(Icons.restaurant_outlined),
                label: const Text(FastingStrings.addMeal),
              ),
              const SizedBox(height: 16),
              if (state.screenError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.screenError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SectionCard(
                key: _protocolSectionKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      FastingStrings.protocolTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey(state.selectedProtocol?.id),
                      initialValue: state.selectedProtocol?.id,
                      items: state.protocols
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: state.canChangeProtocol
                          ? (value) {
                              if (value != null) {
                                controller.selectProtocol(value);
                              }
                            }
                          : null,
                      decoration: InputDecoration(
                        labelText: FastingStrings.protocolSelectLabel,
                        helperText: state.protocolHelperText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (state.isActive) {
                          await controller.stopSession();
                        } else {
                          await controller.startSession();
                        }
                      },
                style: state.primaryButtonIsDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.errorContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onErrorContainer,
                      )
                    : null,
                child: Text(state.primaryButtonLabel),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed:
                    state.canChangeProtocol ? _scrollToProtocol : null,
                child: const Text(FastingStrings.changeProtocol),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
