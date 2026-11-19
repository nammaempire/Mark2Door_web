import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/storefront.dart';
import 'repositories.dart';

/// In-memory implementations so the console runs without a backend.
/// State lives for the browser session and resets on reload.

class _Store<T> {
  _Store(this.value);

  T value;
  final _changes = StreamController<void>.broadcast();

  void set(T next) {
    value = next;
    _changes.add(null);
  }

  Stream<T> watch() async* {
    yield value;
    yield* _changes.stream.map((_) => value);
  }
}

class FakeAdminAuthRepository implements AdminAuthRepository {
  FakeAdminAuthRepository(this._prefs)
    : _session = _Store(_prefs.getString(_key));

  static const _key = 'demo_admin_email';
  final SharedPreferences _prefs;
  final _Store<String?> _session;

  @override
  String? get currentEmail => _session.value;

  @override
  Stream<String?> authStateChanges() => _session.watch();

  @override
  Future<void> signIn({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (email.trim().toLowerCase() != AdminConfig.demoEmail ||
        password != AdminConfig.demoPassword) {
      throw const AdminFailure('Incorrect email or password.');
    }
    await _prefs.setString(_key, AdminConfig.demoEmail);
    _session.set(AdminConfig.demoEmail);
  }

  @override
  Future<void> signOut() async {
    await _prefs.remove(_key);
    _session.set(null);
  }
}

class FakeCatalogAdminRepository implements CatalogAdminRepository {
  static const categories = <Category>[
    Category(id: 'fruits', name: 'Fruits & Veg', icon: 'fruits'),
    Category(id: 'dairy', name: 'Dairy & Eggs', icon: 'dairy'),
    Category(id: 'staples', name: 'Atta, Rice & Dal', icon: 'staples'),
    Category(id: 'snacks', name: 'Snacks', icon: 'snacks'),
    Category(id: 'beverages', name: 'Beverages', icon: 'beverages'),
    Category(id: 'household', name: 'Household', icon: 'household'),
  ];

  /// Same sample catalogue as the customer app.
  static const seed = <Product>[
    Product(
      id: 'p01',
      emoji: '🍌',
      name: 'Banana Robusta',
      categoryId: 'fruits',
      unit: '6 pcs',
      pricePaise: 4200,
      mrpPaise: 5000,
    ),
    Product(
      id: 'p02',
      emoji: '🍅',
      name: 'Tomato Local',
      categoryId: 'fruits',
      unit: '500 g',
      pricePaise: 1800,
      mrpPaise: 2400,
    ),
    Product(
      id: 'p03',
      emoji: '🧅',
      name: 'Onion',
      categoryId: 'fruits',
      unit: '1 kg',
      pricePaise: 3500,
      mrpPaise: 4500,
    ),
    Product(
      id: 'p04',
      emoji: '🍎',
      name: 'Apple Shimla',
      categoryId: 'fruits',
      unit: '4 pcs',
      pricePaise: 12900,
      mrpPaise: 16000,
    ),
    Product(
      id: 'p05',
      emoji: '🥛',
      name: 'Toned Milk',
      categoryId: 'dairy',
      unit: '500 ml',
      pricePaise: 2700,
      mrpPaise: 2700,
    ),
    Product(
      id: 'p06',
      emoji: '🥣',
      name: 'Fresh Curd',
      categoryId: 'dairy',
      unit: '400 g',
      pricePaise: 3500,
      mrpPaise: 4000,
    ),
    Product(
      id: 'p07',
      emoji: '🥚',
      name: 'Farm Eggs',
      categoryId: 'dairy',
      unit: '6 pcs',
      pricePaise: 4800,
      mrpPaise: 5400,
    ),
    Product(
      id: 'p08',
      emoji: '🧈',
      name: 'Salted Butter',
      categoryId: 'dairy',
      unit: '100 g',
      pricePaise: 5800,
      mrpPaise: 6000,
      inStock: false,
    ),
    Product(
      id: 'p09',
      emoji: '🌾',
      name: 'Chakki Atta',
      categoryId: 'staples',
      unit: '5 kg',
      pricePaise: 23900,
      mrpPaise: 28500,
    ),
    Product(
      id: 'p10',
      emoji: '🍚',
      name: 'Sona Masoori Rice',
      categoryId: 'staples',
      unit: '5 kg',
      pricePaise: 34900,
      mrpPaise: 42000,
    ),
    Product(
      id: 'p11',
      emoji: '🫘',
      name: 'Toor Dal',
      categoryId: 'staples',
      unit: '1 kg',
      pricePaise: 15900,
      mrpPaise: 18500,
    ),
    Product(
      id: 'p12',
      emoji: '🌻',
      name: 'Sunflower Oil',
      categoryId: 'staples',
      unit: '1 L',
      pricePaise: 13900,
      mrpPaise: 16500,
    ),
    Product(
      id: 'p13',
      emoji: '🥔',
      name: 'Potato Chips',
      categoryId: 'snacks',
      unit: '90 g',
      pricePaise: 3000,
      mrpPaise: 3500,
    ),
    Product(
      id: 'p14',
      emoji: '🍪',
      name: 'Marie Biscuits',
      categoryId: 'snacks',
      unit: '250 g',
      pricePaise: 3500,
      mrpPaise: 4000,
    ),
    Product(
      id: 'p15',
      emoji: '🥜',
      name: 'Masala Peanuts',
      categoryId: 'snacks',
      unit: '200 g',
      pricePaise: 5500,
      mrpPaise: 6500,
    ),
    Product(
      id: 'p16',
      emoji: '🍵',
      name: 'Assam Tea',
      categoryId: 'beverages',
      unit: '250 g',
      pricePaise: 12500,
      mrpPaise: 14500,
    ),
    Product(
      id: 'p17',
      emoji: '☕',
      name: 'Filter Coffee',
      categoryId: 'beverages',
      unit: '200 g',
      pricePaise: 14900,
      mrpPaise: 17000,
    ),
    Product(
      id: 'p18',
      emoji: '🍊',
      name: 'Orange Juice',
      categoryId: 'beverages',
      unit: '1 L',
      pricePaise: 9900,
      mrpPaise: 12000,
    ),
    Product(
      id: 'p19',
      emoji: '🧴',
      name: 'Dishwash Liquid',
      categoryId: 'household',
      unit: '500 ml',
      pricePaise: 9900,
      mrpPaise: 11500,
    ),
    Product(
      id: 'p20',
      emoji: '🧺',
      name: 'Detergent Powder',
      categoryId: 'household',
      unit: '1 kg',
      pricePaise: 11900,
      mrpPaise: 14000,
    ),
  ];

