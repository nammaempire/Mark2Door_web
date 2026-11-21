// Newer cloud_firestore versions export their own `Order` type.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/coupon.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/storefront.dart';
import 'image_upload.dart';
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

  @override
  Future<void> settle(Order order) async {
    if (!order.needsSettlement || order.userId.isEmpty) return;
    final orderRef = _db.collection('orders').doc(order.id);

    // Only a customer's first delivered order can earn their inviter a
    // reward. Looked up before the transaction, which cannot run queries.
    var firstDelivered = true;
    if (order.status == OrderStatus.delivered) {
      final delivered = await _db
          .collection('orders')
          .where('userId', isEqualTo: order.userId)
          .where('status', isEqualTo: OrderStatus.delivered.name)
          .limit(2)
          .get();
      firstDelivered = delivered.docs.every((d) => d.id == order.id);
    }

    await _db.runTransaction((tx) async {
      // Re-read inside the transaction so two open consoles cannot both
      // pay the same reward or refund.
      final fresh =
          Order.fromMap(order.id, (await tx.get(orderRef)).data() ?? {});
      if (!fresh.needsSettlement) return;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (fresh.status == OrderStatus.delivered) {
        final referralRef = _db.collection('referrals').doc(fresh.userId);
        final referral = (await tx.get(referralRef)).data();
        if (referral != null && referral['status'] == 'joined') {
          final referrer = referral['referrerUid'] as String? ?? '';
          if (!firstDelivered || referrer.isEmpty) {
            tx.update(
                referralRef, {'status': 'ineligible', 'completedAt': now});
          } else {
            final walletRef = _db.collection('wallets').doc(referrer);
            final wallet = (await tx.get(walletRef)).data() ?? const {};
            final invites =
                ((wallet['successfulInvites'] as num?)?.toInt() ?? 0) + 1;
            final rewarded =
                (wallet['rewardedMilestones'] as num?)?.toInt() ?? 0;
            final reached = ReferralRules.milestonesReached(invites);
            final due = reached > rewarded ? reached - rewarded : 0;
            tx.set(
              walletRef,
              {
                'balancePaise':
                    ((wallet['balancePaise'] as num?)?.toInt() ?? 0) +
                        due * ReferralRules.rewardPaise,
                'successfulInvites': invites,
                'rewardedMilestones': rewarded + due,
                'updatedAt': now,
              },
              SetOptions(merge: true),
            );
            for (var i = 0; i < due; i++) {
              tx.set(walletRef.collection('transactions').doc(), {
                'amountPaise': ReferralRules.rewardPaise,
                'type': 'referral_reward',
                'note': 'Invite reward: $invites '
                    '${invites == 1 ? 'friend has' : 'friends have'} ordered',
                'orderId': fresh.id,
                'createdAt': now + i,
              });
            }
            tx.update(referralRef, {'status': 'ordered', 'completedAt': now});
          }
        }
        tx.update(orderRef, {'referralChecked': true});
      } else {
        // Cancelled with wallet money on it: give the money back.
        final walletRef = _db.collection('wallets').doc(fresh.userId);
        final wallet = (await tx.get(walletRef)).data() ?? const {};
        tx.set(
          walletRef,
          {
            'balancePaise': ((wallet['balancePaise'] as num?)?.toInt() ?? 0) +
                fresh.walletAppliedPaise,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
        tx.set(walletRef.collection('transactions').doc(), {
          'amountPaise': fresh.walletAppliedPaise,
          'type': 'order_refund',
          'note': 'Returned from cancelled order ${fresh.displayId}',
          'orderId': fresh.id,
          'createdAt': now,
        });
        tx.update(orderRef, {'walletRefunded': true});
      }
    });
  }
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
  Stream<List<Rider>> watchRiders() => _riders.orderBy('name').snapshots().map(
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

  static const maxBytes = 2 * 1024 * 1024;
  static const _types = {'image/png', 'image/jpeg', 'image/webp'};

  @override
  Future<String?> pickAndUpload() async {
    final image = await pickImageFile();
    if (image == null) return null;
    if (!_types.contains(image.mimeType)) {
      throw const AdminFailure('Choose a PNG, JPG or WebP image.');
    }
    if (image.bytes.length > maxBytes) {
      throw const AdminFailure(
          'That image is over 2 MB. Choose a smaller one.');
    }
    final safeName = image.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ref = _storage
        .ref('products/${DateTime.now().millisecondsSinceEpoch}_$safeName');
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
