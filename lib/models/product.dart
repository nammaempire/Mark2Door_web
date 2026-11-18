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
    this.imageUrl = '',
    this.emoji = '',
    this.description = '',
    this.inStock = true,
  });

  /// Empty for a product that has not been saved yet.
  final String id;
  final String name;
  final String categoryId;
  final String unit;
  final int pricePaise;
  final int mrpPaise;
  final String imageUrl;
  final String emoji;
  final String description;
  final bool inStock;

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
    imageUrl: imageUrl,
    emoji: emoji,
    description: description,
    inStock: inStock ?? this.inStock,
  );

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
    id: id,
    name: map['name'] as String? ?? '',
    categoryId: map['categoryId'] as String? ?? '',
    unit: map['unit'] as String? ?? '',
    pricePaise: (map['pricePaise'] as num?)?.toInt() ?? 0,
    mrpPaise: (map['mrpPaise'] as num?)?.toInt() ?? 0,
    imageUrl: map['imageUrl'] as String? ?? '',
    emoji: map['emoji'] as String? ?? '',
    description: map['description'] as String? ?? '',
    inStock: map['inStock'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'nameLower': name.toLowerCase(),
    'categoryId': categoryId,
    'unit': unit,
    'pricePaise': pricePaise,
    'mrpPaise': mrpPaise,
    'imageUrl': imageUrl,
    'emoji': emoji,
    'description': description,
    'inStock': inStock,
  };
}

/// Mirrors `service_areas/{pincode}`.
@immutable
class ServiceArea {
  const ServiceArea({required this.pincode, required this.active});

  final String pincode;
  final bool active;
}
