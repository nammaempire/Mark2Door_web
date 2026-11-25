import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/product.dart';

/// A customer's review, as the admin sees it.
class _Review {
  const _Review(this.uid, this.name, this.rating, this.text, this.at);

  final String uid;
  final String name;
  final int rating;
  final String text;
  final DateTime at;
}

/// Sample-mode reviews, so the dialog can be tried without Firebase.
final _sample = <String, List<_Review>>{};

Future<List<_Review>> _load(String productId) async {
  if (!Env.useFirebase) {
    return _sample.putIfAbsent(
      productId,
      () => [
        _Review('s1', 'Ananya', 5, 'Fresh and well packed.',
            DateTime.now().subtract(const Duration(days: 4))),
        _Review('s2', 'Rahul', 2, 'Arrived late.',
            DateTime.now().subtract(const Duration(days: 9))),
      ],
    );
  }
  final snap = await FirebaseFirestore.instance
      .collection('products')
      .doc(productId)
      .collection('reviews')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .get();
  return [
    for (final d in snap.docs)
      _Review(
        d.id,
        (d.data()['name'] as String? ?? '').trim(),
        ((d.data()['rating'] as num?)?.toInt() ?? 0).clamp(1, 5),
        (d.data()['text'] as String? ?? '').trim(),
        DateTime.fromMillisecondsSinceEpoch(
          (d.data()['createdAt'] as num?)?.toInt() ?? 0,
        ),
      ),
  ];
}

Future<void> _remove(String productId, String uid) async {
  if (!Env.useFirebase) {
    _sample[productId]?.removeWhere((r) => r.uid == uid);
    return;
  }
  await FirebaseFirestore.instance
      .collection('products')
      .doc(productId)
      .collection('reviews')
      .doc(uid)
      .delete();
}

/// Customer reviews of [product]. Reviews show in the customer app as
/// soon as they are written; the store can remove one here.
class ProductReviewsDialog extends StatefulWidget {
  const ProductReviewsDialog({super.key, required this.product});

  final Product product;

  @override
  State<ProductReviewsDialog> createState() => _ProductReviewsDialogState();
}

class _ProductReviewsDialogState extends State<ProductReviewsDialog> {
  late Future<List<_Review>> _reviews = _load(widget.product.id);

  Future<void> _delete(_Review r) async {
    final ok = await confirm(
      context,
      title: 'Remove this review?',
      message: 'Customers will no longer see the review by '
          '${r.name.isEmpty ? 'this customer' : r.name}.',
      action: 'Remove',
    );
    if (!ok) return;
    try {
      await _remove(widget.product.id, r.uid);
      if (!mounted) return;
      setState(() => _reviews = _load(widget.product.id));
      showMessage(context, 'Review removed');
    } catch (_) {
      if (mounted) showMessage(context, 'Could not remove the review.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reviews: ${widget.product.name}'),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<List<_Review>>(
          future: _reviews,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text('Could not load the reviews.');
            }
            final list = snap.data;
            if (list == null) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (list.isEmpty) {
              return const Text(
                'No reviews yet.',
                style: TextStyle(color: AppColors.textMuted),
              );
            }
            final average =
                list.fold(0, (sum, r) => sum + r.rating) / list.length;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${average.toStringAsFixed(1)} out of 5 from '
                    '${list.length} ${list.length == 1 ? 'review' : 'reviews'}',
                    key: const ValueKey('reviews-average'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final r in list)
                    ListTile(
                      key: ValueKey('review-${r.uid}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${'★' * r.rating}${'☆' * (5 - r.rating)}  '
                        '${r.name.isEmpty ? 'Customer' : r.name}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${r.text.isEmpty ? 'No words written.' : r.text}\n'
                        '${formatOrderDate(r.at)}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        key: ValueKey('remove-review-${r.uid}'),
                        tooltip: 'Remove review',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _delete(r),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
