import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../presentation/providers/auth_provider.dart';

// We will implement these screens later, import stub or relativwhene
import '../../presentation/screens/auth/login_screen.dart';

import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/orders/orders_screen.dart';
import '../../presentation/screens/orders/create/select_items_screen.dart';
import '../../presentation/screens/orders/create/review_order_screen.dart';
import '../../presentation/screens/orders/create/collect_payment_screen.dart';
import '../../presentation/screens/orders/create/upi_payment_screen.dart';
import '../../presentation/screens/orders/create/bill_screen.dart';
import '../../presentation/screens/reports/day_summary_screen.dart';
import '../../presentation/widgets/layout/app_navigation.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
// final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/new',
    refreshListenable:
        GoRouterRefreshStream(ref.watch(authProvider.notifier).stream),
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.uri.path == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/new';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppBottomNavigation(navigationShell: navigationShell);
        },
        branches: [
          // New Order Branch (First Tab)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/new',
                builder: (context, state) => const SelectItemsScreen(),
                routes: [
                  GoRoute(
                    path: 'review',
                    builder: (context, state) => const ReviewOrderScreen(),
                    parentNavigatorKey: _rootNavigatorKey,
                    routes: [
                      GoRoute(
                        path: 'collect-payment',
                        builder: (context, state) {
                          final paymentMethod =
                              state.uri.queryParameters['method'] ?? 'cash';
                          return CollectPaymentScreen(
                            paymentMethod: paymentMethod,
                          );
                        },
                        parentNavigatorKey: _rootNavigatorKey,
                        routes: [
                          GoRoute(
                            path: 'upi',
                            builder: (context, state) {
                              final amount = double.tryParse(
                                      state.uri.queryParameters['amount'] ??
                                          '0') ??
                                  0.0;
                              final invoice =
                                  state.uri.queryParameters['invoice'];
                              return UpiPaymentScreen(
                                amount: amount,
                                invoiceNumber: invoice,
                              );
                            },
                            parentNavigatorKey: _rootNavigatorKey,
                          ),
                          GoRoute(
                            path: 'bill',
                            builder: (context, state) {
                              final paymentMethod =
                                  state.uri.queryParameters['method'] ?? 'cash';
                              final invoice =
                                  state.uri.queryParameters['invoice'];
                              final amount = double.tryParse(
                                  state.uri.queryParameters['amount'] ?? '');
                              final dateStr = state.uri.queryParameters['date'];
                              final date = dateStr != null
                                  ? DateTime.tryParse(dateStr)
                                  : null;

                              return BillScreen(
                                paymentMethod: paymentMethod,
                                invoiceNumber: invoice,
                                amount: amount,
                                date: date,
                              );
                            },
                            parentNavigatorKey: _rootNavigatorKey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Orders History Branch (Second Tab)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          // Settings Branch (Third Tab)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'day-summary',
                    builder: (context, state) => const DaySummaryScreen(),
                    parentNavigatorKey: _rootNavigatorKey,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// Helper to listen to stream
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
