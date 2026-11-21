import 'package:flutter/foundation.dart';

/// Mirrors the `categories/{id}` documents read by the customer app.
@immutable
class Category {
  const Category({required this.id, required this.name, required this.icon});

  final String id;
  final String name;
  final String icon;

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
    id: id,
    name: map['name'] as String? ?? '',
    icon: map['icon'] as String? ?? 'basket',
  );

  Category copyWith({String? id}) =>
      Category(id: id ?? this.id, name: name, icon: icon);

  Map<String, dynamic> toMap() => {'name': name, 'icon': icon};
}

/// Mirrors the `products/{id}` documents read by the customer app. Field
/// names must stay identical in both apps.
@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.unit,
    required this.pricePaise,
    required this.mrpPaise,
    this.imageUrls = const [],
    this.emoji = '',
    this.subtitle = '',
    this.description = '',
    this.inStock = true,
    this.stockQty,
  });

  /// Empty for a product that has not been saved yet.
  final String id;
  final String name;
  final String categoryId;
  final String unit;
  final int pricePaise;
  final int mrpPaise;

  /// Up to [maxImages] photo links; the first is the main photo.
  final List<String> imageUrls;
  final String emoji;

  /// Short line shown under the name on the customer's product page.
  final String subtitle;
  final String description;

  /// The "In stock" switch.
  final bool inStock;

  /// Units left to sell. Orders reduce it and cancelled orders add it
  /// back. Null means stock is not counted for this product.
  final int? stockQty;

  /// Customers can order it: switched on and not counted down to zero.
  bool get canBeOrdered => inStock && (stockQty == null || stockQty! > 0);

  static const maxImages = 5;

  /// Main photo, or empty when the product only has an emoji.
  String get imageUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  int get discountPercent => mrpPaise <= pricePaise
      ? 0
      : (((mrpPaise - pricePaise) * 100) / mrpPaise).round();

  Product copyWith({String? id, bool? inStock}) => Product(
    id: id ?? this.id,
    name: name,
    categoryId: categoryId,
    unit: unit,
    pricePaise: pricePaise,
    mrpPaise: mrpPaise,
    imageUrls: imageUrls,
    emoji: emoji,
    subtitle: subtitle,
    description: description,
    inStock: inStock ?? this.inStock,
    stockQty: stockQty,
  );

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
    id: id,
    name: map['name'] as String? ?? '',
    categoryId: map['categoryId'] as String? ?? '',
    unit: map['unit'] as String? ?? '',
    pricePaise: (map['pricePaise'] as num?)?.toInt() ?? 0,
    mrpPaise: (map['mrpPaise'] as num?)?.toInt() ?? 0,
    imageUrls: _readImages(map),
    emoji: map['emoji'] as String? ?? '',
    subtitle: map['subtitle'] as String? ?? '',
    description: map['description'] as String? ?? '',
    inStock: map['inStock'] as bool? ?? true,
    stockQty: (map['stockQty'] as num?)?.toInt(),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'nameLower': name.toLowerCase(),
    'categoryId': categoryId,
    'unit': unit,
    'pricePaise': pricePaise,
    'mrpPaise': mrpPaise,
    // `imageUrl` is kept for app versions that only know one photo.
    'imageUrl': imageUrl,
    'imageUrls': imageUrls,
    'emoji': emoji,
    'subtitle': subtitle,
    'description': description,
    'inStock': inStock,
    'stockQty': stockQty,
  };
}

/// Reads `imageUrls`, falling back to the single `imageUrl` of products
/// saved before several photos were supported.
List<String> _readImages(Map<String, dynamic> map) {
  final list = [
    for (final e in (map['imageUrls'] as List?) ?? const [])
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
  if (list.isEmpty) {
    final single = (map['imageUrl'] as String? ?? '').trim();
    if (single.isNotEmpty) list.add(single);
  }
  return List.unmodifiable(list.take(Product.maxImages));
}

/// Mirrors `service_areas/{pincode}`.
@immutable
class ServiceArea {
  const ServiceArea({required this.pincode, required this.active});

  final String pincode;
  final bool active;
}
