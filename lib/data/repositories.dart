import '../models/coupon.dart';
import '../models/demand.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/storefront.dart';

/// Error with a message that is safe to show to the admin.
class AdminFailure implements Exception {
  const AdminFailure(this.message);
  final String message;

  @override
  String toString() => 'AdminFailure($message)';
}

abstract interface class AdminAuthRepository {
  /// Email of the signed-in admin, or null.
  String? get currentEmail;

  Stream<String?> authStateChanges();

  /// Throws [AdminFailure] on bad credentials or a non-admin account.
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

abstract interface class CatalogAdminRepository {
  Stream<List<Product>> watchProducts();

  Stream<List<Category>> watchCategories();

  /// Creates when `category.id` is empty, otherwise updates.
  Future<void> saveCategory(Category category);

  /// Throws [AdminFailure] while products still use the category.
  Future<void> deleteCategory(String categoryId);

  /// Creates when `product.id` is empty, otherwise updates.
  Future<void> saveProduct(Product product);

  Future<void> setInStock(String productId, {required bool inStock});

  /// Sets one store's own stock of a product: its "In stock" switch and
  /// the units left there (null: not counted).
  Future<void> setStoreStock(
    String productId,
    String storeId, {
    required bool inStock,
    required int? stockQty,
  });

  Future<void> deleteProduct(String productId);
}

abstract interface class OrdersAdminRepository {
  /// All orders, newest first.
  /// Newest first. With [storeId], only that store's orders: a store
  /// login is not allowed to read any others.
  Stream<List<Order>> watchOrders({String? storeId});

  /// The orders placed from [from] to [to] (whole days), newest first,
  /// at most [limit] of them. Read once, for a report's order list.
  Future<List<Order>> fetchOrdersBetween(
    DateTime from,
    DateTime to, {
    String? storeId,
    int limit = 3000,
  });

  Future<void> updateStatus(String orderId, OrderStatus status);

  /// Marks a courier order shipped, with the courier's name and the
  /// tracking number the customer will see.
  Future<void> shipOrder(
    String orderId, {
    required String courier,
    required String tracking,
  });

  /// Pass null to unassign.
  Future<void> assignRider(String orderId, Rider? rider);

  /// Records that [riderId] handed over all the cash they were holding
  /// from cash-on-delivery orders. Their app then shows nothing to hand
  /// over until they collect cash again.
  Future<void> markCashReceived(String riderId);

  /// Records that the money for a cancelled, paid order was returned.
  Future<void> markRefunded(String orderId);
}

/// Help questions and legal pages shown in the customer app.
abstract interface class ContentAdminRepository {
  /// Ordered by `sortOrder`.
  Stream<List<Faq>> watchFaqs();

  /// Creates when `faq.id` is empty, otherwise updates.
  Future<void> saveFaq(Faq faq);

  Future<void> deleteFaq(String faqId);

  /// Every page that has been written, keyed by its id.
  Stream<Map<String, LegalPage>> watchPages();

  Future<void> savePage(String pageId, String body);

  /// The customer app then shows the page as not available.
  Future<void> deletePage(String pageId);
}

/// Uploads a product photo chosen from this computer.
abstract interface class ImageUploader {
  /// Opens the file chooser, uploads the picked image and returns its
  /// public link; null when the admin closes the chooser without picking.
  /// Throws [AdminFailure] when the file is unsuitable or the upload fails.
  Future<String?> pickAndUpload();
}

abstract interface class ServiceAreaAdminRepository {
  Stream<List<ServiceArea>> watchAreas();

  /// Adds the pincode with its area [name], or re-activates and renames
  /// it if it already exists.
  Future<void> addArea(String pincode, {String name = '', String? storeId});

  Future<void> setActive(String pincode, {required bool active});

  Future<void> removeArea(String pincode);
}

abstract interface class StorefrontAdminRepository {
  /// Ordered by `sortOrder`.
  Stream<List<PromoBanner>> watchBanners();

  /// Creates when `banner.id` is empty, otherwise updates.
  Future<void> saveBanner(PromoBanner banner);

  Future<void> deleteBanner(String bannerId);

  Stream<StoreSettings> watchSettings();

  Future<void> saveSettings(StoreSettings settings);
}

abstract interface class RidersAdminRepository {
  /// By name. With [storeId], only that store's delivery partners.
  Stream<List<Rider>> watchRiders({String? storeId});

  /// Creates when `rider.id` is empty, otherwise updates.
  Future<void> saveRider(Rider rider);

  Future<void> deleteRider(String riderId);
}

/// Discount codes customers type at checkout.
abstract interface class CouponsAdminRepository {
  /// Ordered by code.
  Stream<List<Coupon>> watchCoupons();

  /// Creates the coupon, or replaces the one with the same code.
  Future<void> saveCoupon(Coupon coupon);

  Future<void> setActive(String code, {required bool active});

  Future<void> deleteCoupon(String code);
}

/// What customers wanted and could not get, recorded by the customer app.
abstract interface class DemandAdminRepository {
  /// Pincodes asked for outside the delivery area, most asked first.
  Stream<List<PincodeRequest>> watchPincodeRequests();

  /// Searches that found nothing to buy, most searched first.
  Stream<List<SearchMiss>> watchSearchMisses();

  Future<void> removePincodeRequest(String pincode);

  Future<void> removeSearchMiss(String id);
}
