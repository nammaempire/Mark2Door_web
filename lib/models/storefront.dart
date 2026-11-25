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
  // Brand reds and pinks.
  'maroon': [Color(0xFFA3203F), Color(0xFF5A0A1C)],
  'rose': [Color(0xFFE0607B), Color(0xFFA8243F)],
  'plum': [Color(0xFF8E2A5B), Color(0xFF55103A)],
  'berry': [Color(0xFFC2185B), Color(0xFF7A0F3A)],
  'coral': [Color(0xFFF0766A), Color(0xFFC23B4E)],
  'crimson': [Color(0xFFE53935), Color(0xFF9B1B1B)],
  'pink': [Color(0xFFF06292), Color(0xFFC2185B)],
  // Warm.
  'sunset': [Color(0xFFFF8A4C), Color(0xFFE0425A)],
  'orange': [Color(0xFFFF9838), Color(0xFFD9580F)],
  'amber': [Color(0xFFF2A91E), Color(0xFFC96F08)],
  'gold': [Color(0xFFD9A63A), Color(0xFF94661A)],
  'chocolate': [Color(0xFF8D5B43), Color(0xFF4E2C1E)],
  // Greens.
  'lime': [Color(0xFF8BC34A), Color(0xFF4F8A1D)],
  'green': [Color(0xFF43A862), Color(0xFF1B6B3A)],
  'forest': [Color(0xFF2E7D5B), Color(0xFF12402F)],
  'teal': [Color(0xFF26A69A), Color(0xFF0E6B62)],
  // Blues.
  'aqua': [Color(0xFF29B6D8), Color(0xFF0B7397)],
  'sky': [Color(0xFF4FA8F0), Color(0xFF1E66C2)],
  'blue': [Color(0xFF3F7BE0), Color(0xFF1C3F99)],
  'navy': [Color(0xFF34497A), Color(0xFF15203F)],
  // Purples.
  'indigo': [Color(0xFF5C6BC0), Color(0xFF2C3690)],
  'violet': [Color(0xFF8E5BD9), Color(0xFF512A9E)],
  'grape': [Color(0xFFAB47BC), Color(0xFF6A1B7A)],
  // Neutrals.
  'slate': [Color(0xFF607D8B), Color(0xFF30424B)],
  'charcoal': [Color(0xFF4A4A52), Color(0xFF1D1D22)],
};

