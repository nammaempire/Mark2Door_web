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

  Future<void> deleteProduct(String productId);
}

abstract interface class OrdersAdminRepository {
  /// All orders, newest first.
  Stream<List<Order>> watchOrders();

  Future<void> updateStatus(String orderId, OrderStatus status);

  /// Pass null to unassign.
  Future<void> assignRider(String orderId, Rider? rider);
}

abstract interface class ServiceAreaAdminRepository {
  Stream<List<ServiceArea>> watchAreas();

  /// Adds the pincode, or re-activates it if it already exists.
  Future<void> addArea(String pincode);

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
  Stream<List<Rider>> watchRiders();

  /// Creates when `rider.id` is empty, otherwise updates.
  Future<void> saveRider(Rider rider);

  Future<void> deleteRider(String riderId);
}
