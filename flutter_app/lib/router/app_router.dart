import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:nexiva/presentation/providers/auth_provider.dart";
import "package:nexiva/presentation/screens/analytics/analytics_screen.dart";
import "package:nexiva/presentation/screens/auth/login_screen.dart";
import "package:nexiva/presentation/screens/calendar/calendar_screen.dart";
import "package:nexiva/presentation/screens/home/home_shell_screen.dart";
import "package:nexiva/presentation/screens/ideas/ideas_screen.dart";
import "package:nexiva/presentation/screens/timeline/timeline_screen.dart";

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: "/timeline",
    redirect: (context, state) {
      final signedIn = authState.value != null;
      final inAuth = state.matchedLocation == "/login";

      if (!signedIn && !inAuth) {
        return "/login";
      }
      if (signedIn && inAuth) {
        return "/timeline";
      }
      return null;
    },
    routes: [
      GoRoute(path: "/login", builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: "/timeline", builder: (context, state) => const TimelineScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: "/ideas", builder: (context, state) => const IdeasScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: "/analytics", builder: (context, state) => const AnalyticsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: "/calendar", builder: (context, state) => const CalendarScreen()),
          ]),
        ],
      ),
    ],
  );
});
