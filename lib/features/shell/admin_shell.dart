import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme.dart';

@immutable
class _NavItem {
  const _NavItem(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

const _items = [
  _NavItem('Dashboard', Icons.space_dashboard_rounded, Routes.dashboard),
  _NavItem('Orders', Icons.receipt_long_rounded, Routes.orders),
  _NavItem('Products', Icons.inventory_2_rounded, Routes.products),
  _NavItem('Categories', Icons.category_rounded, Routes.categories),
  _NavItem('Customers', Icons.people_alt_rounded, Routes.customers),
  _NavItem('Riders', Icons.delivery_dining_rounded, Routes.riders),
  _NavItem('Reports', Icons.bar_chart_rounded, Routes.reports),
  _NavItem('Storefront', Icons.storefront_rounded, Routes.storefront),
  _NavItem('Service areas', Icons.location_on_rounded, Routes.areas),
];

/// Sidebar on wide screens, drawer on narrow ones.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final sidebar = _Sidebar(location: location, inDrawer: !wide);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            sidebar,
            Expanded(child: child),
          ],
        ),
      );
    }
    final current = _items.firstWhere(
      (i) => i.path == location,
      orElse: () => _items.first,
    );
    return Scaffold(
      appBar: AppBar(title: Text(current.label)),
      drawer: Drawer(child: sidebar),
      body: child,
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location, required this.inDrawer});

  final String location;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email =
        ref.watch(authStateProvider).valueOrNull ??
        ref.watch(authRepositoryProvider).currentEmail ??
        '';

    return Container(
      width: 248,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 24, 22, 4),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                  children: [
                    TextSpan(text: 'mart'),
                    TextSpan(
                      text: '2',
                      style: TextStyle(color: AppColors.accent),
                    ),
                    TextSpan(text: 'door'),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Admin console',
                style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            // Scrolls on short windows instead of overflowing.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  for (final item in _items)
                    _NavTile(
                      item: item,
                      selected: item.path == location,
                      onTap: () {
                        if (inDrawer) Navigator.of(context).pop();
                        context.go(item.path);
                      },
                    ),
                ],
              ),
            ),
            const Divider(color: Color(0x33FFFFFF), indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xE6FFFFFF),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('sign-out-button'),
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('nav-${item.path}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? AppColors.primary : Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? AppColors.primaryDark : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
