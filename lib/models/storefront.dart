import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Artwork a category can use. Keys are stored in `categories/{id}.icon`
/// and must match `CategoryStyle` in the customer app.
const kCategoryIcons = <String, ({String emoji, String label})>{
  'fruits': (emoji: '🥬', label: 'Fruits & veg'),
  'dairy': (emoji: '🥛', label: 'Dairy'),
  'staples': (emoji: '🌾', label: 'Staples'),
  'snacks': (emoji: '🍿', label: 'Snacks'),
  'beverages': (emoji: '🧃', label: 'Beverages'),
  'household': (emoji: '🧼', label: 'Household'),
  'bakery': (emoji: '🍞', label: 'Bakery'),
  'meat': (emoji: '🍗', label: 'Meat & fish'),
  'frozen': (emoji: '🍦', label: 'Frozen'),
  'personal': (emoji: '🧴', label: 'Personal care'),
  'baby': (emoji: '🍼', label: 'Baby care'),
  'pets': (emoji: '🐾', label: 'Pet care'),
};

String categoryEmoji(String icon) => kCategoryIcons[icon]?.emoji ?? '🛒';

/// Banner colour themes. Keys are stored in `banners/{id}.theme` and must
/// match `bannerColors` in the customer app.
const kBannerThemes = <String, List<Color>>{
  'green': [Color(0xFF1FA463), Color(0xFF0A6B40)],
  'orange': [Color(0xFFFF9D3C), Color(0xFFEE5A0B)],
  'purple': [Color(0xFF7C5CFF), Color(0xFF4B2FCB)],
  'blue': [Color(0xFF2F9BFF), Color(0xFF155FCB)],
  'pink': [Color(0xFFFF6FA3), Color(0xFFD42A6B)],
};

/// Mirrors `banners/{id}`: a promo card on the customer home page.
@immutable
class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.theme,
    required this.categoryId,
    this.active = true,
    this.sortOrder = 0,
  });

  /// Empty for a banner that has not been saved yet.
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final String theme;

  /// Category opened when the banner is tapped.
  final String categoryId;
  final bool active;
  final int sortOrder;

  List<Color> get colors => kBannerThemes[theme] ?? kBannerThemes['green']!;

  PromoBanner copyWith({String? id, bool? active, int? sortOrder}) =>
      PromoBanner(
        id: id ?? this.id,
        title: title,
        subtitle: subtitle,
        emoji: emoji,
        theme: theme,
        categoryId: categoryId,
        active: active ?? this.active,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  factory PromoBanner.fromMap(String id, Map<String, dynamic> map) =>
      PromoBanner(
        id: id,
        title: map['title'] as String? ?? '',
        subtitle: map['subtitle'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '',
        theme: map['theme'] as String? ?? 'green',
        categoryId: map['categoryId'] as String? ?? '',
        active: map['active'] as bool? ?? true,
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'subtitle': subtitle,
        'emoji': emoji,
        'theme': theme,
        'categoryId': categoryId,
        'active': active,
        'sortOrder': sortOrder,
      };
}

/// Mirrors the single document `settings/store`.
@immutable
class StoreSettings {
  const StoreSettings({
    required this.deliveryFeePaise,
    required this.freeDeliveryThresholdPaise,
    required this.deliveryEtaMinutes,
  });

  static const defaults = StoreSettings(
    deliveryFeePaise: 3000,
    freeDeliveryThresholdPaise: 49900,
    deliveryEtaMinutes: 30,
  );

  final int deliveryFeePaise;

  /// Orders at or above this subtotal are delivered free.
  final int freeDeliveryThresholdPaise;
  final int deliveryEtaMinutes;

  factory StoreSettings.fromMap(Map<String, dynamic> map) => StoreSettings(
        deliveryFeePaise: (map['deliveryFeePaise'] as num?)?.toInt() ??
            defaults.deliveryFeePaise,
        freeDeliveryThresholdPaise:
            (map['freeDeliveryThresholdPaise'] as num?)?.toInt() ??
                defaults.freeDeliveryThresholdPaise,
        deliveryEtaMinutes: (map['deliveryEtaMinutes'] as num?)?.toInt() ??
            defaults.deliveryEtaMinutes,
      );

  Map<String, dynamic> toMap() => {
        'deliveryFeePaise': deliveryFeePaise,
        'freeDeliveryThresholdPaise': freeDeliveryThresholdPaise,
        'deliveryEtaMinutes': deliveryEtaMinutes,
      };
}

/// Mirrors `riders/{id}`: a delivery partner. The delivery app will sign
/// riders in by this phone number.
@immutable
class Rider {
  const Rider({
    required this.id,
    required this.name,
    required this.phone,
    this.active = true,
  });

  /// Empty for a rider that has not been saved yet.
  final String id;
  final String name;
  final String phone;
  final bool active;

  Rider copyWith({String? id, bool? active}) => Rider(
        id: id ?? this.id,
        name: name,
        phone: phone,
        active: active ?? this.active,
      );

  factory Rider.fromMap(String id, Map<String, dynamic> map) => Rider(
        id: id,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        active: map['active'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'phone': phone, 'active': active};
}
