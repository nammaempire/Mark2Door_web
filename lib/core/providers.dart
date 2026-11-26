import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/stores/stores.dart';
import '../data/fake_repositories.dart';
import '../data/firebase_repositories.dart';
import '../data/repositories.dart';
import '../features/customers/customer_stats.dart';
import '../features/dashboard/revenue_stats.dart';
import '../features/reports/day_stats.dart';
import '../features/reports/sales_report.dart';
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

/// A store login reads only its own store's riders; the main admin
/// reads them all.
final _allRidersProvider = StreamProvider<List<Rider>>((ref) async* {
  final own = await ref.watch(adminStoreIdProvider.future);
  yield* ref.watch(ridersRepositoryProvider).watchRiders(storeId: own);
});

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

/// A store login reads only its own store's orders; the main admin
/// reads them all.
final _allOrdersProvider = StreamProvider<List<Order>>((ref) async* {
  final own = await ref.watch(adminStoreIdProvider.future);
  yield* ref.watch(ordersRepositoryProvider).watchOrders(storeId: own);
});

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

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return Env.useFirebase
      ? FirestoreStatsRepository(FirebaseFirestore.instance)
      : FakeStatsRepository(ref.watch(ordersRepositoryProvider));
});

/// The server's day totals for the dashboard: from the first of the month
/// five months back until today. A few hundred small records, whatever
/// the number of orders.
final _dashboardDaysProvider = StreamProvider<List<DayStats>>((ref) async* {
  final own = await ref.watch(adminStoreIdProvider.future);
  final now = DateTime.now();
  yield* ref.watch(statsRepositoryProvider).watchDays(
        DateTime(now.year, now.month - 5),
        now,
        storeId: own,
      );
});

/// Dashboard numbers. Revenue comes from the server's day totals, so it
/// covers every order; the count of orders still to deliver comes from
/// the live order list.
final revenueStatsProvider = Provider<AsyncValue<RevenueStats>>((ref) {
  final store = ref.watch(activeStoreIdProvider);
  final active = (ref.watch(ordersProvider).valueOrNull ?? const <Order>[])
      .where((o) => o.isActive)
      .length;
  return ref.watch(_dashboardDaysProvider).whenData(
        (days) => RevenueStats.fromDays(
          DayStats.forStore(days, store),
          DateTime.now(),
          activeOrders: active,
        ),
      );
});

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return Env.useFirebase
      ? FirestoreCustomersRepository(FirebaseFirestore.instance)
      : FakeCustomersRepository(ref.watch(ordersRepositoryProvider));
});

/// The store whose customers are on screen: a store login's own store,
/// or the one the main admin picked; null for every store.
final _customerStoreProvider = FutureProvider<String?>((ref) async {
  final own = await ref.watch(adminStoreIdProvider.future);
  return own ?? ref.watch(activeStoreIdProvider);
});

/// The biggest spenders of a month (all time when null), from the
/// server's customer records.
final topCustomersProvider = FutureProvider.autoDispose
    .family<List<CustomerSummary>, DateTime?>((ref, month) async {
  final store = await ref.watch(_customerStoreProvider.future);
  // Read again when an order arrives or changes.
  ref.watch(ordersProvider);
  return ref
      .watch(customersRepositoryProvider)
      .fetchTop(month: month, storeId: store);
});

/// A customer found by their full mobile number, for one who is not
/// among the biggest spenders on screen.
final customerByPhoneProvider = FutureProvider.autoDispose
    .family<CustomerSummary?, ({String phone, DateTime? month})>(
        (ref, key) async {
  final store = await ref.watch(_customerStoreProvider.future);
  return ref
      .watch(customersRepositoryProvider)
      .findByPhone(key.phone, month: key.month, storeId: store);
});

/// A customer's orders in a period, read when their row is opened.
final customerOrdersProvider = FutureProvider.autoDispose
    .family<List<Order>, ({String phone, DateTime? month})>((ref, key) async {
  final store = await ref.watch(_customerStoreProvider.future);
  return ref
      .watch(customersRepositoryProvider)
      .fetchOrders(key.phone, month: key.month, storeId: store);
});

/// A sales report for a period: totals from the server's day records,
/// and the period's orders (up to [reportOrderLimit]) for the table and
/// the export.
const reportOrderLimit = 3000;

final salesReportProvider = FutureProvider.autoDispose
    .family<SalesReport, ({DateTime from, DateTime to})>((ref, range) async {
  final own = await ref.watch(adminStoreIdProvider.future);
  final store = ref.watch(activeStoreIdProvider);
  // Run again when an order arrives or changes, so today stays current.
  ref.watch(ordersProvider);
  final days = await ref
      .watch(statsRepositoryProvider)
      .watchDays(range.from, range.to, storeId: own)
      .first;
  final orders = await ref.watch(ordersRepositoryProvider).fetchOrdersBetween(
        range.from,
        range.to,
        storeId: own ?? store,
        limit: reportOrderLimit,
      );
  return SalesReport.fromDays(
    DayStats.forStore(days, store),
    range.from,
    range.to,
    orders: orders,
    ordersCapped: orders.length >= reportOrderLimit,
  );
});
