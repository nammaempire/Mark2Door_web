import 'package:flutter/foundation.dart';

import '../../models/order.dart';

/// A customer as seen through their orders. Customers are identified by
/// the phone number on the delivery address.
@immutable
class CustomerSummary {
  const CustomerSummary({
    required this.name,
    required this.phone,
    required this.pincode,
    required this.orders,
    required this.spentPaise,
  });

  final String name;
  final String phone;
  final String pincode;

  /// Newest first.
  final List<Order> orders;

  /// Total across orders that count as revenue.
  final int spentPaise;

  DateTime get lastOrderAt => orders.first.createdAt;

  /// Groups [orders] by phone; biggest spenders first.
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
        orders: List.unmodifiable(list),
        spentPaise: list
            .where((o) => o.countsAsRevenue)
            .fold(0, (sum, o) => sum + o.totalPaise),
      );
    }).toList()
      ..sort((a, b) => b.spentPaise.compareTo(a.spentPaise));
    return customers;
  }
}
