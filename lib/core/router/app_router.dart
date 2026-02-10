import 'package:desafio_maba/core/router/go_router_refresh_stream.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/fasting/presentation/pages/fasting_page.dart';
import '../../features/meals/presentation/pages/meals_page.dart';
import '../../features/meals/presentation/pages/meal_form_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/history/presentation/pages/day_detail_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(firebaseAuthProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      final isLoggedIn = auth.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRoot = state.matchedLocation == '/';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && (isLoggingIn || isRoot)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/fasting',
        builder: (context, state) => const FastingPage(),
      ),
      GoRoute(
        path: '/meals',
        builder: (context, state) => const MealsPage(),
      ),
      GoRoute(
        path: '/meals/form',
        builder: (context, state) => const MealFormPage(),
      ),
      GoRoute(
        path: '/meals/form/:mealId',
        builder: (context, state) => MealFormPage(
          mealId: state.pathParameters['mealId'],
        ),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/history/:dateKey',
        builder: (context, state) => DayDetailPage(
          dateKey: state.pathParameters['dateKey'] ?? '',
        ),
      ),
    ],
  );
});
