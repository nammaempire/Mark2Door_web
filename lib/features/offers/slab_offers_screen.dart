import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/product.dart';
import 'slab_offers.dart';

/// Price slab offers: "order above ₹299 and pick one of these products
/// for ₹9". The admin sets the cart amount, the offer price and exactly
/// which products are in the list.
class SlabOffersScreen extends ConsumerWidget {
  const SlabOffersScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    List<Product> products, [
    SlabOffer? offer,
  ]) async {
    final saved = await showDialog<SlabOffer>(
      context: context,
      builder: (_) => _OfferDialog(offer: offer, products: products),
    );
    if (saved == null) return;
    try {
      await ref.read(slabOffersRepositoryProvider).save(saved);
      if (context.mounted) {
        showMessage(context, offer == null ? 'Offer added' : 'Offer saved');
      }
    } catch (_) {
      if (context.mounted) showMessage(context, 'Could not save. Try again.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(slabOffersProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final names = {for (final p in products) p.id: p.name};
    return AdminPage(
      title: 'Slab offers',
      subtitle: 'Order above an amount, pick one product at a special price.',
      actions: [
        FilledButton.icon(
          key: const ValueKey('add-offer-button'),
          onPressed: () => _open(context, ref, products),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add offer'),
        ),
      ],
      children: [
        AsyncView(
          value: offers,
          data: (list) => Panel(
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No offers yet. Add one, for example: order above '
                      '₹299 and pick one product for ₹9.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : Column(
                    children: [
                      for (final o in list)
                        ListTile(
                          key: ValueKey('offer-${o.id}'),
                          leading: const Icon(
                            Icons.redeem_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            'Order above ${formatPaise(o.minOrderPaise)}: '
                            'pick one for ${formatPaise(o.offerPricePaise)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              for (final id in o.productIds)
                                names[id] ?? 'Deleted product',
                            ].join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                key: ValueKey('offer-active-${o.id}'),
                                value: o.active,
                                onChanged: (v) => ref
                                    .read(slabOffersRepositoryProvider)
                                    .save(o.copyWith(active: v)),
                              ),
                              IconButton(
                                key: ValueKey('offer-edit-${o.id}'),
                                tooltip: 'Edit offer',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _open(context, ref, products, o),
                              ),
                              IconButton(
                                key: ValueKey('offer-delete-${o.id}'),
                                tooltip: 'Delete offer',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async {
                                  final yes = await confirm(
                                    context,
                                    title: 'Delete this offer?',
                                    message: 'Customers will no longer see '
                                        'it. Orders already placed keep '
                                        'their offer price.',
                                    action: 'Delete',
                                  );
                                  if (yes) {
                                    await ref
                                        .read(slabOffersRepositoryProvider)
                                        .delete(o.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        const Panel(
          title: 'How it works',
          child: Text(
            '1. Set the cart amount, the offer price and tick the products '
            'in the list.\n'
            '2. In the customer app, the cart shows the list once the items '
            'in it reach the amount. Below the amount it shows how much more '
            'to add.\n'
            '3. The customer picks one product, one unit, per order. It is '
            'added at the offer price and does not count towards the '
            'amount.\n'
            '4. If the cart drops below the amount, the offer product is '
            'removed.\n'
            '5. With several offers, the customer picks from any one offer '
            'their cart has reached.\n'
            '6. A product that is out of stock is left out of the list.',
            style: TextStyle(height: 1.6, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({this.offer, required this.products});

  final SlabOffer? offer;
  final List<Product> products;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _min = TextEditingController(text: _rupees(widget.offer?.minOrderPaise));
  late final _price =
      TextEditingController(text: _rupees(widget.offer?.offerPricePaise));
  late final Set<String> _picked = {...?widget.offer?.productIds};
  late bool _active = widget.offer?.active ?? true;
  String _query = '';
  String? _pickError;

  static String _rupees(int? paise) {
    if (paise == null) return '';
    return paise % 100 == 0
        ? '${paise ~/ 100}'
        : (paise / 100).toStringAsFixed(2);
  }

  static int? _paise(String text) {
    final value = double.tryParse(text.trim());
    return value == null ? null : (value * 100).round();
  }

  @override
  void dispose() {
    _min.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final ok = _formKey.currentState!.validate();
    setState(
      () => _pickError = _picked.isEmpty ? 'Tick at least one product' : null,
    );
    if (!ok || _picked.isEmpty) return;
    Navigator.of(context).pop(
      SlabOffer(
        id: widget.offer?.id ?? '',
        minOrderPaise: _paise(_min.text)!,
        offerPricePaise: _paise(_price.text)!,
        // Keep the order the products are listed in.
        productIds: [
          for (final p in widget.products)
            if (_picked.contains(p.id)) p.id,
        ],
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final money = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    ];
    final shown = [
      for (final p in widget.products)
        if (_query.isEmpty || p.name.toLowerCase().contains(_query)) p,
    ];
    return AlertDialog(
      title: Text(widget.offer == null ? 'Add offer' : 'Edit offer'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('offer-min'),
                      controller: _min,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: money,
                      validator: (v) {
                        final paise = _paise(v ?? '');
                        return paise == null || paise <= 0
                            ? 'Enter the cart amount'
                            : null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Order above (₹)',
                        hintText: '299',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('offer-price'),
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: money,
                      validator: (v) {
                        final paise = _paise(v ?? '');
                        return paise == null || paise < 0
                            ? 'Enter the offer price'
                            : null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Offer price (₹)',
                        hintText: '9',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Products in the list (${_picked.length} ticked)',
                key: const ValueKey('offer-picked-count'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('offer-product-search'),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search products',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: shown.isEmpty
                    ? const Center(
                        child: Text(
                          'No products match.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final p = shown[i];
                          return CheckboxListTile(
                            key: ValueKey('offer-product-${p.id}'),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _picked.contains(p.id),
                            title: Text(p.name),
                            subtitle: Text(
                              '${p.unit} · sells at '
                              '${formatPaise(p.pricePaise)}',
                            ),
                            onChanged: (v) => setState(() {
                              v == true
                                  ? _picked.add(p.id)
                                  : _picked.remove(p.id);
                              _pickError = null;
                            }),
                          );
                        },
                      ),
              ),
              if (_pickError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _pickError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Offer is on'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-offer-button'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
