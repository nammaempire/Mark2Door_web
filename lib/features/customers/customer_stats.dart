import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';

import '../../data/repositories.dart';
import '../../models/order.dart';

/// A customer as seen through their orders. Customers are identified by
/// the phone number on the delivery address.
@immutable
class CustomerSummary {
  const CustomerSummary({
    required this.name,
    required this.phone,
    required this.pincode,
    required this.orderCount,
    required this.spentPaise,
    required this.lastOrderAt,
  });

  final String name;
  final String phone;
  final String pincode;

  /// Every order they placed in the period, whatever became of it.
  final int orderCount;

  /// Total across orders that count as revenue.
  final int spentPaise;
  final DateTime lastOrderAt;

  /// Groups [orders] by phone; biggest spenders first. Used by tests and
  /// sample data; the live console reads the server's customer records.
  static List<CustomerSummary> from(List<Order> orders) {
    final byPhone = <String, List<Order>>{};
    for (final order in orders) {
      final phone = order.address.phone;
      if (phone.isEmpty) continue;
      byPhone.putIfAbsent(phone, () => []).add(order);
    }
    final customers = byPhone.entries.map((entry) {
      final list = entry.value
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return CustomerSummary(
        // Name and pincode come from the most recent order.
        name: list.first.address.name,
        phone: entry.key,
        pincode: list.first.address.pincode,
        orderCount: list.length,
        spentPaise: list
            .where((o) => o.countsAsRevenue)
            .fold(0, (sum, o) => sum + o.totalPaise),
        lastOrderAt: list.first.createdAt,
      );
    }).toList()
      ..sort((a, b) => b.spentPaise.compareTo(a.spentPaise));
    return customers;
  }

  /// Adds together the records several stores hold for the same phone,
  /// keeping the newest name and pincode; biggest spenders first.
  static List<CustomerSummary> merged(Iterable<CustomerSummary> records) {
    final byPhone = <String, CustomerSummary>{};
    for (final r in records) {
      final was = byPhone[r.phone];
      if (was == null) {
        byPhone[r.phone] = r;
        continue;
      }
      final newest = r.lastOrderAt.isAfter(was.lastOrderAt) ? r : was;
      byPhone[r.phone] = CustomerSummary(
        name: newest.name,
        phone: r.phone,
        pincode: newest.pincode,
        orderCount: was.orderCount + r.orderCount,
        spentPaise: was.spentPaise + r.spentPaise,
        lastOrderAt: newest.lastOrderAt,
      );
    }
    return byPhone.values.toList()
      ..sort((a, b) => b.spentPaise.compareTo(a.spentPaise));
  }

  /// One of the server's records (`stats_customers`, see
  /// `functions/stats.js`).
  factory CustomerSummary.fromMap(Map<String, dynamic> map) => CustomerSummary(
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        pincode: map['pincode'] as String? ?? '',
        orderCount: (map['orders'] as num?)?.round() ?? 0,
        spentPaise: (map['spentPaise'] as num?)?.round() ?? 0,
        lastOrderAt: DateTime.fromMillisecondsSinceEpoch(
          (map['lastOrderAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// How many customers the page loads at once: the biggest spenders.
/// Anyone else is found by typing their full mobile number.
const customerListLimit = 500;

abstract interface class CustomersRepository {
  /// The biggest spenders of [month] (all time when null), at most
  /// [customerListLimit]. With [storeId], that store's customers only.
  Future<List<CustomerSummary>> fetchTop({DateTime? month, String? storeId});

  /// The customer with exactly this mobile number, if they ordered in the
  /// period.
  Future<CustomerSummary?> findByPhone(
    String phone, {
    DateTime? month,
    String? storeId,
  });

  /// A customer's orders in the period, newest first.
  Future<List<Order>> fetchOrders(
    String phone, {
    DateTime? month,
    String? storeId,
  });
}

String _period(DateTime? month) => month == null
    ? 'all'
    : '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';

bool _inMonth(DateTime at, DateTime? month) =>
    month == null || (at.year == month.year && at.month == month.month);

class FirestoreCustomersRepository implements CustomersRepository {
  FirestoreCustomersRepository(this._db);

  final FirebaseFirestore _db;

  Query<Map<String, dynamic>> _records(DateTime? month, String? storeId) {
    Query<Map<String, dynamic>> q = _db
        .collection('stats_customers')
        .where('period', isEqualTo: _period(month));
    if (storeId != null) q = q.where('storeId', isEqualTo: storeId);
    return q;
  }

  @override
  Future<List<CustomerSummary>> fetchTop({
    DateTime? month,
    String? storeId,
  }) async {
    final snap = await _records(month, storeId)
        .orderBy('spentPaise', descending: true)
        .limit(customerListLimit)
        .get();
    return CustomerSummary.merged(
      snap.docs.map((d) => CustomerSummary.fromMap(d.data())),
    );
  }

  @override
  Future<CustomerSummary?> findByPhone(
    String phone, {
    DateTime? month,
    String? storeId,
  }) async {
    final snap = await _records(month, storeId)
        .where('phone', isEqualTo: phone)
        .get();
    final found = CustomerSummary.merged(
      snap.docs.map((d) => CustomerSummary.fromMap(d.data())),
    );
    return found.isEmpty ? null : found.first;
  }

  @override
  Future<List<Order>> fetchOrders(
    String phone, {
    DateTime? month,
    String? storeId,
  }) async {
    Query<Map<String, dynamic>> q =
        _db.collection('orders').where('address.phone', isEqualTo: phone);
    if (storeId != null) q = q.where('storeId', isEqualTo: storeId);
    final snap = await q.limit(300).get();
    return [
      for (final d in snap.docs) Order.fromMap(d.id, d.data()),
    ].where((o) => _inMonth(o.createdAt, month)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

/// Sample mode: worked out from the sample orders.
class FakeCustomersRepository implements CustomersRepository {
  FakeCustomersRepository(this._orders);

  final OrdersAdminRepository _orders;

  Future<List<Order>> _in(DateTime? month, String? storeId) async => [
        for (final o in await _orders.watchOrders(storeId: storeId).first)
          if (_inMonth(o.createdAt, month)) o,
      ];

  @override
  Future<List<CustomerSummary>> fetchTop({
    DateTime? month,
    String? storeId,
  }) async =>
      CustomerSummary.from(await _in(month, storeId))
          .take(customerListLimit)
          .toList();

  @override
  Future<CustomerSummary?> findByPhone(
    String phone, {
    DateTime? month,
    String? storeId,
  }) async =>
      CustomerSummary.from(await _in(month, storeId))
          .where((c) => c.phone == phone)
          .firstOrNull;

  @override
  Future<List<Order>> fetchOrders(
    String phone, {
    DateTime? month,
    String? storeId,
  }) async =>
      [
        for (final o in await _in(month, storeId))
          if (o.address.phone == phone) o,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
