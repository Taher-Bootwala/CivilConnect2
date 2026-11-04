import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../features/account/account_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/bookings/bookings_screen.dart';
import '../features/customer/customer_home_screen.dart';
import '../features/customer/service_catalog_screen.dart';
import '../features/professional/professional_earnings_screen.dart';
import '../features/professional/professional_jobs_screen.dart';
import '../features/professional/professional_home_screen.dart';
import '../features/shared/booking_detail_screen.dart';
import 'providers.dart';
import 'theme.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<UserProfile?>(authProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>(
  (ref) {
    final notifier = ref.watch(routerNotifierProvider);
    return GoRouter(
      refreshListenable: notifier,
      initialLocation: '/auth',
      redirect: (context, state) {
        final user = ref.read(authProvider);
        final isAuthRoute = state.uri.path == '/auth';

        // Compulsory registration/login: all unauthenticated requests are redirected to /auth
        if (user == null) {
          return isAuthRoute ? null : '/auth';
        }

        // Once authenticated, prevent remaining on or accessing /auth
        if (isAuthRoute) {
          return user.role == AppRole.professional ? '/pro/jobs' : '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/auth',
          builder: (context, state) => const AuthScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const CustomerHomeScreen(),
            ),
            GoRoute(
              path: '/services',
              builder: (context, state) => const ServiceCatalogScreen(),
            ),
            GoRoute(
              path: '/bookings',
              builder: (context, state) => const BookingsScreen(),
            ),
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountScreen(),
            ),
            GoRoute(
              path: '/booking/:id',
              builder: (context, state) =>
                  BookingDetailScreen(bookingId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/pro/jobs',
              builder: (context, state) => const ProfessionalJobsScreen(),
            ),
            GoRoute(
              path: '/pro/earnings',
              builder: (context, state) => const ProfessionalEarningsScreen(),
            ),
            GoRoute(
              path: '/pro/home',
              builder: (context, state) => const ProfessionalHomeScreen(),
            ),
          ],
        ),
      ],
    );
  },
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'CivilConnect',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    routerConfig: ref.watch(routerProvider),
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final path = GoRouterState.of(context).uri.path;
    final isProfessional = role == AppRole.professional;
    final destinations = isProfessional
        ? const [
            NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'Jobs',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Earnings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ];
    final selectedIndex = isProfessional
        ? path.startsWith('/pro/earnings')
              ? 1
              : path == '/account'
              ? 2
              : 0
        : path == '/bookings'
        ? 1
        : path == '/account'
        ? 2
        : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: destinations,
        onDestinationSelected: (index) {
          if (isProfessional) {
            context.go(
              index == 0
                  ? '/pro/jobs'
                  : index == 1
                  ? '/pro/earnings'
                  : '/account',
            );
          } else {
            context.go(
              index == 0
                  ? '/home'
                  : index == 1
                  ? '/bookings'
                  : '/account',
            );
          }
        },
      ),
    );
  }
}