/// Banner designs. Keys are stored in `banners/{id}.layout` and must match
/// `bannerLayouts` in the customer app, which draws the same designs.
const kBannerLayouts = <String, String>{
  'classic': 'Classic',
  'emojiLeft': 'Picture left',
  'centered': 'Centered',
  'spotlight': 'Spotlight',
  'offerTag': 'Offer tag',
  'watermark': 'Watermark',
  // Festival designs: animated 3D artwork with their own colours.
  'christmas': 'Christmas (3D)',
  'newYear': 'New Year (3D)',
  'pongal': 'Pongal (3D)',
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
    this.layout = 'classic',
    this.active = true,
    this.sortOrder = 0,
  });

  /// Empty for a banner that has not been saved yet.
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final String theme;

  /// Design key from [kBannerLayouts].
  final String layout;

  /// Category opened when the banner is tapped.
  final String categoryId;
  final bool active;
  final int sortOrder;

  /// Unknown or legacy theme keys fall back to maroon.
  List<Color> get colors =>
      kBannerThemes[theme] ?? kBannerThemes['maroon']!;

  PromoBanner copyWith({String? id, bool? active, int? sortOrder}) =>
      PromoBanner(
        id: id ?? this.id,
        title: title,
        subtitle: subtitle,
        emoji: emoji,
        theme: theme,
        layout: layout,
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
        theme: map['theme'] as String? ?? 'maroon',
        layout: map['layout'] as String? ?? 'classic',
        categoryId: map['categoryId'] as String? ?? '',
        active: map['active'] as bool? ?? true,
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'subtitle': subtitle,
        'emoji': emoji,
        'theme': theme,
        'layout': layout,
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
    this.handlingFeeEnabled = false,
    this.handlingFeePaise = 0,
    this.rainFeeEnabled = false,
    this.rainFeePaise = 0,
    this.storeName = '',
    this.storeAddress = '',
    this.supportEmail = '',
    this.courierFeePaise = 6000,
    this.courierFreeAbovePaise = 99900,
    this.courierEta = '3 to 5 days',
    this.paymentQrUrl = '',
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

  /// Extra charges the admin can switch on. A charge is added to every
  /// order, and shown to customers, only while it is enabled.
  final bool handlingFeeEnabled;
  final int handlingFeePaise;
  final bool rainFeeEnabled;
  final int rainFeePaise;

  /// Pickup point shown to riders in the delivery app.
  final String storeName;
  final String storeAddress;

  /// Shown on the customer app's help page; empty hides "Email us".
  final String supportEmail;

  /// Outstation (courier) orders: one flat charge, free at or above an
  /// order value, and the delivery time customers are told.
  final int courierFeePaise;
  final int courierFreeAbovePaise;
  final String courierEta;

  /// Link to a picture of the store's UPI QR code. The delivery app
  /// shows it to a cash-on-delivery customer who would rather pay by
  /// scanning. Empty hides that option.
  final String paymentQrUrl;

  factory StoreSettings.fromMap(Map<String, dynamic> map) => StoreSettings(
        deliveryFeePaise: (map['deliveryFeePaise'] as num?)?.toInt() ??
            defaults.deliveryFeePaise,
        freeDeliveryThresholdPaise:
            (map['freeDeliveryThresholdPaise'] as num?)?.toInt() ??
                defaults.freeDeliveryThresholdPaise,
        deliveryEtaMinutes: (map['deliveryEtaMinutes'] as num?)?.toInt() ??
            defaults.deliveryEtaMinutes,
        handlingFeeEnabled: map['handlingFeeEnabled'] as bool? ?? false,
        handlingFeePaise: (map['handlingFeePaise'] as num?)?.toInt() ?? 0,
        rainFeeEnabled: map['rainFeeEnabled'] as bool? ?? false,
        rainFeePaise: (map['rainFeePaise'] as num?)?.toInt() ?? 0,
        storeName: map['storeName'] as String? ?? '',
        storeAddress: map['storeAddress'] as String? ?? '',
        supportEmail: map['supportEmail'] as String? ?? '',
        courierFeePaise: (map['courierFeePaise'] as num?)?.toInt() ?? 6000,
        courierFreeAbovePaise:
            (map['courierFreeAbovePaise'] as num?)?.toInt() ?? 99900,
        courierEta: (map['courierEta'] as String? ?? '').trim().isEmpty
            ? '3 to 5 days'
            : (map['courierEta'] as String).trim(),
        paymentQrUrl: (map['paymentQrUrl'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toMap() => {
        'deliveryFeePaise': deliveryFeePaise,
        'freeDeliveryThresholdPaise': freeDeliveryThresholdPaise,
        'deliveryEtaMinutes': deliveryEtaMinutes,
        'handlingFeeEnabled': handlingFeeEnabled,
        'handlingFeePaise': handlingFeePaise,
        'rainFeeEnabled': rainFeeEnabled,
        'rainFeePaise': rainFeePaise,
        'storeName': storeName,
        'storeAddress': storeAddress,
        'supportEmail': supportEmail,
        'courierFeePaise': courierFeePaise,
        'courierFreeAbovePaise': courierFreeAbovePaise,
        'courierEta': courierEta,
        'paymentQrUrl': paymentQrUrl,
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
    this.storeId,
  });

  /// Empty for a rider that has not been saved yet.
  final String id;
  final String name;
  final String phone;
  final bool active;

  /// The store this rider delivers for; null with one shop.
  final String? storeId;

  Rider copyWith({String? id, bool? active}) => Rider(
        id: id ?? this.id,
        name: name,
        phone: phone,
        active: active ?? this.active,
        storeId: storeId,
      );

  factory Rider.fromMap(String id, Map<String, dynamic> map) => Rider(
        id: id,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        active: map['active'] as bool? ?? true,
        storeId: map['storeId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'active': active,
        'storeId': storeId,
      };
}

/// A question and answer on an app's help page (`faqs/{id}`). [app] says
/// which app shows it: the customer app or the delivery app.
@immutable
class Faq {
  const Faq({
    required this.id,
    required this.question,
    required this.answer,
    this.sortOrder = 0,
    this.app = customer,
  });

  static const customer = 'customer';
  static const delivery = 'delivery';

  /// Empty for a question that has not been saved yet.
  final String id;
  final String question;
  final String answer;
  final int sortOrder;

  /// [customer] or [delivery]. Questions saved before the delivery app
  /// had a help page have no value and belong to the customer app.
  final String app;

  Faq copyWith({String? id, int? sortOrder}) => Faq(
        id: id ?? this.id,
        question: question,
        answer: answer,
        sortOrder: sortOrder ?? this.sortOrder,
        app: app,
      );

  factory Faq.fromMap(String id, Map<String, dynamic> map) => Faq(
        id: id,
        question: map['question'] as String? ?? '',
        answer: map['answer'] as String? ?? '',
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
        app: map['app'] == delivery ? delivery : customer,
      );

  Map<String, dynamic> toMap() => {
        'question': question,
        'answer': answer,
        'sortOrder': sortOrder,
        'app': app,
      };
}

/// Terms and conditions or the privacy policy (`pages/{id}`), shown in the
/// customer app exactly as typed here.
@immutable
class LegalPage {
  const LegalPage({required this.id, required this.body, this.updatedAt});

  static const termsId = 'terms';
  static const privacyId = 'privacy';

  /// Shown in the delivery app, under Profile.
  static const deliveryTermsId = 'delivery_terms';
  static const deliveryPrivacyId = 'delivery_privacy';

  /// The customer app's pages.
  static const ids = [termsId, privacyId];

  /// The delivery app's pages.
  static const deliveryIds = [deliveryTermsId, deliveryPrivacyId];

  static bool isPrivacy(String id) =>
      id == privacyId || id == deliveryPrivacyId;

  static String titleOf(String id) => switch (id) {
        privacyId => 'Privacy policy',
        deliveryTermsId => 'Delivery partner terms',
        deliveryPrivacyId => 'Delivery partner privacy policy',
        _ => 'Terms and conditions',
      };

  final String id;
  final String body;
  final DateTime? updatedAt;

  String get title => titleOf(id);
}

/// Invite-and-earn terms; must match `ReferralRules` in the customer app.
abstract final class ReferralRules {
  static const List<int> milestones = [1, 3, 6, 10, 15];
  static const int rewardPaise = 2500;

  static int milestonesReached(int successfulInvites) =>
      milestones.where((m) => successfulInvites >= m).length;
}