  final _products = _Store<List<Product>>(List.of(seed));
  final _categories = _Store<List<Category>>(List.of(categories));
  int _seq = 100;

  @override
  Stream<List<Product>> watchProducts() => _products.watch();

  @override
  Stream<List<Category>> watchCategories() => _categories.watch();

  @override
  Future<void> saveCategory(Category category) async {
    final list = List.of(_categories.value);
    if (category.id.isEmpty) {
      list.add(category.copyWith(id: 'c${++_seq}'));
    } else {
      final i = list.indexWhere((c) => c.id == category.id);
      if (i == -1) throw const AdminFailure('That category no longer exists.');
      list[i] = category;
    }
    _categories.set(list);
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    final used = _products.value.where((p) => p.categoryId == categoryId).length;
    if (used > 0) {
      throw AdminFailure(
        '$used product${used == 1 ? '' : 's'} still use this category. '
        'Move or delete them first.',
      );
    }
    _categories.set(_categories.value.where((c) => c.id != categoryId).toList());
  }

  @override
  Future<void> saveProduct(Product product) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final list = List.of(_products.value);
    if (product.id.isEmpty) {
      list.insert(0, product.copyWith(id: 'p${++_seq}'));
    } else {
      final i = list.indexWhere((p) => p.id == product.id);
      if (i == -1) throw const AdminFailure('That product no longer exists.');
      list[i] = product;
    }
    _products.set(list);
  }

  @override
  Future<void> setInStock(String productId, {required bool inStock}) async {
    _products.set([
      for (final p in _products.value)
        p.id == productId ? p.copyWith(inStock: inStock) : p,
    ]);
  }

  @override
  Future<void> deleteProduct(String productId) async {
    _products.set(_products.value.where((p) => p.id != productId).toList());
  }
}

class FakeOrdersAdminRepository implements OrdersAdminRepository {
  FakeOrdersAdminRepository({DateTime? now})
    : _orders = _Store(_generate(now ?? DateTime.now()));

  final _Store<List<Order>> _orders;

  @override
  Stream<List<Order>> watchOrders() => _orders.watch();

  @override
  Future<void> updateStatus(String orderId, OrderStatus status) async {
    _orders.set([
      for (final o in _orders.value)
        o.id == orderId ? o.copyWith(status: status) : o,
    ]);
  }

  @override
  Future<void> assignRider(String orderId, Rider? rider) async {
    _orders.set([
      for (final o in _orders.value)
        o.id == orderId
            ? o.withRider(id: rider?.id, name: rider?.name, phone: rider?.phone)
            : o,
    ]);
  }

