import 'package:flutter/foundation.dart';

/// A pincode customers asked for delivery to that the store does not
/// serve. Written by the customer app (`pincode_requests/{pincode}`), each
/// customer counted once.
@immutable
class PincodeRequest {
  const PincodeRequest({
    required this.pincode,
    required this.count,
    required this.lastAt,
  });

  final String pincode;

  /// How many customers have asked for this pincode.
  final int count;
  final DateTime lastAt;

  factory PincodeRequest.fromMap(String id, Map<String, dynamic> map) =>
      PincodeRequest(
        pincode: id,
        count: (map['count'] as num?)?.toInt() ?? 0,
        lastAt: DateTime.fromMillisecondsSinceEpoch(
          (map['lastAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// Something customers searched for and could not buy
/// (`search_misses/{term}`), each customer counted once per search term.
@immutable
class SearchMiss {
  const SearchMiss({
    required this.id,
    required this.term,
    required this.count,
    required this.notFound,
    required this.outOfStock,
    required this.lastAt,
  });

  final String id;

  /// What was typed, in lower case.
  final String term;

  /// How many customers searched for this and found nothing to buy.
  final int count;

  /// Of those, how many found no matching product at all...
  final int notFound;

  /// ...and how many found it, but out of stock.
  final int outOfStock;
  final DateTime lastAt;

  /// "Not in the catalogue", "Out of stock" or both.
  String get reason {
    if (notFound > 0 && outOfStock > 0) return 'Not listed, later out of stock';
    return outOfStock > 0 ? 'Out of stock' : 'Not in the catalogue';
  }

  factory SearchMiss.fromMap(String id, Map<String, dynamic> map) => SearchMiss(
        id: id,
        term: map['term'] as String? ?? id,
        count: (map['count'] as num?)?.toInt() ?? 0,
        notFound: (map['notFound'] as num?)?.toInt() ?? 0,
        outOfStock: (map['outOfStock'] as num?)?.toInt() ?? 0,
        lastAt: DateTime.fromMillisecondsSinceEpoch(
          (map['lastAt'] as num?)?.toInt() ?? 0,
        ),
      );
}
