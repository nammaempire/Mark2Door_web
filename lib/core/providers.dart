import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fake_repositories.dart';
import '../data/firebase_repositories.dart';
import '../data/repositories.dart';
import '../features/dashboard/revenue_stats.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/storefront.dart';
import 'env.dart';

/// Composition root: the only place that knows which implementation backs
/// each interface.

/// Overridden in `main()`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final authRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  return Env.useFirebase
      ? FirebaseAdminAuthRepository(
          FirebaseAuth.instance,
          FirebaseFirestore.instance,
        )
      : FakeAdminAuthRepository(ref.watch(sharedPreferencesProvider));
});

final catalogRepositoryProvider = Provider<CatalogAdminRepository>((ref) {
  return Env.useFirebase
      ? FirestoreCatalogAdminRepository(FirebaseFirestore.instance)
      : FakeCatalogAdminRepository();
});

final ordersRepositoryProvider = Provider<OrdersAdminRepository>((ref) {
  return Env.useFirebase
      ? FirestoreOrdersAdminRepository(FirebaseFirestore.instance)
      : FakeOrdersAdminRepository();
});

final areasRepositoryProvider = Provider<ServiceAreaAdminRepository>((ref) {
  return Env.useFirebase
      ? FirestoreServiceAreaAdminRepository(FirebaseFirestore.instance)
      : FakeServiceAreaAdminRepository();
});

final authStateProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final productsProvider = StreamProvider<List<Product>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchProducts(),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchCategories(),
);

final storefrontRepositoryProvider = Provider<StorefrontAdminRepository>((ref) {
  return Env.useFirebase
      ? FirestoreStorefrontAdminRepository(FirebaseFirestore.instance)
      : FakeStorefrontAdminRepository();
});

final ridersRepositoryProvider = Provider<RidersAdminRepository>((ref) {
  return Env.useFirebase
      ? FirestoreRidersAdminRepository(FirebaseFirestore.instance)
      : FakeRidersAdminRepository();
});

final bannersProvider = StreamProvider<List<PromoBanner>>(
  (ref) => ref.watch(storefrontRepositoryProvider).watchBanners(),
);

final storeSettingsProvider = StreamProvider<StoreSettings>(
  (ref) => ref.watch(storefrontRepositoryProvider).watchSettings(),
);

final ridersProvider = StreamProvider<List<Rider>>(
  (ref) => ref.watch(ridersRepositoryProvider).watchRiders(),
);

final ordersProvider = StreamProvider<List<Order>>(
  (ref) => ref.watch(ordersRepositoryProvider).watchOrders(),
);

final areasProvider = StreamProvider<List<ServiceArea>>(
  (ref) => ref.watch(areasRepositoryProvider).watchAreas(),
);

/// Dashboard numbers, recomputed whenever the order stream emits.
final revenueStatsProvider = Provider<AsyncValue<RevenueStats>>((ref) {
  return ref
      .watch(ordersProvider)
      .whenData((orders) => RevenueStats.from(orders, DateTime.now()));
});