  static const _customers = [
    (
      'Ananya Rao',
      '9845012345',
      '14, 2nd Main, Koramangala 4th Block',
      '560034',
    ),
    (
      'Rahul Shetty',
      '9900123456',
      '7, Wind Tunnel Road, Murugeshpalya',
      '560038',
    ),
    (
      'Meera Iyer',
      '9741098765',
      '221, 5th Cross, HSR Layout Sector 2',
      '560102',
    ),
    ('Imran Khan', '9880456123', '3, Residency Road', '560001'),
    ('Divya Nair', '9538011223', '45, Hosur Main Road, Bommanahalli', '560068'),
    ('Karthik Gowda', '9620334455', '18, 80 Feet Road, Koramangala', '560034'),
  ];

  /// About six months of plausible history. Seeded, so every reload shows
  /// the same shape of data relative to today.
  static List<Order> _generate(DateTime now) {
    final rnd = Random(42);
    const catalog = FakeCatalogAdminRepository.seed;
    final orders = <Order>[];
    var seq = 1000;

    for (var daysAgo = 180; daysAgo >= 0; daysAgo--) {
      final day = DateTime(now.year, now.month, now.day - daysAgo);
      final weekend = day.weekday >= DateTime.saturday;
      // Gentle growth over time plus a weekend bump.
      final count =
          1 +
          ((180 - daysAgo) / 45).floor() +
          rnd.nextInt(3) +
          (weekend ? 2 : 0);

      for (var n = 0; n < count; n++) {
        final at = day.add(
          Duration(hours: 8 + rnd.nextInt(13), minutes: rnd.nextInt(60)),
        );
        if (at.isAfter(now)) continue;

        final items = <OrderItem>[];
        final picks = <int>{};
        final lines = 1 + rnd.nextInt(4);
        while (picks.length < lines) {
          picks.add(rnd.nextInt(catalog.length));
        }
        for (final i in picks) {
          final p = catalog[i];
          items.add(
            OrderItem(
              productId: p.id,
              name: p.name,
              unit: p.unit,
              pricePaise: p.pricePaise,
              quantity: 1 + rnd.nextInt(3),
            ),
          );
        }
        final subtotal = items.fold(0, (s, i) => s + i.lineTotalPaise);
        final fee = subtotal >= 49900 ? 0 : 3000;
        final customer = _customers[rnd.nextInt(_customers.length)];
        final online = rnd.nextInt(10) < 6;
        final roll = rnd.nextInt(100);

        var status = OrderStatus.delivered;
        var payment = online ? PaymentStatus.paid : PaymentStatus.pending;
        if (roll < 5) {
          status = OrderStatus.cancelled;
          if (online) payment = PaymentStatus.failed;
        } else if (daysAgo == 0) {
          final minutesOld = now.difference(at).inMinutes;
          status = minutesOld < 20
              ? OrderStatus.placed
              : minutesOld < 45
              ? OrderStatus.accepted
              : minutesOld < 90
              ? OrderStatus.pickedUp
              : OrderStatus.delivered;
        }

        orders.add(
          Order(
            id: 'M2D${++seq}',
            items: items,
            subtotalPaise: subtotal,
            deliveryFeePaise: fee,
            totalPaise: subtotal + fee,
            address: Address(
              name: customer.$1,
              phone: customer.$2,
              line1: customer.$3,
              landmark: '',
              pincode: customer.$4,
            ),
            paymentMethod: online ? PaymentMethod.online : PaymentMethod.cod,
            paymentStatus: payment,
            status: status,
            createdAt: at,
          ),
        );
      }
    }

    // Always include a few live orders, whatever the time of day, so status
    // changes and rider assignment can be tried in sample-data mode.
    const live = [
      (5, OrderStatus.placed, null, null, null),
      (14, OrderStatus.placed, null, null, null),
      (32, OrderStatus.accepted, 'r1', 'Suresh Kumar', '9900011111'),
      (58, OrderStatus.pickedUp, 'r2', 'Manjunath R', '9900022222'),
    ];
    for (final (i, entry) in live.indexed) {
      final product = catalog[(i * 5 + 1) % catalog.length];
      final customer = _customers[i % _customers.length];
      final subtotal = product.pricePaise * 2;
      orders.add(
        Order(
          id: 'M2D${++seq}',
          items: [
            OrderItem(
              productId: product.id,
              name: product.name,
              unit: product.unit,
              pricePaise: product.pricePaise,
              quantity: 2,
            ),
          ],
          subtotalPaise: subtotal,
          deliveryFeePaise: 3000,
          totalPaise: subtotal + 3000,
          address: Address(
            name: customer.$1,
            phone: customer.$2,
            line1: customer.$3,
            landmark: '',
            pincode: customer.$4,
          ),
          paymentMethod: PaymentMethod.cod,
          paymentStatus: PaymentStatus.pending,
          status: entry.$2,
          createdAt: now.subtract(Duration(minutes: entry.$1)),
          riderId: entry.$3,
          riderName: entry.$4,
          riderPhone: entry.$5,
        ),
      );
    }

    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }
}

