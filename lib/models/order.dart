import 'package:flutter/foundation.dart';

enum PaymentMethod {
  online('Online'),
  cod('Cash on delivery');

  const PaymentMethod(this.label);
  final String label;
}

enum PaymentStatus { pending, paid, failed }

/// Lifecycle shared with the customer and delivery apps.
enum OrderStatus {
  placed('Placed'),
  accepted('Accepted'),
  pickedUp('Out for delivery'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const OrderStatus(this.label);
  final String label;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

@immutable
class Address {
  const Address({
    required this.name,
    required this.phone,
    required this.line1,
    required this.landmark,
    required this.pincode,
  });

  final String name;
  final String phone;
  final String line1;
  final String landmark;
  final String pincode;

  String get singleLine =>
      [line1, if (landmark.isNotEmpty) landmark, pincode].join(', ');

  factory Address.fromMap(Map<String, dynamic> map) => Address(
    name: map['name'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    line1: map['line1'] as String? ?? '',
    landmark: map['landmark'] as String? ?? '',
    pincode: map['pincode'] as String? ?? '',
  );
}

@immutable
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.pricePaise,
    required this.quantity,
  });

  final String productId;
  final String name;
  final String unit;
  final int pricePaise;
  final int quantity;

  int get lineTotalPaise => pricePaise * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    productId: map['productId'] as String? ?? '',
    name: map['name'] as String? ?? '',
    unit: map['unit'] as String? ?? '',
    pricePaise: (map['pricePaise'] as num?)?.toInt() ?? 0,
    quantity: (map['quantity'] as num?)?.toInt() ?? 0,
  );
}

/// Read model of `orders/{id}`. The admin only ever changes `status`.
@immutable
class Order {
  const Order({
    required this.id,
    required this.items,
    required this.subtotalPaise,
    required this.deliveryFeePaise,
    required this.totalPaise,
    required this.address,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    this.riderId,
    this.riderName,
    this.riderPhone,
  });

  final String id;
  final List<OrderItem> items;
  final int subtotalPaise;
  final int deliveryFeePaise;
  final int totalPaise;
  final Address address;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final DateTime createdAt;

  /// Delivery partner assigned by the admin; null until assigned. Name and
  /// phone are copied onto the order so the customer app can show them
  /// without reading the `riders` collection.
  final String? riderId;
  final String? riderName;
  final String? riderPhone;

  String get displayId =>
      '#${(id.length <= 6 ? id : id.substring(id.length - 6)).toUpperCase()}';

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  bool get isActive =>
      status != OrderStatus.delivered && status != OrderStatus.cancelled;

  /// Revenue rule used across the dashboard: an order counts unless it was
  /// cancelled or its online payment has not been received. Cash-on-delivery
  /// orders count from the moment they are placed.
  bool get countsAsRevenue =>
      status != OrderStatus.cancelled &&
      (paymentMethod == PaymentMethod.cod ||
          paymentStatus == PaymentStatus.paid);

  String get paymentLabel => switch ((paymentMethod, paymentStatus)) {
    (PaymentMethod.cod, _) => 'COD',
    (_, PaymentStatus.paid) => 'Paid online',
    (_, PaymentStatus.pending) => 'Payment pending',
    (_, PaymentStatus.failed) => 'Payment failed',
  };

  /// Returns a copy with the rider replaced; pass nulls to unassign.
  Order withRider({String? id, String? name, String? phone}) => Order(
    id: this.id,
    items: items,
    subtotalPaise: subtotalPaise,
    deliveryFeePaise: deliveryFeePaise,
    totalPaise: totalPaise,
    address: address,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    status: status,
    createdAt: createdAt,
    riderId: id,
    riderName: name,
    riderPhone: phone,
  );

  Order copyWith({OrderStatus? status}) => Order(
    id: id,
    items: items,
    subtotalPaise: subtotalPaise,
    deliveryFeePaise: deliveryFeePaise,
    totalPaise: totalPaise,
    address: address,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    status: status ?? this.status,
    createdAt: createdAt,
    riderId: riderId,
    riderName: riderName,
    riderPhone: riderPhone,
  );

  factory Order.fromMap(String id, Map<String, dynamic> map) => Order(
    id: id,
    items: ((map['items'] as List?) ?? const [])
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false),
    subtotalPaise: (map['subtotalPaise'] as num?)?.toInt() ?? 0,
    deliveryFeePaise: (map['deliveryFeePaise'] as num?)?.toInt() ?? 0,
    totalPaise: (map['totalPaise'] as num?)?.toInt() ?? 0,
    address: Address.fromMap(
      Map<String, dynamic>.from((map['address'] as Map?) ?? const {}),
    ),
    paymentMethod: _enumByName(
      PaymentMethod.values,
      map['paymentMethod'],
      PaymentMethod.cod,
    ),
    paymentStatus: _enumByName(
      PaymentStatus.values,
      map['paymentStatus'],
      PaymentStatus.pending,
    ),
    status: _enumByName(OrderStatus.values, map['status'], OrderStatus.placed),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (map['createdAt'] as num?)?.toInt() ?? 0,
    ),
    riderId: map['riderId'] as String?,
    riderName: map['riderName'] as String?,
    riderPhone: map['riderPhone'] as String?,
  );
}
