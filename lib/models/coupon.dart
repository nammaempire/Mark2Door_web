import 'package:flutter/foundation.dart';

import '../core/formatters.dart';

enum CouponType {
  percent('Percent off'),
  flat('Rupees off');

  const CouponType(this.label);
  final String label;
}

/// Mirrors `coupons/{CODE}`, read by the customer app at checkout. Field
/// names must stay identical in both apps.
@immutable
class Coupon {
  const Coupon({
    required this.code,
    required this.type,
    required this.value,
    this.minOrderPaise = 0,
    this.maxDiscountPaise = 0,
    this.expiresAt,
    this.active = true,
    this.oncePerCustomer = false,
  });

  /// Upper case; also the document id, so it cannot be changed later.
  final String code;
  final CouponType type;

  /// Percent off (1 to 100) or paise off, depending on [type].
  final int value;

  /// Smallest item total the coupon works on; 0 for no minimum.
  final int minOrderPaise;

  /// Upper limit for a percent coupon's discount; 0 for no limit.
  final int maxDiscountPaise;

  /// The coupon works up to the end of this day; null means no expiry.
  final DateTime? expiresAt;
  final bool active;

  /// When true, each customer can use the code on one order only.
  final bool oncePerCustomer;

  bool isExpiredAt(DateTime now) =>
      expiresAt != null && now.isAfter(expiresAt!);

  /// "10% off, up to ₹100" or "₹50 off".
  String get offer {
    if (type == CouponType.flat) return '${formatPaise(value)} off';
    return maxDiscountPaise > 0
        ? '$value% off, up to ${formatPaise(maxDiscountPaise)}'
        : '$value% off';
  }

  Coupon copyWith({bool? active}) => Coupon(
        code: code,
        type: type,
        value: value,
        minOrderPaise: minOrderPaise,
        maxDiscountPaise: maxDiscountPaise,
        expiresAt: expiresAt,
        active: active ?? this.active,
        oncePerCustomer: oncePerCustomer,
      );

  static final _valid = RegExp(r'^[A-Z0-9]{3,20}$');

  /// Codes are 3 to 20 letters and digits, stored in upper case.
  static bool isValidCode(String code) => _valid.hasMatch(code);

  static String normalise(String input) => input.trim().toUpperCase();

  factory Coupon.fromMap(String id, Map<String, dynamic> map) => Coupon(
        code: id,
        type: map['type'] == 'flat' ? CouponType.flat : CouponType.percent,
        value: (map['value'] as num?)?.toInt() ?? 0,
        minOrderPaise: (map['minOrderPaise'] as num?)?.toInt() ?? 0,
        maxDiscountPaise: (map['maxDiscountPaise'] as num?)?.toInt() ?? 0,
        expiresAt: map['expiresAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (map['expiresAt'] as num).toInt(),
              ),
        active: map['active'] as bool? ?? true,
        oncePerCustomer: map['oncePerCustomer'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'value': value,
        'minOrderPaise': minOrderPaise,
        'maxDiscountPaise': maxDiscountPaise,
        'expiresAt': expiresAt?.millisecondsSinceEpoch,
        'active': active,
        'oncePerCustomer': oncePerCustomer,
      };
}
