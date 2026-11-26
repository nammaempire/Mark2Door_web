import 'package:flutter/foundation.dart';

/// Mirrors the `categories/{id}` documents read by the customer app.
@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    this.icon = 'basket',
    this.imageUrl = '',
  });

  final String id;
  final String name;

  /// Drawn icon of categories made before pictures. The customer app
  /// still uses it for the tile colour, and shows it when [imageUrl] is
  /// empty or fails to load.
  final String icon;

  /// Picture for the category tile: an https link or an uploaded image.
  final String imageUrl;

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
    id: id,
    name: map['name'] as String? ?? '',
    icon: map['icon'] as String? ?? 'basket',
    imageUrl: map['imageUrl'] as String? ?? '',
  );

  Category copyWith({String? id}) => Category(
    id: id ?? this.id,
    name: name,
    icon: icon,
    imageUrl: imageUrl,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'icon': icon,
    'imageUrl': imageUrl,
  };
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
    this.allIndia = false,
    this.storeStock = const {},
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

  /// "Deliver all over India": shown on the customer app's Outstation
  /// tab and sent by courier to pincodes outside the service areas.
  final bool allIndia;

  /// Stock kept separately by each store, by store id. A store without
  /// an entry uses [inStock] and [stockQty].
  final Map<String, StoreStock> storeStock;

  /// "In stock" as store [storeId] has it (null: the business as a whole).
  bool inStockAt(String? storeId) =>
      inStock && (storeStock[storeId]?.inStock ?? true);

  /// True when the product is switched off for every store with the main
  /// "In stock" switch, which a store's own switch cannot override.
  bool get offEverywhere => !inStock;

  /// Units left at store [storeId]; null when not counted there.
  int? stockQtyAt(String? storeId) => storeStock.containsKey(storeId)
      ? storeStock[storeId]!.stockQty
      : stockQty;

  bool canBeOrderedAt(String? storeId) {
    final qty = stockQtyAt(storeId);
    return inStockAt(storeId) && (qty == null || qty > 0);
  }

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
    storeStock: storeStock,
    allIndia: allIndia,
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
    allIndia: map['allIndia'] as bool? ?? false,
    storeStock: {
      for (final e in (map['storeStock'] as Map? ?? const {}).entries)
        if (e.value is Map)
          e.key as String: StoreStock.fromMap(
            Map<String, dynamic>.from(e.value as Map),
          ),
    },
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
    'allIndia': allIndia,
    if (storeStock.isNotEmpty)
      'storeStock': {
        for (final e in storeStock.entries) e.key: e.value.toMap(),
      },
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
  const ServiceArea({
    required this.pincode,
    required this.active,
    this.name = '',
    this.storeId,
  });

  final String pincode;
  final bool active;

  /// The store that delivers to this pincode; null with one shop.
  final String? storeId;

  /// Area name shown to customers next to the pincode, e.g. "Nagercoil".
  final String name;
}

/// One store's stock of a product.
@immutable
class StoreStock {
  const StoreStock({this.inStock = true, this.stockQty});

  final bool inStock;

  /// Units left at this store; null means not counted.
  final int? stockQty;

  factory StoreStock.fromMap(Map<String, dynamic> map) => StoreStock(
        inStock: map['inStock'] as bool? ?? true,
        stockQty: (map['stockQty'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {'inStock': inStock, 'stockQty': stockQty};
}
