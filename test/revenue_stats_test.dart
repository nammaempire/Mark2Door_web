import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door_admin/data/fake_repositories.dart';
import 'package:mart2door_admin/features/customers/customer_stats.dart';
import 'package:mart2door_admin/features/dashboard/revenue_stats.dart';
import 'package:mart2door_admin/features/products/product_form_dialog.dart';
import 'package:mart2door_admin/features/reports/sales_report.dart';
import 'package:mart2door_admin/models/order.dart';

Order _order(
  DateTime at,
  int totalPaise, {
  OrderStatus status = OrderStatus.delivered,
  PaymentMethod method = PaymentMethod.cod,
  PaymentStatus payment = PaymentStatus.pending,
  List<OrderItem> items = const [],
  String name = '',
  String phone = '',
  String? rider,
}) => Order(
  id: 'o${at.microsecondsSinceEpoch}$totalPaise',
  items: items,
  subtotalPaise: totalPaise,
  deliveryFeePaise: 0,
  totalPaise: totalPaise,
  address: Address(
    name: name,
    phone: phone,
    line1: '',
    landmark: '',
    pincode: '560034',
  ),
  paymentMethod: method,
  paymentStatus: payment,
  status: status,
  createdAt: at,
  riderName: rider,
);

void main() {
  final now = DateTime(2026, 11, 19, 14, 30); // a Thursday

  group('Order.countsAsRevenue', () {
    test('COD counts unless cancelled; online counts only when paid', () {
      expect(_order(now, 100).countsAsRevenue, isTrue);
      expect(
        _order(now, 100, status: OrderStatus.cancelled).countsAsRevenue,
        isFalse,
      );
      expect(
        _order(now, 100, method: PaymentMethod.online).countsAsRevenue,
        isFalse,
      );
      expect(
        _order(
          now,
          100,
          method: PaymentMethod.online,
          payment: PaymentStatus.paid,
        ).countsAsRevenue,
        isTrue,
      );
    });
  });

  group('RevenueStats', () {
    test('splits revenue into today, yesterday, this month and last month', () {
      final stats = RevenueStats.from([
        _order(DateTime(2026, 11, 19, 9), 10000),
        _order(DateTime(2026, 11, 19, 0, 0), 5000), // midnight is still today
        _order(DateTime(2026, 11, 18, 23, 59), 7000),
        _order(DateTime(2026, 11, 1, 10), 20000),
        _order(DateTime(2026, 10, 31, 23, 59), 40000),
        _order(
          DateTime(2026, 11, 19, 10),
          99999,
          status: OrderStatus.cancelled,
        ),
        _order(DateTime(2026, 11, 19, 11), 88888, method: PaymentMethod.online),
      ], now);

      expect(stats.todayPaise, 15000);
      expect(stats.yesterdayPaise, 7000);
      expect(stats.monthPaise, 42000);
      expect(stats.lastMonthPaise, 40000);
      expect(stats.ordersToday, 4); // includes cancelled and unpaid
      expect(stats.avgOrderPaise, 42000 ~/ 4);
    });

    test('daily series is 7 days oldest first and ends with today', () {
      final stats = RevenueStats.from([
        _order(DateTime(2026, 11, 13, 12), 1100), // 6 days ago
        _order(DateTime(2026, 11, 12, 12), 9900), // outside the window
      ], now);

      expect(stats.daily.map((p) => p.label), [
        'Fri',
        'Sat',
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Today',
      ]);
      expect(stats.daily.first.paise, 1100);
      expect(stats.daily.fold(0, (s, p) => s + p.paise), 1100);
    });

    test('monthly series spans a year boundary correctly', () {
      final january = DateTime(2027, 1, 15, 10);
      final stats = RevenueStats.from([
        _order(DateTime(2026, 12, 31, 22), 3000),
        _order(DateTime(2026, 8, 1, 8), 500),
        _order(DateTime(2026, 7, 31, 8), 700), // outside the window
      ], january);

      expect(stats.monthly.map((p) => p.label), [
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
        'Jan',
      ]);
      expect(stats.monthly[4].paise, 3000);
      expect(stats.monthly[0].paise, 500);
      expect(stats.lastMonthPaise, 3000);
    });

    test('top products rank by revenue this month', () {
      const milk = OrderItem(
        productId: 'm',
        name: 'Milk',
        unit: '',
        pricePaise: 2700,
        quantity: 2,
      );
      const atta = OrderItem(
        productId: 'a',
        name: 'Atta',
        unit: '',
        pricePaise: 23900,
        quantity: 1,
      );
      final stats = RevenueStats.from([
        _order(now, 5400, items: [milk]),
        _order(now, 29300, items: [milk, atta]),
      ], now);

      expect(stats.topProducts.map((p) => p.name), ['Atta', 'Milk']);
      expect(stats.topProducts.last.quantity, 4);
      expect(stats.topProducts.last.paise, 10800);
    });

    test('counts active orders and handles no data', () {
      final empty = RevenueStats.from(const [], now);
      expect(empty.todayPaise, 0);
      expect(empty.avgOrderPaise, 0);
      expect(empty.daily, hasLength(7));

      final stats = RevenueStats.from([
        _order(now, 100, status: OrderStatus.placed),
        _order(now, 100, status: OrderStatus.pickedUp),
        _order(now, 100),
      ], now);
      expect(stats.activeOrders, 2);
    });

    test('sample data never contains future orders', () {
      final repo = FakeOrdersAdminRepository(now: now);
      expectLater(
        repo.watchOrders().first,
        completion(
          everyElement(predicate<Order>((o) => !o.createdAt.isAfter(now))),
        ),
      );
    });
  });

  group('parseRupeesToPaise', () {
    test('parses whole and decimal amounts exactly', () {
      expect(parseRupeesToPaise('42'), 4200);
      expect(parseRupeesToPaise('42.5'), 4250);
      expect(parseRupeesToPaise(' 19.99 '), 1999);
      expect(parseRupeesToPaise('0.07'), 7);
    });

    test('rejects anything that is not a plain amount', () {
      for (final bad in ['', 'abc', '4.567', '1.2.3', '.5', '-3']) {
        expect(parseRupeesToPaise(bad), isNull, reason: bad);
      }
    });

    test('round-trips with paiseToRupeesText', () {
      expect(paiseToRupeesText(4200), '42');
      expect(paiseToRupeesText(4205), '42.05');
      expect(parseRupeesToPaise(paiseToRupeesText(123456)), 123456);
    });
  });

  group('SalesReport', () {
    final from = DateTime(2026, 11, 17);
    final to = DateTime(2026, 11, 19);
    final orders = [
      _order(DateTime(2026, 11, 19, 9), 10000, name: 'Asha', phone: '9000000001'),
      _order(DateTime(2026, 11, 19, 10), 6000,
          method: PaymentMethod.online, payment: PaymentStatus.paid),
      _order(DateTime(2026, 11, 17, 0, 0), 4000),
      _order(DateTime(2026, 11, 18, 12), 9000, status: OrderStatus.cancelled),
      _order(DateTime(2026, 11, 18, 13), 8000, method: PaymentMethod.online),
      _order(DateTime(2026, 11, 16, 23, 59), 7777), // before the range
      _order(DateTime(2026, 11, 20, 0, 0), 5555), // after the range
    ];

    test('totals only include orders inside the inclusive range', () {
      final r = SalesReport.from(orders, from, to);
      expect(r.revenuePaise, 20000);
      expect(r.revenueOrders, 3);
      expect(r.avgOrderPaise, 6666);
      expect(r.codPaise, 14000);
      expect(r.onlinePaise, 6000);
      expect(r.cancelledOrders, 1);
      expect(r.unpaidOrders, 1);
      expect(r.orders, hasLength(5));
    });

    test('has one row per day, including days without sales', () {
      final r = SalesReport.from(orders, from, to);
      expect(r.days.map((d) => d.date.day), [17, 18, 19]);
      expect(r.days.map((d) => d.revenuePaise), [4000, 0, 16000]);
      expect(r.days.fold(0, (s, d) => s + d.revenuePaise), r.revenuePaise);
    });

    test('times of day on the range bounds are ignored', () {
      final r = SalesReport.from(
        orders,
        DateTime(2026, 11, 19, 15),
        DateTime(2026, 11, 19, 8),
      );
      expect(r.days, hasLength(1));
      expect(r.revenuePaise, 16000);
    });

    test('CSV has summary, daily rows and escapes awkward text', () {
      final r = SalesReport.from([
        _order(DateTime(2026, 11, 19, 9), 12345,
            name: 'Rao, "Anu"', phone: '9000000002', rider: '=cmd'),
      ], to, to);
      final csv = r.toCsv();
      expect(csv, contains('Revenue (Rs),123.45'));
      expect(csv, contains('2026-11-19,1,123.45'));
      expect(csv, contains('"Rao, ""Anu"""'));
      expect(csv, contains("'=cmd")); // formula neutralised
      expect(r.fileStem, 'mart2door-sales-2026-11-19-to-2026-11-19');
      expect(r.toCsvBytes().take(3), [0xEF, 0xBB, 0xBF]);
    });

    test('PDF export produces a PDF document', () async {
      final bytes = await SalesReport.from(orders, from, to).toPdfBytes();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });
  });

  group('CustomerSummary', () {
    test('groups by phone, sums revenue orders and sorts by spend', () {
      final customers = CustomerSummary.from([
        _order(DateTime(2026, 11, 10), 5000, name: 'Asha', phone: '9000000001'),
        _order(DateTime(2026, 11, 12), 7000, name: 'Asha R', phone: '9000000001'),
        _order(DateTime(2026, 11, 11), 9000,
            name: 'Asha R', phone: '9000000001', status: OrderStatus.cancelled),
        _order(DateTime(2026, 11, 9), 20000, name: 'Ravi', phone: '9000000002'),
        _order(DateTime(2026, 11, 9), 100), // no phone: skipped
      ]);

      expect(customers.map((c) => c.name), ['Ravi', 'Asha R']);
      final asha = customers.last;
      expect(asha.orderCount, 3);
      expect(asha.spentPaise, 12000);
      expect(asha.lastOrderAt, DateTime(2026, 11, 12));
    });
  });
}
