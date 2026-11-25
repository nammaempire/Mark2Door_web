import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/stores/stores.dart';
import '../data/fake_repositories.dart';
import '../data/firebase_repositories.dart';
import '../data/repositories.dart';
import '../features/dashboard/revenue_stats.dart';
import '../models/coupon.dart';
import '../models/demand.dart';
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

/// Photo upload from this computer; null on sample data, where products
/// take photo links only.
final imageUploaderProvider = Provider<ImageUploader?>((ref) {
  return Env.useFirebase
      ? FirebaseImageUploader(FirebaseStorage.instance)
      : null;
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

final demandRepositoryProvider = Provider<DemandAdminRepository>((ref) {
  return Env.useFirebase
      ? FirestoreDemandAdminRepository(FirebaseFirestore.instance)
      : FakeDemandAdminRepository();
});

final pincodeRequestsProvider = StreamProvider<List<PincodeRequest>>(
  (ref) => ref.watch(demandRepositoryProvider).watchPincodeRequests(),
);

final searchMissesProvider = StreamProvider<List<SearchMiss>>(
  (ref) => ref.watch(demandRepositoryProvider).watchSearchMisses(),
);

final couponsRepositoryProvider = Provider<CouponsAdminRepository>((ref) {
  return Env.useFirebase
      ? FirestoreCouponsAdminRepository(FirebaseFirestore.instance)
      : FakeCouponsAdminRepository();
});

final couponsProvider = StreamProvider<List<Coupon>>(
  (ref) => ref.watch(couponsRepositoryProvider).watchCoupons(),
);

final bannersProvider = StreamProvider<List<PromoBanner>>(
  (ref) => ref.watch(storefrontRepositoryProvider).watchBanners(),
);

final contentRepositoryProvider = Provider<ContentAdminRepository>((ref) {
  return Env.useFirebase
      ? FirestoreContentAdminRepository(FirebaseFirestore.instance)
      : FakeContentAdminRepository();
});

final faqsProvider = StreamProvider<List<Faq>>(
  (ref) => ref.watch(contentRepositoryProvider).watchFaqs(),
);

final legalPagesProvider = StreamProvider<Map<String, LegalPage>>(
  (ref) => ref.watch(contentRepositoryProvider).watchPages(),
);

final storeSettingsProvider = StreamProvider<StoreSettings>(
  (ref) => ref.watch(storefrontRepositoryProvider).watchSettings(),
);

final _allRidersProvider = StreamProvider<List<Rider>>(
  (ref) => ref.watch(ridersRepositoryProvider).watchRiders(),
);

/// Riders of the store on screen (see [activeStoreIdProvider]); all
/// riders when no store is chosen.
final ridersProvider = Provider<AsyncValue<List<Rider>>>((ref) {
  final store = ref.watch(activeStoreIdProvider);
  return ref.watch(_allRidersProvider).whenData(
        (all) => store == null
            ? all
            : all.where((r) => r.storeId == store).toList(growable: false),
      );
});

final _allOrdersProvider = StreamProvider<List<Order>>(
  (ref) => ref.watch(ordersRepositoryProvider).watchOrders(),
);

/// Orders of the store on screen; every order when no store is chosen.
/// The dashboard, reports, customers and cash figures all read this, so
/// they follow the chosen store too.
final ordersProvider = Provider<AsyncValue<List<Order>>>((ref) {
  final store = ref.watch(activeStoreIdProvider);
  return ref.watch(_allOrdersProvider).whenData(
        (all) => store == null
            ? all
            : all.where((o) => o.storeId == store).toList(growable: false),
      );
});

final _allAreasProvider = StreamProvider<List<ServiceArea>>(
  (ref) => ref.watch(areasRepositoryProvider).watchAreas(),
);

/// Pincodes of the store on screen; every pincode when none is chosen.
final areasProvider = Provider<AsyncValue<List<ServiceArea>>>((ref) {
  final store = ref.watch(activeStoreIdProvider);
  return ref.watch(_allAreasProvider).whenData(
        (all) => store == null
            ? all
            : all.where((a) => a.storeId == store).toList(growable: false),
      );
});

/// Dashboard numbers, recomputed whenever the order stream emits.
final revenueStatsProvider = Provider<AsyncValue<RevenueStats>>((ref) {
  return ref
      .watch(ordersProvider)
      .whenData((orders) => RevenueStats.from(orders, DateTime.now()));
});