class FakeServiceAreaAdminRepository implements ServiceAreaAdminRepository {
  final _areas = _Store<List<ServiceArea>>(const [
    ServiceArea(pincode: '560001', active: true),
    ServiceArea(pincode: '560034', active: true),
    ServiceArea(pincode: '560038', active: true),
    ServiceArea(pincode: '560068', active: true),
    ServiceArea(pincode: '560102', active: true),
  ]);

  @override
  Stream<List<ServiceArea>> watchAreas() => _areas.watch();

  @override
  Future<void> addArea(String pincode) async {
    final rest = _areas.value.where((a) => a.pincode != pincode);
    _areas.set(
      [...rest, ServiceArea(pincode: pincode, active: true)]
        ..sort((a, b) => a.pincode.compareTo(b.pincode)),
    );
  }

  @override
  Future<void> setActive(String pincode, {required bool active}) async {
    _areas.set([
      for (final a in _areas.value)
        a.pincode == pincode
            ? ServiceArea(pincode: pincode, active: active)
            : a,
    ]);
  }

  @override
  Future<void> removeArea(String pincode) async {
    _areas.set(_areas.value.where((a) => a.pincode != pincode).toList());
  }
}

class FakeStorefrontAdminRepository implements StorefrontAdminRepository {
  /// Same three banners the customer app ships with.
  final _banners = _Store<List<PromoBanner>>(const [
    PromoBanner(id: 'b1', title: 'Farm fresh\nfruits & veggies', subtitle: 'Up to 25% off today', emoji: '🥦', theme: 'maroon', categoryId: 'fruits', sortOrder: 0),
    PromoBanner(id: 'b2', title: 'Monthly staples\nat mart prices', subtitle: 'Atta, rice, dal and oil', emoji: '🛒', theme: 'rose', categoryId: 'staples', sortOrder: 1),
    PromoBanner(id: 'b3', title: 'Snack time\nfavourites', subtitle: 'Chips, biscuits and more', emoji: '🍿', theme: 'plum', categoryId: 'snacks', sortOrder: 2),
  ]);
  final _settings = _Store<StoreSettings>(StoreSettings.defaults);
  int _seq = 10;

  @override
  Stream<List<PromoBanner>> watchBanners() => _banners.watch();

  @override
  Future<void> saveBanner(PromoBanner banner) async {
    final list = List.of(_banners.value);
    if (banner.id.isEmpty) {
      final last = list.fold(-1, (m, b) => b.sortOrder > m ? b.sortOrder : m);
      list.add(banner.copyWith(id: 'b${++_seq}', sortOrder: last + 1));
    } else {
      final i = list.indexWhere((b) => b.id == banner.id);
      if (i == -1) throw const AdminFailure('That banner no longer exists.');
      list[i] = banner;
    }
    _banners.set(list..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
  }

  @override
  Future<void> deleteBanner(String bannerId) async {
    _banners.set(_banners.value.where((b) => b.id != bannerId).toList());
  }

  @override
  Stream<StoreSettings> watchSettings() => _settings.watch();

  @override
  Future<void> saveSettings(StoreSettings settings) async =>
      _settings.set(settings);
}

class FakeRidersAdminRepository implements RidersAdminRepository {
  final _riders = _Store<List<Rider>>(const [
    Rider(id: 'r1', name: 'Suresh Kumar', phone: '9900011111'),
    Rider(id: 'r2', name: 'Manjunath R', phone: '9900022222'),
    Rider(id: 'r3', name: 'Abdul Rahman', phone: '9900033333', active: false),
  ]);
  int _seq = 10;

  @override
  Stream<List<Rider>> watchRiders() => _riders.watch();

  @override
  Future<void> saveRider(Rider rider) async {
    final list = List.of(_riders.value);
    if (rider.id.isEmpty) {
      list.add(rider.copyWith(id: 'r${++_seq}'));
    } else {
      final i = list.indexWhere((r) => r.id == rider.id);
      if (i == -1) throw const AdminFailure('That rider no longer exists.');
      list[i] = rider;
    }
    _riders.set(list);
  }

  @override
  Future<void> deleteRider(String riderId) async {
    _riders.set(_riders.value.where((r) => r.id != riderId).toList());
  }
}
