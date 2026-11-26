import 'package:flutter/foundation.dart';

import '../../models/order.dart';
import '../reports/day_stats.dart';

@immutable
class RevenuePoint {
  const RevenuePoint({required this.label, required this.paise});

  final String label;
  final int paise;
}

@immutable
class TopProduct {
  const TopProduct({
    required this.name,
    required this.quantity,
    required this.paise,
  });

  final String name;
  final int quantity;
  final int paise;
}

/// Everything the dashboard shows, computed from the order list in one pass
/// so the numbers can never disagree with each other. Pure and unit tested.
@immutable
class RevenueStats {
  const RevenueStats({
    required this.todayPaise,
    required this.yesterdayPaise,
    required this.monthPaise,
    required this.lastMonthPaise,
    required this.ordersToday,
    required this.activeOrders,
    required this.avgOrderPaise,
    required this.daily,
    required this.monthly,
    required this.topProducts,
  });

  final int todayPaise;
  final int yesterdayPaise;
  final int monthPaise;
  final int lastMonthPaise;

  /// All orders placed today, whether or not they count as revenue.
  final int ordersToday;

  /// Orders still to be delivered.
  final int activeOrders;

  /// Average value of this month's revenue orders.
  final int avgOrderPaise;

  /// Last 7 days, oldest first.
  final List<RevenuePoint> daily;

  /// Last 6 months, oldest first.
  final List<RevenuePoint> monthly;

  /// Best sellers this month by revenue.
  final List<TopProduct> topProducts;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// From a list of orders: used by tests and by sample data. The live
  /// console uses [RevenueStats.fromDays], fed by the server's totals.
  factory RevenueStats.from(List<Order> orders, DateTime now) =>
      RevenueStats.fromDays(
        DayStats.fromOrders(orders),
        now,
        activeOrders: orders.where((o) => o.isActive).length,
      );

  /// From the day totals the server keeps, which cover every order ever
  /// placed. [activeOrders] comes from the live order list.
  factory RevenueStats.fromDays(
    List<DayStats> days,
    DateTime now, {
    required int activeOrders,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    // Calendar arithmetic (not Duration) so DST shifts cannot move a day.
    DateTime dayOffset(int n) =>
        DateTime(today.year, today.month, today.day + n);
    DateTime monthOffset(int months) =>
        DateTime(today.year, today.month + months);

    final dayStarts = [for (var i = -6; i <= 0; i++) dayOffset(i)];
    final monthStarts = [for (var i = -5; i <= 0; i++) monthOffset(i)];
    final dayTotals = List<int>.filled(7, 0);
    final monthTotals = List<int>.filled(6, 0);
    final productQty = <String, int>{};
    final productPaise = <String, int>{};

    var ordersToday = 0;
    final active = activeOrders;
    var monthOrders = 0;

    for (final d in days) {
      final month = DateTime(d.day.year, d.day.month);
      if (d.day == today) ordersToday += d.orders;

      final dayIndex = dayStarts.indexOf(d.day);
      if (dayIndex != -1) dayTotals[dayIndex] += d.revenuePaise;
      final monthIndex = monthStarts.indexOf(month);
      if (monthIndex != -1) monthTotals[monthIndex] += d.revenuePaise;

      if (month == monthStarts.last) {
        monthOrders += d.revenueOrders;
        d.items.forEach((name, sold) {
          productQty.update(
            name,
            (q) => q + sold.quantity,
            ifAbsent: () => sold.quantity,
          );
          productPaise.update(
            name,
            (p) => p + sold.paise,
            ifAbsent: () => sold.paise,
          );
        });
      }
    }

    final top =
        productPaise.keys
            .map(
              (name) => TopProduct(
                name: name,
                quantity: productQty[name]!,
                paise: productPaise[name]!,
              ),
            )
            .toList()
          ..sort((a, b) => b.paise.compareTo(a.paise));

    return RevenueStats(
      todayPaise: dayTotals[6],
      yesterdayPaise: dayTotals[5],
      monthPaise: monthTotals[5],
      lastMonthPaise: monthTotals[4],
      ordersToday: ordersToday,
      activeOrders: active,
      avgOrderPaise: monthOrders == 0 ? 0 : monthTotals[5] ~/ monthOrders,
      daily: [
        for (var i = 0; i < 7; i++)
          RevenuePoint(
            label: i == 6 ? 'Today' : _weekdays[dayStarts[i].weekday - 1],
            paise: dayTotals[i],
          ),
      ],
      monthly: [
        for (var i = 0; i < 6; i++)
          RevenuePoint(
            label: _months[monthStarts[i].month - 1],
            paise: monthTotals[i],
          ),
      ],
      topProducts: top.take(5).toList(growable: false),
    );
  }
}
