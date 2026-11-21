import 'package:flutter/foundation.dart';

enum PaymentMethod {
  online('Online'),
  cod('Cash on delivery');

  const PaymentMethod(this.label);
  final String label;
}

enum PaymentStatus { pending, paid, failed, refunded }

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
    this.handlingFeePaise = 0,
    this.rainFeePaise = 0,
    this.userId = '',
    this.walletAppliedPaise = 0,
    this.referralChecked = false,
    this.walletRefunded = false,
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.assignedAt,
    this.rejectReason,
    this.rejectedByName,
    this.rejectedAt,
    this.riderRating,
    this.cashHandedOver = false,
    this.deliveryPhotoUrl,
    this.couponCode,
    this.couponDiscountPaise = 0,
    this.cancelledBy,
  });

  final String id;
  final List<OrderItem> items;
  final int subtotalPaise;
  final int deliveryFeePaise;

  /// Extra charges that were switched on when the order was placed.
  final int handlingFeePaise;
  final int rainFeePaise;
  final int totalPaise;

  /// Customer who placed the order.
  final String userId;

  /// Part of [totalPaise] the customer paid from their m2d wallet.
  final int walletAppliedPaise;

  /// Set once this order has been checked for an invite reward.
  final bool referralChecked;

  /// Set once wallet money on a cancelled order has been returned.
  final bool walletRefunded;
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

  /// When the current rider was assigned; null when nobody is assigned.
  final DateTime? assignedAt;

  /// Why a rider last handed this order back, written by the delivery app
  /// together with who rejected it and when.
  final String? rejectReason;
  final String? rejectedByName;
  final DateTime? rejectedAt;

  /// Stars (1 to 5) the customer gave this delivery; null until rated.
  final int? riderRating;

  /// Coupon the customer used, and what it took off the item total.
  final String? couponCode;
  final int couponDiscountPaise;

  /// "customer" when the customer cancelled the order in their app.
  final String? cancelledBy;

  /// Web address of the photo the rider took when handing the order over.
  final String? deliveryPhotoUrl;

  /// True once the admin confirmed the rider handed over this order's cash.
  final bool cashHandedOver;

  /// Cash the rider collected for this order and has not handed over yet.
  bool get cashWithRider =>
      status == OrderStatus.delivered &&
      paymentMethod == PaymentMethod.cod &&
      riderId != null &&
      !cashHandedOver;

  /// How long a rider may take to accept before the admin is alerted.
  static const acceptWithin = Duration(minutes: 5);

  /// A rider rejected this order and nobody else has been assigned yet.
  bool get hasOpenRejection =>
      isActive && riderId == null && (rejectReason ?? '').isNotEmpty;

  /// Assigned, but the rider has not accepted within [acceptWithin].
  bool isAwaitingRiderAt(DateTime now) =>
      status == OrderStatus.placed &&
      riderId != null &&
      assignedAt != null &&
      now.difference(assignedAt!) >= acceptWithin;

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

  String get paymentLabel => needsRefund ? 'Refund due' : _paymentLabel;

  String get _paymentLabel => switch ((paymentMethod, paymentStatus)) {
        (PaymentMethod.cod, _) => 'COD',
        (_, PaymentStatus.paid) => 'Paid online',
        (_, PaymentStatus.pending) => 'Payment pending',
        (_, PaymentStatus.failed) => 'Payment failed',
        (_, PaymentStatus.refunded) => 'Refunded',
      };

  /// Still to be collected online or in cash after the wallet.
  int get payablePaise => totalPaise - walletAppliedPaise;

  /// Whether the admin console still has wallet work to do for this order:
  /// an invite reward to check, or wallet money to return.
  bool get needsSettlement =>
      (status == OrderStatus.delivered && !referralChecked) ||
      (status == OrderStatus.cancelled &&
          walletAppliedPaise > 0 &&
          !walletRefunded);

  /// A paid online order that was cancelled: the customer is owed their
  /// money back until the admin records the refund.
  bool get needsRefund =>
      status == OrderStatus.cancelled &&
      paymentMethod == PaymentMethod.online &&
      paymentStatus == PaymentStatus.paid;

  /// Returns a copy with the rider replaced; pass nulls to unassign.
  Order withRider({
    String? id,
    String? name,
    String? phone,
    DateTime? assignedAt,
  }) =>
      Order(
        id: this.id,
        items: items,
        subtotalPaise: subtotalPaise,
        deliveryFeePaise: deliveryFeePaise,
        handlingFeePaise: handlingFeePaise,
        rainFeePaise: rainFeePaise,
        userId: userId,
        walletAppliedPaise: walletAppliedPaise,
        referralChecked: referralChecked,
        walletRefunded: walletRefunded,
        totalPaise: totalPaise,
        address: address,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        status: status,
        createdAt: createdAt,
        riderId: id,
        riderName: name,
        riderPhone: phone,
        assignedAt: id == null ? null : assignedAt,
        rejectReason: rejectReason,
        rejectedByName: rejectedByName,
        rejectedAt: rejectedAt,
        riderRating: riderRating,
        cashHandedOver: cashHandedOver,
        deliveryPhotoUrl: deliveryPhotoUrl,
        couponCode: couponCode,
        couponDiscountPaise: couponDiscountPaise,
        cancelledBy: cancelledBy,
      );

  Order copyWith({
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    bool? cashHandedOver,
  }) =>
      Order(
        id: id,
        items: items,
        subtotalPaise: subtotalPaise,
        deliveryFeePaise: deliveryFeePaise,
        handlingFeePaise: handlingFeePaise,
        rainFeePaise: rainFeePaise,
        userId: userId,
        walletAppliedPaise: walletAppliedPaise,
        referralChecked: referralChecked,
        walletRefunded: walletRefunded,
        totalPaise: totalPaise,
        address: address,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        status: status ?? this.status,
        createdAt: createdAt,
        riderId: riderId,
        riderName: riderName,
        riderPhone: riderPhone,
        assignedAt: assignedAt,
        rejectReason: rejectReason,
        rejectedByName: rejectedByName,
        rejectedAt: rejectedAt,
        riderRating: riderRating,
        cashHandedOver: cashHandedOver ?? this.cashHandedOver,
        deliveryPhotoUrl: deliveryPhotoUrl,
        couponCode: couponCode,
        couponDiscountPaise: couponDiscountPaise,
        cancelledBy: cancelledBy,
      );

  factory Order.fromMap(String id, Map<String, dynamic> map) => Order(
        id: id,
        items: ((map['items'] as List?) ?? const [])
            .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        subtotalPaise: (map['subtotalPaise'] as num?)?.toInt() ?? 0,
        deliveryFeePaise: (map['deliveryFeePaise'] as num?)?.toInt() ?? 0,
        handlingFeePaise: (map['handlingFeePaise'] as num?)?.toInt() ?? 0,
        rainFeePaise: (map['rainFeePaise'] as num?)?.toInt() ?? 0,
        userId: map['userId'] as String? ?? '',
        walletAppliedPaise: (map['walletAppliedPaise'] as num?)?.toInt() ?? 0,
        referralChecked: map['referralChecked'] as bool? ?? false,
        walletRefunded: map['walletRefunded'] as bool? ?? false,
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
        status:
            _enumByName(OrderStatus.values, map['status'], OrderStatus.placed),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0,
        ),
        riderId: map['riderId'] as String?,
        riderName: map['riderName'] as String?,
        riderPhone: map['riderPhone'] as String?,
        assignedAt: _time(map['assignedAt']),
        rejectReason: map['rejectReason'] as String?,
        rejectedByName: map['rejectedByName'] as String?,
        rejectedAt: _time(map['rejectedAt']),
        riderRating: (map['riderRating'] as num?)?.toInt(),
        cashHandedOver: map['cashHandedOver'] as bool? ?? false,
        deliveryPhotoUrl: map['deliveryPhotoUrl'] as String?,
        couponCode: map['couponCode'] as String?,
        couponDiscountPaise:
            (map['couponDiscountPaise'] as num?)?.toInt() ?? 0,
        cancelledBy: map['cancelledBy'] as String?,
      );

  static DateTime? _time(Object? millis) => millis is num
      ? DateTime.fromMillisecondsSinceEpoch(millis.toInt())
      : null;
}
