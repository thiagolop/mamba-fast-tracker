import 'package:desafio_maba/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/ui/snackbar_helper.dart';
import 'core/ui/ui_message.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'features/fasting/presentation/controllers/fasting_controller.dart';
import 'features/history/presentation/controllers/history_controller.dart';
import 'features/meals/presentation/controllers/meals_controller.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Mamba Fast Tracker',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return _AppMessageListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _AppMessageListener extends ConsumerWidget {
  const _AppMessageListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn =
        ref.watch(firebaseAuthProvider).currentUser != null;

    ref.listen<UiMessage?>(
      authControllerProvider.select((state) => state.uiMessage),
      (previous, next) {
        if (next == null) return;
        _showMessage(context, next);
        ref.read(authControllerProvider.notifier).consumeMessage();
      },
    );

    if (isLoggedIn) {
      ref.listen<UiMessage?>(
        fastingControllerProvider.select((state) => state.uiMessage),
        (previous, next) {
          if (next == null) return;
          _showMessage(context, next);
          ref
              .read(fastingControllerProvider.notifier)
              .consumeMessage();
        },
      );

      ref.listen<UiMessage?>(
        mealsControllerProvider.select((state) => state.uiMessage),
        (previous, next) {
          if (next == null) return;
          _showMessage(context, next);
          ref.read(mealsControllerProvider.notifier).consumeMessage();
        },
      );

      ref.listen<UiMessage?>(
        historyControllerProvider.select((state) => state.uiMessage),
        (previous, next) {
          if (next == null) return;
          _showMessage(context, next);
          ref
              .read(historyControllerProvider.notifier)
              .consumeMessage();
        },
      );

      ref.listen<UiMessage?>(
        dashboardControllerProvider.select(
          (state) => state.uiMessage,
        ),
        (previous, next) {
          if (next == null) return;
          _showMessage(context, next);
          ref
              .read(dashboardControllerProvider.notifier)
              .consumeMessage();
        },
      );
    }

    return child;
  }

  void _showMessage(BuildContext context, UiMessage message) {
    showAppSnack(
      context,
      message.text,
      isError: message.type == UiMessageType.error,
    );
  }
}
