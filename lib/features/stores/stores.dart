import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/providers.dart';

/// One of the business's shops. Each store has its own delivery pincodes,
/// stock, riders and orders; a customer's pincode decides which store
/// serves them. Firestore: `stores/{id}`.
///
/// With no stores added, the whole business works as one shop, exactly as
/// before.
@immutable
class Store {
  const Store({
    required this.id,
    required this.name,
    this.address = '',
    this.active = true,
  });

  /// Empty for a store that has not been saved yet.
  final String id;
  final String name;
  final String address;
  final bool active;

  factory Store.fromMap(String id, Map<String, dynamic> map) => Store(
        id: id,
        name: (map['name'] as String? ?? '').trim(),
        address: (map['address'] as String? ?? '').trim(),
        active: map['active'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'address': address, 'active': active};

  Store copyWith({String? id, bool? active}) => Store(
        id: id ?? this.id,
        name: name,
        address: address,
        active: active ?? this.active,
      );
}

abstract interface class StoresRepository {
  /// All stores, by name.
  Stream<List<Store>> watch();

  /// Adds a store, or updates it when it already has an id.
  Future<void> save(Store store);

  /// The store the signed-in admin belongs to, or null for a main admin
  /// who manages every store. Set by hand in Firebase: the `storeId`
  /// field on the admin's `admins/{uid}` document.
  Future<String?> storeOfSignedInAdmin();
}

class FirestoreStoresRepository implements StoresRepository {
  FirestoreStoresRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  Stream<List<Store>> watch() => _db.collection('stores').snapshots().map(
        (s) => [for (final d in s.docs) Store.fromMap(d.id, d.data())]
          ..sort((a, b) => a.name.compareTo(b.name)),
      );

  @override
  Future<void> save(Store store) => store.id.isEmpty
      ? _db.collection('stores').add(store.toMap())
      : _db.collection('stores').doc(store.id).set(store.toMap());

  @override
  Future<String?> storeOfSignedInAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('admins').doc(uid).get();
    final id = (doc.data()?['storeId'] as String? ?? '').trim();
    return id.isEmpty ? null : id;
  }
}

/// Sample mode: starts with no stores (one shop, as before).
class FakeStoresRepository implements StoresRepository {
  FakeStoresRepository({this.adminStoreId});

  /// Set in tests to act as a store admin.
  final String? adminStoreId;

  final _stores = <Store>[];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Store>> watch() async* {
    yield List.unmodifiable(_stores);
    await for (final _ in _changes.stream) {
      yield List.unmodifiable(_stores);
    }
  }

  @override
  Future<void> save(Store store) async {
    if (store.id.isEmpty) {
      _stores.add(store.copyWith(id: 'store${_stores.length + 1}'));
    } else {
      final i = _stores.indexWhere((s) => s.id == store.id);
      if (i >= 0) _stores[i] = store;
    }
    _stores.sort((a, b) => a.name.compareTo(b.name));
    _changes.add(null);
  }

  @override
  Future<String?> storeOfSignedInAdmin() async => adminStoreId;
}

final storesRepositoryProvider = Provider<StoresRepository>(
  (ref) => Env.useFirebase
      ? FirestoreStoresRepository(
          FirebaseFirestore.instance,
          FirebaseAuth.instance,
        )
      : FakeStoresRepository(),
);

final storesProvider = StreamProvider<List<Store>>(
  (ref) => ref.watch(storesRepositoryProvider).watch(),
);

/// The store this admin is tied to; null for a main admin.
final adminStoreIdProvider = FutureProvider<String?>((ref) {
  // Looked up again whenever someone else signs in on this browser.
  ref.watch(authStateProvider);
  return ref.watch(storesRepositoryProvider).storeOfSignedInAdmin();
});

/// True for a store login: someone who manages one store only. Such a
/// login sees its own store's orders, riders, pincodes and stock, and
/// none of the business-wide pages. The database rules enforce the same.
final isStoreStaffProvider = Provider<bool>(
  (ref) => ref.watch(adminStoreIdProvider).valueOrNull != null,
);

/// The store a main admin has chosen to look at; null means all stores.
final selectedStoreProvider =
    NotifierProvider<SelectedStore, String?>(SelectedStore.new);

class SelectedStore extends Notifier<String?> {
  @override
  String? build() => null;

  void choose(String? storeId) => state = storeId;
}

/// The store whose orders, riders, pincodes and stock are on screen: a
/// store admin's own store, or the one a main admin picked. Null shows
/// every store together.
final activeStoreIdProvider = Provider<String?>(
  (ref) =>
      ref.watch(adminStoreIdProvider).valueOrNull ??
      ref.watch(selectedStoreProvider),
);

/// The name of store [id] for display; empty when it is unknown.
String storeName(List<Store> stores, String? id) {
  for (final s in stores) {
    if (s.id == id) return s.name;
  }
  return '';
}
