import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/fasting_status.dart';
import 'fasting_controller.dart';

class FastingPage extends ConsumerWidget {
  const FastingPage({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fastingControllerProvider);
    final controller = ref.read(fastingControllerProvider.notifier);

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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: state.selectedProtocol?.id,
              items: state.protocols
                  .map(
                    (protocol) => DropdownMenuItem(
                      value: protocol.id,
                      child: Text(protocol.name),
                    ),
                  )
                  .toList(),
              onChanged: state.isLoading || state.status.isActive
                  ? null
                  : (value) {
                      if (value != null) {
                        controller.selectProtocol(value);
                      }
                    },
              decoration: const InputDecoration(
                labelText: 'Protocolo',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Status: ${_statusLabel(state.status.state)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tempo decorrido: ${_formatDuration(state.status.elapsed)}',
            ),
            Text(
              'Tempo restante: ${_formatDuration(state.status.remaining)}',
            ),
            const SizedBox(height: 24),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (state.status.isActive) {
                    await controller.stopSession();
                  } else {
                    await controller.startSession();
                  }
                },
                child: Text(
                  state.status.isActive
                      ? 'Encerrar jejum'
                      : 'Iniciar jejum',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
