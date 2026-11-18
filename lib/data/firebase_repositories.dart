// Newer cloud_firestore versions export their own `Order` type.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/storefront.dart';
import 'repositories.dart';

/// Email/password sign-in, restricted to accounts listed in `admins/{uid}`.
///
/// The `admins` check here is only for a friendly error message. The real
/// protection must be Firestore security rules that allow catalogue and
/// order writes only when `exists(/databases/$(db)/documents/admins/$(uid))`.
class FirebaseAdminAuthRepository implements AdminAuthRepository {
  FirebaseAdminAuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((user) => user?.email);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final admin = await _db.collection('admins').doc(result.user!.uid).get();
      if (!admin.exists) {
        await _auth.signOut();
        throw const AdminFailure('This account does not have admin access.');
      }
    } on FirebaseAuthException catch (e) {
      throw AdminFailure(switch (e.code) {
        'invalid-email' => 'That email address looks invalid.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'network-request-failed' => 'No internet connection.',
        _ => 'Incorrect email or password.',
      });
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class FirestoreCatalogAdminRepository implements CatalogAdminRepository {
  FirestoreCatalogAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  @override
  Stream<List<Product>> watchProducts() => _products
      .orderBy('nameLower')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => Product.fromMap(d.id, d.data()))
            .toList(growable: false),
      );

  @override
  Stream<List<Category>> watchCategories() => _db
      .collection('categories')
      .orderBy('name')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => Category.fromMap(d.id, d.data()))
            .toList(growable: false),
      );

  @override
  Future<void> saveCategory(Category category) {
    final col = _db.collection('categories');
    final doc = category.id.isEmpty ? col.doc() : col.doc(category.id);
    return doc.set(category.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    final used = await _products
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();
    if (used.docs.isNotEmpty) {
      throw const AdminFailure(
        'Products still use this category. Move or delete them first.',
      );
    }
    await _db.collection('categories').doc(categoryId).delete();
  }

  @override
  Future<void> saveProduct(Product product) {
    final doc = product.id.isEmpty
        ? _products.doc()
        : _products.doc(product.id);
    return doc.set(product.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> setInStock(String productId, {required bool inStock}) =>
      _products.doc(productId).update({'inStock': inStock});

  @override
  Future<void> deleteProduct(String productId) =>
      _products.doc(productId).delete();
}

class FirestoreOrdersAdminRepository implements OrdersAdminRepository {
  FirestoreOrdersAdminRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Order>> watchOrders() {
    // Bounded so the dashboard stays fast as history grows. For exact
    // long-range reporting, aggregate daily totals in a Cloud Function.
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(2000)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Order.fromMap(d.id, d.data()))
              .toList(growable: false),
        );
  }

  @override
  Future<void> updateStatus(String orderId, OrderStatus status) =>
      _db.collection('orders').doc(orderId).update({'status': status.name});

  @override
  Future<void> assignRider(String orderId, Rider? rider) =>
      _db.collection('orders').doc(orderId).update({
        'riderId': rider?.id,
        'riderName': rider?.name,
        'riderPhone': rider?.phone,
      });
}

class FirestoreServiceAreaAdminRepository
    implements ServiceAreaAdminRepository {
  FirestoreServiceAreaAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _areas =>
      _db.collection('service_areas');

  @override
  Stream<List<ServiceArea>> watchAreas() => _areas.snapshots().map(
    (snap) =>
        snap.docs
            .map(
              (d) => ServiceArea(
                pincode: d.id,
                active: d.data()['active'] as bool? ?? false,
              ),
            )
            .toList()
          ..sort((a, b) => a.pincode.compareTo(b.pincode)),
  );

  @override
  Future<void> addArea(String pincode) =>
      _areas.doc(pincode).set({'active': true});

  @override
  Future<void> setActive(String pincode, {required bool active}) =>
      _areas.doc(pincode).set({'active': active});

  @override
  Future<void> removeArea(String pincode) => _areas.doc(pincode).delete();
}

class FirestoreStorefrontAdminRepository implements StorefrontAdminRepository {
  FirestoreStorefrontAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _banners =>
      _db.collection('banners');
  DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings').doc('store');

  @override
  Stream<List<PromoBanner>> watchBanners() =>
      _banners.orderBy('sortOrder').snapshots().map(
            (snap) => snap.docs
                .map((d) => PromoBanner.fromMap(d.id, d.data()))
                .toList(growable: false),
          );

  @override
  Future<void> saveBanner(PromoBanner banner) async {
    if (banner.id.isNotEmpty) {
      return _banners.doc(banner.id).set(banner.toMap(), SetOptions(merge: true));
    }
    final last =
        await _banners.orderBy('sortOrder', descending: true).limit(1).get();
    final next = last.docs.isEmpty
        ? 0
        : ((last.docs.first.data()['sortOrder'] as num?)?.toInt() ?? 0) + 1;
    await _banners.doc().set(banner.copyWith(sortOrder: next).toMap());
  }

  @override
  Future<void> deleteBanner(String bannerId) => _banners.doc(bannerId).delete();

  @override
  Stream<StoreSettings> watchSettings() => _settings.snapshots().map((doc) {
        final data = doc.data();
        return data == null
            ? StoreSettings.defaults
            : StoreSettings.fromMap(data);
      });

  @override
  Future<void> saveSettings(StoreSettings settings) =>
      _settings.set(settings.toMap(), SetOptions(merge: true));
}

class FirestoreRidersAdminRepository implements RidersAdminRepository {
  FirestoreRidersAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _riders =>
      _db.collection('riders');

  @override
  Stream<List<Rider>> watchRiders() =>
      _riders.orderBy('name').snapshots().map(
            (snap) => snap.docs
                .map((d) => Rider.fromMap(d.id, d.data()))
                .toList(growable: false),
          );

  @override
  Future<void> saveRider(Rider rider) {
    final doc = rider.id.isEmpty ? _riders.doc() : _riders.doc(rider.id);
    return doc.set(rider.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteRider(String riderId) => _riders.doc(riderId).delete();
}
