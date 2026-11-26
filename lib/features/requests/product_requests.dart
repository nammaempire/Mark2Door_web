import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';

/// A product a customer could not find in the app and asked the store
/// to get (`product_requests/{id}`). The store calls the customer to say
/// how long it will take.
@immutable
class ProductRequest {
  const ProductRequest({
    required this.id,
    required this.product,
    required this.quantity,
    required this.customerName,
    required this.phone,
    required this.pincode,
    required this.createdAt,
    this.contacted = false,
  });

  final String id;
  final String product;
  final String quantity;
  final String customerName;
  final String phone;
  final String pincode;
  final DateTime createdAt;

  /// The store has called the customer about it.
  final bool contacted;

  factory ProductRequest.fromMap(String id, Map<String, dynamic> map) =>
      ProductRequest(
        id: id,
        product: map['product'] as String? ?? '',
        quantity: '${map['quantity'] ?? ''}',
        customerName: map['customerName'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        pincode: map['pincode'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0,
        ),
        contacted: map['status'] == 'contacted',
      );

  ProductRequest copyWith({bool? contacted}) => ProductRequest(
        id: id,
        product: product,
        quantity: quantity,
        customerName: customerName,
        phone: phone,
        pincode: pincode,
        createdAt: createdAt,
        contacted: contacted ?? this.contacted,
      );
}

abstract interface class ProductRequestsRepository {
  /// Newest first.
  Stream<List<ProductRequest>> watch();

  Future<void> setContacted(String id, bool contacted);

  Future<void> delete(String id);
}

class FirestoreProductRequestsRepository implements ProductRequestsRepository {
  FirestoreProductRequestsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('product_requests');

  @override
  Stream<List<ProductRequest>> watch() => _col.snapshots().map(
        (s) => [
          for (final d in s.docs) ProductRequest.fromMap(d.id, d.data()),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<void> setContacted(String id, bool contacted) =>
      _col.doc(id).update({'status': contacted ? 'contacted' : 'new'});

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

/// Sample mode: two requests to look at.
class FakeProductRequestsRepository implements ProductRequestsRepository {
  final _items = <ProductRequest>[
    ProductRequest(
      id: 'q1',
      product: 'Mysore sandal soap 125 g',
      quantity: '3',
      customerName: 'Asha',
      phone: '+919876543210',
      pincode: '560034',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ProductRequest(
      id: 'q2',
      product: 'Palm jaggery',
      quantity: '2 kg',
      customerName: 'Ravi',
      phone: '+919812345678',
      pincode: '560095',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      contacted: true,
    ),
  ];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<ProductRequest>> watch() async* {
    yield List.unmodifiable(_items);
    await for (final _ in _changes.stream) {
      yield List.unmodifiable(_items);
    }
  }

  @override
  Future<void> setContacted(String id, bool contacted) async {
    final i = _items.indexWhere((r) => r.id == id);
    if (i >= 0) _items[i] = _items[i].copyWith(contacted: contacted);
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((r) => r.id == id);
    _changes.add(null);
  }
}

final productRequestsRepositoryProvider = Provider<ProductRequestsRepository>(
  (ref) => Env.useFirebase
      ? FirestoreProductRequestsRepository(FirebaseFirestore.instance)
      : FakeProductRequestsRepository(),
);

final productRequestsProvider = StreamProvider<List<ProductRequest>>(
  (ref) => ref.watch(productRequestsRepositoryProvider).watch(),
);
