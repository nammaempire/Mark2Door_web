import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/order.dart';
import '../orders/orders_screen.dart';
import 'revenue_stats.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(revenueStatsProvider);
    final orders = ref.watch(ordersProvider).valueOrNull ?? const <Order>[];

    return AdminPage(
      title: 'Dashboard',
      subtitle:
          'Revenue counts paid online orders and cash-on-delivery '
          'orders that were not cancelled.',
      children: [
        AsyncView(
          value: stats,
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatGrid(stats: s),
              const SizedBox(height: 20),
              _Responsive(
                children: [
                  Panel(
                    title: 'Daily revenue · last 7 days',
                    child: RevenueBarChart(points: s.daily),
                  ),
                  Panel(
                    title: 'Monthly revenue · last 6 months',
                    child: RevenueBarChart(
                      points: s.monthly,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Responsive(
                flex: const [3, 2],
                children: [
                  Panel(
                    title: 'Recent orders',
                    child: Column(
                      children: [
                        for (final o in orders.take(6))
                          _RecentOrderRow(order: o),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.go(Routes.orders),
                            child: const Text('View all orders'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Panel(
                    title: 'Top products this month',
                    child: s.topProducts.isEmpty
                        ? const Text(
                            'No sales yet this month.',
                            style: TextStyle(color: AppColors.textMuted),
                          )
                        : Column(
                            children: [
                              for (final (i, p) in s.topProducts.indexed)
                                _TopProductRow(
                                  rank: i + 1,
                                  product: p,
                                  maxPaise: s.topProducts.first.paise,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lays children side by side on wide screens and stacked on narrow ones.
class _Responsive extends StatelessWidget {
  const _Responsive({required this.children, this.flex});

  final List<Widget> children;
  final List<int>? flex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const SizedBox(height: 20),
                child,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(width: 20),
              Expanded(flex: flex?[i] ?? 1, child: child),
            ],
          ],
        );
      },
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final RevenueStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        label: "Today's revenue",
        value: formatPaise(stats.todayPaise),
        icon: Icons.today_rounded,
        colors: const [AppColors.primaryLight, AppColors.primaryDark],
        footnote: _change(stats.todayPaise, stats.yesterdayPaise, 'yesterday'),
      ),
      _StatCard(
        label: 'This month',
        value: formatPaise(stats.monthPaise),
        icon: Icons.calendar_month_rounded,
        colors: const [Color(0xFFE0607B), Color(0xFFA8243F)],
        footnote: 'Last month ${formatPaise(stats.lastMonthPaise)}',
      ),
      _StatCard(
        label: 'Orders today',
        value: '${stats.ordersToday}',
        icon: Icons.shopping_bag_rounded,
        colors: const [Color(0xFF8E2A5B), Color(0xFF55103A)],
        footnote: '${stats.activeOrders} still to deliver',
      ),
      _StatCard(
        label: 'Average order',
        value: formatPaise(stats.avgOrderPaise),
        icon: Icons.receipt_rounded,
        colors: const [Color(0xFFC2185B), Color(0xFF7A0F3A)],
        footnote: "Across this month's orders",
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  static String _change(int now, int before, String versus) {
    if (before == 0) return 'No sales $versus';
    final pct = ((now - before) * 100 / before).round();
    return '${pct >= 0 ? '+' : ''}$pct% vs $versus';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
    required this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withAlpha(60),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            footnote,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Dependency-free bar chart: value label, bar, axis label per point.
class RevenueBarChart extends StatelessWidget {
  const RevenueBarChart({
    super.key,
    required this.points,
    this.color = AppColors.primary,
  });

  final List<RevenuePoint> points;
  final Color color;

  static const double _barArea = 150;

  @override
  Widget build(BuildContext context) {
    final max = points.fold(0, (m, p) => p.paise > m ? p.paise : m);
    return SizedBox(
      height: _barArea + 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, p) in points.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _compact(p.paise),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Tooltip(
                      message: '${p.label}: ${formatPaise(p.paise)}',
                      child: Container(
                        height: max == 0
                            ? 4
                            : (4 + (_barArea - 4) * p.paise / max),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                            bottom: Radius.circular(3),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color,
                              // The latest period is solid; earlier ones fade.
                              color.withAlpha(
                                i == points.length - 1 ? 255 : 110,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == points.length - 1
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// ₹1.2L / ₹45.3k / ₹820 so labels fit above narrow bars.
  static String _compact(int paise) {
    final rupees = paise / 100;
    if (rupees >= 100000) return '₹${(rupees / 100000).toStringAsFixed(1)}L';
    if (rupees >= 1000) return '₹${(rupees / 1000).toStringAsFixed(1)}k';
    return '₹${rupees.round()}';
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.displayId} · ${order.address.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  formatOrderDate(order.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          StatusPill(order.status.label, orderStatusColor(order.status)),
          SizedBox(
            width: 84,
            child: Text(
              formatPaise(order.totalPaise),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({
    required this.rank,
    required this.product,
    required this.maxPaise,
  });

  final int rank;
  final TopProduct product;
  final int maxPaise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$rank.',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '${product.quantity} sold · ${formatPaise(product.paise)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxPaise == 0 ? 0 : product.paise / maxPaise,
              minHeight: 6,
              backgroundColor: AppColors.primarySoft,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
