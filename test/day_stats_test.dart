import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door_admin/features/customers/customer_stats.dart';
import 'package:mart2door_admin/features/dashboard/revenue_stats.dart';
import 'package:mart2door_admin/features/reports/day_stats.dart';
import 'package:mart2door_admin/features/reports/sales_report.dart';

void main() {
  // What the server writes for one day (functions/stats.js).
  final nov26 = DayStats.fromMap(const {
    'day': '2026-11-26',
    'storeId': 's1',
    'orders': 5,
    'revenueOrders': 3,
    'revenuePaise': 90000,
    'cancelledOrders': 1,
    'unpaidOrders': 1,
    'codPaise': 60000,
    'onlinePaise': 30000,
    'deliveryFeesPaise': 9000,
    'items': {
      'Apple': {'q': 6, 'p': 77400},
      'Milk (Offer)': {'q': 1, 'p': 900},
    },
  })!;
  final nov25OtherStore = DayStats.fromMap(const {
    'day': '2026-11-25',
    'storeId': 's2',
    'orders': 2,
    'revenueOrders': 2,
    'revenuePaise': 40000,
    'codPaise': 40000,
  })!;

  test('a server day record is read in full', () {
    expect(nov26.day, DateTime(2026, 11, 26));
    expect(nov26.storeId, 's1');
    expect(nov26.orders, 5);
    expect(nov26.revenuePaise, 90000);
    expect(nov26.items['Apple'], (quantity: 6, paise: 77400));
    expect(DayStats.fromMap(const {'day': 'soon'}), isNull);
    // A record with fields missing reads as zero, not as an error.
    expect(nov25OtherStore.cancelledOrders, 0);
    expect(nov25OtherStore.items, isEmpty);
  });

  test('the dashboard adds up day records, with no order list at all', () {
    final stats = RevenueStats.fromDays(
      [nov26, nov25OtherStore],
      DateTime(2026, 11, 26, 15),
      activeOrders: 4,
    );
    expect(stats.todayPaise, 90000);
    expect(stats.yesterdayPaise, 40000);
    expect(stats.monthPaise, 130000);
    expect(stats.ordersToday, 5);
    expect(stats.activeOrders, 4);
    // Five revenue orders this month.
    expect(stats.avgOrderPaise, 26000);
    expect(stats.topProducts.first.name, 'Apple');
    expect(stats.topProducts.first.quantity, 6);

    // One store only.
    final s1 = RevenueStats.fromDays(
      DayStats.forStore([nov26, nov25OtherStore], 's1'),
      DateTime(2026, 11, 26, 15),
      activeOrders: 0,
    );
    expect(s1.monthPaise, 90000);
    expect(s1.yesterdayPaise, 0);
  });

  test('a report counts every order even when its order list is cut short',
      () {
    final report = SalesReport.fromDays(
      [nov26, nov25OtherStore],
      DateTime(2026, 11, 25),
      DateTime(2026, 11, 26),
      orders: const [],
      ordersCapped: true,
    );
    expect(report.revenuePaise, 130000);
    expect(report.revenueOrders, 5);
    expect(report.cancelledOrders, 1);
    expect(report.unpaidOrders, 1);
    expect(report.codPaise, 100000);
    expect(report.onlinePaise, 30000);
    expect(report.deliveryFeesPaise, 9000);
    expect(report.days.map((d) => d.orders), [2, 3]);
    expect(report.ordersCapped, isTrue);
    // A day outside the period is left out.
    final oneDay = SalesReport.fromDays(
      [nov26, nov25OtherStore],
      DateTime(2026, 11, 26),
      DateTime(2026, 11, 26),
      orders: const [],
    );
    expect(oneDay.revenuePaise, 90000);
  });

  test('customer records from several stores are added together', () {
    final a = CustomerSummary.fromMap(const {
      'period': 'all',
      'storeId': 's1',
      'phone': '9876543210',
      'name': 'Asha',
      'pincode': '629001',
      'orders': 3,
      'spentPaise': 90000,
      'lastOrderAt': 1795600000000,
    });
    final b = CustomerSummary.fromMap(const {
      'period': 'all',
      'storeId': 's2',
      'phone': '9876543210',
      'name': 'Asha R',
      'pincode': '629002',
      'orders': 1,
      'spentPaise': 20000,
      'lastOrderAt': 1795700000000,
    });
    final other = CustomerSummary.fromMap(const {
      'phone': '9000000001',
      'name': 'Ravi',
      'orders': 5,
      'spentPaise': 250000,
      'lastOrderAt': 1795500000000,
    });
    expect(a.orderCount, 3);
    expect(a.spentPaise, 90000);
    final merged = CustomerSummary.merged([a, b, other]);
    // Biggest spender first; Asha's two stores are one row.
    expect(merged.map((c) => c.phone), ['9000000001', '9876543210']);
    expect(merged.last.orderCount, 4);
    expect(merged.last.spentPaise, 110000);
    // Name and pincode from her newest order.
    expect(merged.last.name, 'Asha R');
    expect(merged.last.pincode, '629002');
  });
}
