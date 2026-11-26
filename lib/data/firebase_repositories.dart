// Newer cloud_firestore versions export their own `Order` type.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/coupon.dart';
import '../models/demand.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/storefront.dart';
import 'image_upload.dart';
import '../core/photo_shrink.dart';
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
  Stream<List<Product>> watchProducts() =>
      _products.orderBy('nameLower').snapshots().map(
            (snap) => snap.docs
                .map((d) => Product.fromMap(d.id, d.data()))
                .toList(growable: false),
          );

  @override
  Stream<List<Category>> watchCategories() =>
      _db.collection('categories').orderBy('name').snapshots().map(
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
    final doc =
        product.id.isEmpty ? _products.doc() : _products.doc(product.id);
    return doc.set(product.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> setInStock(String productId, {required bool inStock}) =>
      _products.doc(productId).update({'inStock': inStock});

  @override
  Future<void> setStoreStock(
    String productId,
    String storeId, {
    required bool inStock,
    required int? stockQty,
  }) =>
      _products.doc(productId).update({
        'storeStock.$storeId': {'inStock': inStock, 'stockQty': stockQty},
      });

  @override
  Future<void> deleteProduct(String productId) =>
      _products.doc(productId).delete();
}

class FirestoreOrdersAdminRepository implements OrdersAdminRepository {
  FirestoreOrdersAdminRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<List<Order>> fetchOrdersBetween(
    DateTime from,
    DateTime to, {
    String? storeId,
    int limit = 3000,
  }) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day + 1);
    Query<Map<String, dynamic>> orders = _db.collection('orders');
    if (storeId != null) orders = orders.where('storeId', isEqualTo: storeId);
    final snap = await orders
        .where('createdAt',
            isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
        .where('createdAt', isLessThan: end.millisecondsSinceEpoch)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final d in snap.docs) Order.fromMap(d.id, d.data())];
  }

  @override
  Stream<List<Order>> watchOrders({String? storeId}) {
    // Bounded so the dashboard stays fast as history grows. For exact
    // long-range reporting, aggregate daily totals in a Cloud Function.
    Query<Map<String, dynamic>> orders = _db.collection('orders');
    // A store login may read only its own store's orders, and the rules
    // refuse a query that could return any others.
    if (storeId != null) orders = orders.where('storeId', isEqualTo: storeId);
    return orders
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
  Future<void> shipOrder(
    String orderId, {
    required String courier,
    required String tracking,
  }) =>
      _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.pickedUp.name,
        'courierName': courier.trim(),
        'trackingNumber': tracking.trim(),
      });

  @override
  Future<void> assignRider(String orderId, Rider? rider) =>
      _db.collection('orders').doc(orderId).update({
        'riderId': rider?.id,
        'riderName': rider?.name,
        'riderPhone': rider?.phone,
        // Starts the five-minute clock for the rider to accept.
        'assignedAt':
            rider == null ? null : DateTime.now().millisecondsSinceEpoch,
      });

  @override
  Future<void> markCashReceived(String riderId) async {
    final delivered = await _db
        .collection('orders')
        .where('riderId', isEqualTo: riderId)
        .where('status', isEqualTo: OrderStatus.delivered.name)
        .get();
    final holding = delivered.docs
        .where((d) => Order.fromMap(d.id, d.data()).cashWithRider)
        .toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    // A batch takes at most 500 writes.
    for (var i = 0; i < holding.length; i += 400) {
      final batch = _db.batch();
      for (final doc in holding.skip(i).take(400)) {
        batch.update(doc.reference, {
          'cashHandedOver': true,
          'cashHandedOverAt': now,
        });
      }
      await batch.commit();
    }
  }

  @override
  Future<void> markRefunded(String orderId) => _db
      .collection('orders')
      .doc(orderId)
      .update({'paymentStatus': PaymentStatus.refunded.name});
}

