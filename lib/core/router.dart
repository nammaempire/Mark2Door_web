import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/areas/service_areas_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/content/content_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/products/products_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/coupons/coupons_screen.dart';
import '../features/riders/riders_screen.dart';
import '../features/shell/admin_shell.dart';
import '../features/storefront/storefront_screen.dart';
import 'providers.dart';

abstract final class Routes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const products = '/products';
  static const orders = '/orders';
  static const areas = '/areas';
  static const categories = '/categories';
  static const customers = '/customers';
  static const riders = '/riders';
  static const coupons = '/coupons';
  static const reports = '/reports';
  static const storefront = '/storefront';
  static const content = '/content';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref
    ..listen(authStateProvider, (_, __) => refresh.notify())
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(authRepositoryProvider).currentEmail != null;
      final onLogin = state.matchedLocation == Routes.login;
      if (!signedIn) return onLogin ? null : Routes.login;
      return onLogin ? Routes.dashboard : null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.matchedLocation, child: child),
        routes: [
          for (final (path, page) in <(String, Widget)>[
            (Routes.dashboard, const DashboardScreen()),
            (Routes.products, const ProductsScreen()),
            (Routes.orders, const OrdersScreen()),
            (Routes.areas, const ServiceAreasScreen()),
            (Routes.categories, const CategoriesScreen()),
            (Routes.customers, const CustomersScreen()),
            (Routes.riders, const RidersScreen()),
            (Routes.coupons, const CouponsScreen()),
            (Routes.reports, const ReportsScreen()),
            (Routes.storefront, const StorefrontScreen()),
            (Routes.content, const ContentScreen()),
          ])
            GoRoute(
              path: path,
              // Section switches should feel instant, not slide like pages.
              pageBuilder: (context, state) => NoTransitionPage(child: page),
            ),
        ],
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
