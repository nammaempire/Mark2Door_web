import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';

import '../../data/repositories.dart';
import '../../models/order.dart';

/// One day's sales totals for one store, kept by the server in
/// `stats_daily/{day}__{store}` (see `functions/stats.js`). The dashboard
/// and reports add these up instead of reading every order, so the
/// numbers stay right however many orders there are.
@immutable
class DayStats {
  const DayStats({
    required this.day,
    required this.storeId,
    this.orders = 0,
    this.revenueOrders = 0,
    this.revenuePaise = 0,
    this.cancelledOrders = 0,
    this.unpaidOrders = 0,
    this.codPaise = 0,
    this.onlinePaise = 0,
    this.deliveryFeesPaise = 0,
    this.items = const {},
  });

  /// Midnight at the start of the day.
  final DateTime day;

  /// Empty for orders that belong to no store.
  final String storeId;

  /// Every order placed that day, whatever became of it.
  final int orders;

  /// Orders that count as revenue, and what they came to.
  final int revenueOrders;
  final int revenuePaise;
  final int cancelledOrders;

  /// Online orders not paid yet.
  final int unpaidOrders;
  final int codPaise;
  final int onlinePaise;
  final int deliveryFeesPaise;

  /// Product name to units sold and money taken, from revenue orders.
  final Map<String, ({int quantity, int paise})> items;

  static int _int(Object? v) => (v as num?)?.round() ?? 0;

  /// Null when the record has no readable day.
  static DayStats? fromMap(Map<String, dynamic> map) {
    final parts = '${map['day'] ?? ''}'.split('-');
    if (parts.length != 3) return null;
    final ymd = parts.map(int.tryParse).toList();
    if (ymd.contains(null)) return null;
    final items = <String, ({int quantity, int paise})>{};
    final raw = map['items'];
    if (raw is Map) {
      raw.forEach((name, value) {
        if (value is Map) {
          items['$name'] = (quantity: _int(value['q']), paise: _int(value['p']));
        }
      });
    }
    return DayStats(
      day: DateTime(ymd[0]!, ymd[1]!, ymd[2]!),
      storeId: map['storeId'] as String? ?? '',
      orders: _int(map['orders']),
      revenueOrders: _int(map['revenueOrders']),
      revenuePaise: _int(map['revenuePaise']),
      cancelledOrders: _int(map['cancelledOrders']),
      unpaidOrders: _int(map['unpaidOrders']),
      codPaise: _int(map['codPaise']),
      onlinePaise: _int(map['onlinePaise']),
      deliveryFeesPaise: _int(map['deliveryFeesPaise']),
      items: items,
    );
  }

  /// The same totals worked out from a list of orders, by the same rules
  /// as the server: a cancelled order counts only as cancelled, an unpaid
  /// online order only as unpaid, and every other order as revenue.
  static List<DayStats> fromOrders(Iterable<Order> orders) {
    final byKey = <String, _Tally>{};
    for (final o in orders) {
      final day = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
      final store = o.storeId ?? '';
      final t = byKey.putIfAbsent(
        '${day.millisecondsSinceEpoch}|$store',
        () => _Tally(day, store),
      );
      t.orders++;
      if (o.status == OrderStatus.cancelled) {
        t.cancelled++;
        continue;
      }
      if (!o.countsAsRevenue) {
        t.unpaid++;
        continue;
      }
      t.revenueOrders++;
      t.revenue += o.totalPaise;
      t.fees += o.deliveryFeePaise;
      if (o.paymentMethod == PaymentMethod.cod) {
        t.cod += o.totalPaise;
      } else {
        t.online += o.totalPaise;
      }
      for (final item in o.items) {
        final was = t.items[item.name] ?? (quantity: 0, paise: 0);
        t.items[item.name] = (
          quantity: was.quantity + item.quantity,
          paise: was.paise + item.lineTotalPaise,
        );
      }
    }
    return [for (final t in byKey.values) t.done()];
  }

  /// [all] narrowed to one store; every store when [storeId] is null.
  static List<DayStats> forStore(List<DayStats> all, String? storeId) =>
      storeId == null
          ? all
          : [
              for (final d in all)
                if (d.storeId == storeId) d,
            ];
}

class _Tally {
  _Tally(this.day, this.storeId);

  final DateTime day;
  final String storeId;
  int orders = 0, revenueOrders = 0, revenue = 0, cancelled = 0, unpaid = 0;
  int cod = 0, online = 0, fees = 0;
  final items = <String, ({int quantity, int paise})>{};

  DayStats done() => DayStats(
        day: day,
        storeId: storeId,
        orders: orders,
        revenueOrders: revenueOrders,
        revenuePaise: revenue,
        cancelledOrders: cancelled,
        unpaidOrders: unpaid,
        codPaise: cod,
        onlinePaise: online,
        deliveryFeesPaise: fees,
        items: items,
      );
}

abstract interface class StatsRepository {
  /// The day totals from [from] to [to], both included. With [storeId],
  /// only that store's: a store login may read no others.
  Stream<List<DayStats>> watchDays(
    DateTime from,
    DateTime to, {
    String? storeId,
  });

  /// Has the server work every day's totals out again from all orders.
  /// Returns how many orders it counted. Main admin only.
  Future<int> rebuild();
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class FirestoreStatsRepository implements StatsRepository {
  FirestoreStatsRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<DayStats>> watchDays(
    DateTime from,
    DateTime to, {
    String? storeId,
  }) {
    Query<Map<String, dynamic>> days = _db.collection('stats_daily');
    if (storeId != null) days = days.where('storeId', isEqualTo: storeId);
    return days
        .where('day', isGreaterThanOrEqualTo: _dayKey(from))
        .where('day', isLessThanOrEqualTo: _dayKey(to))
        .snapshots()
        .map(
          (snap) => [
            for (final d in snap.docs)
              if (DayStats.fromMap(d.data()) case final day?) day,
          ],
        );
  }

  @override
  Future<int> rebuild() async {
    final job = await _db.collection('stats_jobs').add({
      'type': 'rebuild',
      'status': 'running',
      'requestedAt': DateTime.now().millisecondsSinceEpoch,
    });
    // The server writes the outcome back onto the record.
    final done = await job
        .snapshots()
        .firstWhere((s) => s.data()?['status'] != 'running')
        .timeout(const Duration(minutes: 10));
    final data = done.data() ?? const {};
    if (data['status'] != 'done') throw StateError('Rebuild failed');
    return (data['orders'] as num?)?.toInt() ?? 0;
  }
}

/// Sample mode: the totals are worked out from the sample orders, so the
/// console behaves as it does with the server keeping them.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository(this._orders);

  final OrdersAdminRepository _orders;

  @override
  Stream<List<DayStats>> watchDays(
    DateTime from,
    DateTime to, {
    String? storeId,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return _orders.watchOrders(storeId: storeId).map(
          (orders) => [
            for (final d in DayStats.fromOrders(orders))
              if (!d.day.isBefore(start) && !d.day.isAfter(end)) d,
          ],
        );
  }

  @override
  Future<int> rebuild() async =>
      (await _orders.watchOrders().first).length;
}