class FirestoreServiceAreaAdminRepository
    implements ServiceAreaAdminRepository {
  FirestoreServiceAreaAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _areas =>
      _db.collection('service_areas');

  @override
  Stream<List<ServiceArea>> watchAreas() => _areas.snapshots().map(
        (snap) => snap.docs
            .map(
              (d) => ServiceArea(
                pincode: d.id,
                active: d.data()['active'] as bool? ?? false,
                name: (d.data()['name'] as String? ?? '').trim(),
                storeId: d.data()['storeId'] as String?,
              ),
            )
            .toList()
          ..sort((a, b) => a.pincode.compareTo(b.pincode)),
      );

  @override
  Future<void> addArea(String pincode, {String name = '', String? storeId}) =>
      _areas.doc(pincode).set({
        'active': true,
        'name': name.trim(),
        'storeId': storeId,
      });

  @override
  Future<void> setActive(String pincode, {required bool active}) =>
      // Merged, so the area name is kept.
      _areas.doc(pincode).set({'active': active}, SetOptions(merge: true));

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
      return _banners
          .doc(banner.id)
          .set(banner.toMap(), SetOptions(merge: true));
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
  Stream<List<Rider>> watchRiders({String? storeId}) => storeId == null
      ? _riders.orderBy('name').snapshots().map(
            (snap) => snap.docs
                .map((d) => Rider.fromMap(d.id, d.data()))
                .toList(growable: false),
          )
      // Sorted here, so a store login needs no extra database index.
      : _riders.where('storeId', isEqualTo: storeId).snapshots().map(
            (snap) => snap.docs
                .map((d) => Rider.fromMap(d.id, d.data()))
                .toList(growable: false)
              ..sort(
                (a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ),
          );

  @override
  Future<void> saveRider(Rider rider) {
    final doc = rider.id.isEmpty ? _riders.doc() : _riders.doc(rider.id);
    return doc.set(rider.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteRider(String riderId) => _riders.doc(riderId).delete();
}

/// Collections `pincode_requests` and `search_misses`, written by the
/// customer app as running counts.
class FirestoreDemandAdminRepository implements DemandAdminRepository {
  FirestoreDemandAdminRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<PincodeRequest>> watchPincodeRequests() =>
      _db.collection('pincode_requests').snapshots().map(
            (snap) => snap.docs
                .map((d) => PincodeRequest.fromMap(d.id, d.data()))
                .toList()
              ..sort((a, b) => b.count.compareTo(a.count)),
          );

  @override
  Stream<List<SearchMiss>> watchSearchMisses() =>
      _db.collection('search_misses').snapshots().map(
            (snap) => snap.docs
                .map((d) => SearchMiss.fromMap(d.id, d.data()))
                .toList()
              ..sort((a, b) => b.count.compareTo(a.count)),
          );

  @override
  Future<void> removePincodeRequest(String pincode) =>
      _db.collection('pincode_requests').doc(pincode).delete();

  @override
  Future<void> removeSearchMiss(String id) =>
      _db.collection('search_misses').doc(id).delete();
}

/// Collection: `coupons/{CODE}`. The customer app reads a coupon by its
/// code, so the code is the document id.
class FirestoreCouponsAdminRepository implements CouponsAdminRepository {
  FirestoreCouponsAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coupons =>
      _db.collection('coupons');

  @override
  Stream<List<Coupon>> watchCoupons() => _coupons.snapshots().map(
        (snap) => snap.docs
            .map((d) => Coupon.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => a.code.compareTo(b.code)),
      );

  @override
  Future<void> saveCoupon(Coupon coupon) =>
      _coupons.doc(coupon.code).set(coupon.toMap(), SetOptions(merge: true));

  @override
  Future<void> setActive(String code, {required bool active}) =>
      _coupons.doc(code).update({'active': active});

  @override
  Future<void> deleteCoupon(String code) => _coupons.doc(code).delete();
}

/// Stores product photos in Firebase Storage under `products/` and returns
/// their download links. Needs Storage enabled on the Firebase project.
class FirebaseImageUploader implements ImageUploader {
  FirebaseImageUploader(this._storage);

  final FirebaseStorage _storage;

  /// The largest photo that may be chosen. It is made smaller before it
  /// is sent, so a photo straight from a phone camera is fine.
  static const maxPickBytes = 12 * 1024 * 1024;

  /// The largest file the storage rules accept.
  static const maxBytes = 2 * 1024 * 1024;
  static const _types = {'image/png', 'image/jpeg', 'image/webp'};

  @override
  Future<String?> pickAndUpload() async {
    final picked = await pickImageFile();
    if (picked == null) return null;
    if (!_types.contains(picked.mimeType)) {
      throw const AdminFailure('Choose a PNG, JPG or WebP image.');
    }
    if (picked.bytes.length > maxPickBytes) {
      throw const AdminFailure(
          'That image is over 12 MB. Choose a smaller one.');
    }
    // Stored no larger than a phone needs: quicker for customers to
    // load and cheaper to send.
    final small = await shrinkPhoto(picked.bytes, picked.mimeType);
    if (small.bytes.length > maxBytes) {
      throw const AdminFailure(
          'That image is over 2 MB. Choose a smaller one.');
    }
    final base = picked.name
        .replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final extension = switch (small.mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final image = (
      name: '$base.$extension',
      mimeType: small.mimeType,
      bytes: small.bytes,
    );
    final ref = _storage
        .ref('products/${DateTime.now().millisecondsSinceEpoch}_${image.name}');
    try {
      await ref.putData(
        image.bytes,
        SettableMetadata(
          contentType: image.mimeType,
          // Photos never change once uploaded, so phones may cache them.
          cacheControl: 'public, max-age=31536000',
        ),
      );
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw AdminFailure(switch (e.code) {
        'unauthorized' =>
          "Upload isn't allowed. Check that Storage is set up and its "
              'rules are deployed.',
        'bucket-not-found' ||
        'project-not-found' =>
          'Firebase Storage is not enabled for this project yet.',
        _ => "Couldn't upload that image. Try again.",
      });
    }
  }
}

class FirestoreContentAdminRepository implements ContentAdminRepository {
  FirestoreContentAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _faqs => _db.collection('faqs');
  CollectionReference<Map<String, dynamic>> get _pages =>
      _db.collection('pages');

  @override
  Stream<List<Faq>> watchFaqs() => _faqs.orderBy('sortOrder').snapshots().map(
        (snap) => snap.docs
            .map((d) => Faq.fromMap(d.id, d.data()))
            .toList(growable: false),
      );

  @override
  Future<void> saveFaq(Faq faq) async {
    if (faq.id.isNotEmpty) {
      await _faqs.doc(faq.id).set(faq.toMap(), SetOptions(merge: true));
      return;
    }
    // New questions go to the end.
    final last =
        await _faqs.orderBy('sortOrder', descending: true).limit(1).get();
    final next = last.docs.isEmpty
        ? 0
        : ((last.docs.first.data()['sortOrder'] as num?)?.toInt() ?? 0) + 1;
    await _faqs.add(faq.copyWith(sortOrder: next).toMap());
  }

  @override
  Future<void> deleteFaq(String faqId) => _faqs.doc(faqId).delete();

  @override
  Stream<Map<String, LegalPage>> watchPages() => _pages.snapshots().map(
        (snap) => {
          for (final d in snap.docs)
            if ((d.data()['body'] as String? ?? '').trim().isNotEmpty)
              d.id: LegalPage(
                id: d.id,
                body: d.data()['body'] as String,
                updatedAt: d.data()['updatedAt'] == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        (d.data()['updatedAt'] as num).toInt(),
                      ),
              ),
        },
      );

  @override
  Future<void> savePage(String pageId, String body) => _pages.doc(pageId).set({
        'body': body,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  @override
  Future<void> deletePage(String pageId) => _pages.doc(pageId).delete();
}
