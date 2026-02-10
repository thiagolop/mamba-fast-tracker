import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/fasting_protocol.dart';
import '../domain/fasting_status.dart';
import 'fasting_controller.dart';

class FastingPage extends ConsumerStatefulWidget {
  const FastingPage({super.key});

  @override
  ConsumerState<FastingPage> createState() => _FastingPageState();
}

class _FastingPageState extends ConsumerState<FastingPage> {
  final GlobalKey _protocolSectionKey = GlobalKey();

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _statusLabel(FastingState state) {
    switch (state) {
      case FastingState.inactive:
        return 'Inativo';
      case FastingState.fasting:
        return 'Jejuando';
      case FastingState.feeding:
        return 'Alimentação';
      case FastingState.completed:
        return 'Concluído';
    }
  }

  String _protocolLabel(FastingProtocol? protocol) {
    if (protocol == null) {
      return 'Selecione um protocolo';
    }
    return '${protocol.name} • ${protocol.fastingMinutes ~/ 60}h';
  }

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

    final protocol = state.selectedProtocol;
    final total = protocol?.fastingDuration ?? Duration.zero;
    final elapsed = state.status.elapsed;
    final remaining = state.status.remaining;

    final totalSeconds = total.inSeconds;
    final progress = totalSeconds == 0
        ? 0.0
        : (elapsed.inSeconds / totalSeconds).clamp(0.0, 1.0);

    final isActive = state.status.isActive;
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jejum'),
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
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _StatusChip(label: _statusLabel(state.status.state)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _protocolLabel(protocol),
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
                      child: _TimerText(
                        text: _formatDuration(elapsed),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MetricText(
                          label: 'Decorrido',
                          value: _formatDuration(elapsed),
                        ),
                        _MetricText(
                          label: 'Restante',
                          value: _formatDuration(remaining),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: _ProgressRing(progress: progress),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (state.errorMessage != null)
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
                          state.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              _SectionCard(
                key: _protocolSectionKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Protocolo',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: protocol?.id,
                      items: state.protocols
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: isLoading || isActive
                          ? null
                          : (value) {
                              if (value != null) {
                                controller.selectProtocol(value);
                              }
                            },
                      decoration: const InputDecoration(
                        labelText: 'Selecionar protocolo',
                        helperText: 'Finalize o jejum para trocar o protocolo.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (isActive) {
                          await controller.stopSession();
                        } else {
                          await controller.startSession();
                        }
                      },
                style: isActive
                    ? FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.errorContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onErrorContainer,
                      )
                    : null,
                child: Text(isActive ? 'Encerrar jejum' : 'Iniciar jejum'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: isLoading || isActive ? null : _scrollToProtocol,
                child: const Text('Trocar protocolo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TimerText extends StatelessWidget {
  const _TimerText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return SizedBox(
      height: 140,
      width: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 10,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'do jejum',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
