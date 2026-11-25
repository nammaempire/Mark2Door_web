import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';

/// A price slab offer: once a customer's cart reaches [minOrderPaise],
/// they may pick one product from [productIds] at [offerPricePaise]
/// instead of its selling price. Firestore: `slab_offers/{id}`.
@immutable
class SlabOffer {
  const SlabOffer({
    required this.id,
    required this.minOrderPaise,
    required this.offerPricePaise,
    required this.productIds,
    this.active = true,
  });

  /// Empty for an offer that has not been saved yet.
  final String id;
  final int minOrderPaise;
  final int offerPricePaise;
  final List<String> productIds;
  final bool active;

  factory SlabOffer.fromMap(String id, Map<String, dynamic> map) => SlabOffer(
        id: id,
        minOrderPaise: (map['minOrderPaise'] as num?)?.toInt() ?? 0,
        offerPricePaise: (map['offerPricePaise'] as num?)?.toInt() ?? 0,
        productIds: [
          for (final p in (map['productIds'] as List?) ?? const []) '$p',
        ],
        active: map['active'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'minOrderPaise': minOrderPaise,
        'offerPricePaise': offerPricePaise,
        'productIds': productIds,
        'active': active,
      };

  SlabOffer copyWith({String? id, bool? active}) => SlabOffer(
        id: id ?? this.id,
        minOrderPaise: minOrderPaise,
        offerPricePaise: offerPricePaise,
        productIds: productIds,
        active: active ?? this.active,
      );
}

abstract interface class SlabOffersRepository {
  /// All offers, lowest cart amount first.
  Stream<List<SlabOffer>> watch();

  /// Adds an offer, or updates it when it already has an id.
  Future<void> save(SlabOffer offer);

  Future<void> delete(String id);
}

class FirestoreSlabOffersRepository implements SlabOffersRepository {
  FirestoreSlabOffersRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('slab_offers');

  @override
  Stream<List<SlabOffer>> watch() => _col.snapshots().map(
        (s) => [for (final d in s.docs) SlabOffer.fromMap(d.id, d.data())]
          ..sort((a, b) => a.minOrderPaise.compareTo(b.minOrderPaise)),
      );

  @override
  Future<void> save(SlabOffer offer) => offer.id.isEmpty
      ? _col.add(offer.toMap())
      : _col.doc(offer.id).set(offer.toMap());

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

/// Sample mode: starts with no offers.
class FakeSlabOffersRepository implements SlabOffersRepository {
  final _offers = <SlabOffer>[];
  final _changes = StreamController<void>.broadcast();
  var _next = 1;

  @override
  Stream<List<SlabOffer>> watch() async* {
    yield List.unmodifiable(_offers);
    await for (final _ in _changes.stream) {
      yield List.unmodifiable(_offers);
    }
  }

  @override
  Future<void> save(SlabOffer offer) async {
    if (offer.id.isEmpty) {
      _offers.add(offer.copyWith(id: 'offer${_next++}'));
    } else {
      final i = _offers.indexWhere((o) => o.id == offer.id);
      if (i >= 0) _offers[i] = offer;
    }
    _offers.sort((a, b) => a.minOrderPaise.compareTo(b.minOrderPaise));
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _offers.removeWhere((o) => o.id == id);
    _changes.add(null);
  }
}

final slabOffersRepositoryProvider = Provider<SlabOffersRepository>(
  (ref) => Env.useFirebase
      ? FirestoreSlabOffersRepository(FirebaseFirestore.instance)
      : FakeSlabOffersRepository(),
);

final slabOffersProvider = StreamProvider<List<SlabOffer>>(
  (ref) => ref.watch(slabOffersRepositoryProvider).watch(),
);
