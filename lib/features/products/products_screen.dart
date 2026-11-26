import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../stores/stores.dart';
import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/product.dart';
import 'product_form_dialog.dart';
import 'reviews_dialog.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';
  String? _categoryId;

  void _openForm(List<Category> categories, [Product? product]) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ProductFormDialog(product: product, categories: categories),
    );
  }

  Future<void> _delete(Product product) async {
    final ok = await confirm(
      context,
      title: 'Delete ${product.name}?',
      message:
          'It will disappear from the customer app. Past orders keep '
          'their record of it.',
      action: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(catalogRepositoryProvider).deleteProduct(product.id);
      if (mounted) showMessage(context, '${product.name} deleted');
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't delete that product.");
    }
  }

  /// "Nagercoil 5 · Marthandam 5": what each store has of [p], for the
  /// stores that keep their own count. Empty when none does.
  static List<String> _byStore(Product p, List<Store> stores) => [
        for (final s in stores)
          if (p.storeStock.containsKey(s.id))
            '${s.name} ${p.storeStock[s.id]!.inStock ? p.storeStock[s.id]!.stockQty ?? '–' : 'off'}',
      ];

  /// Asks for the units a store has of [p] and saves them for that store.
  Future<void> _editStoreStock(Product p, String storeId) async {
    final controller = TextEditingController(
      text: p.stockQtyAt(storeId)?.toString() ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stock of ${p.name}'),
        content: SizedBox(
          width: 320,
          child: TextField(
            key: const ValueKey('store-stock-field'),
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Units in this store',
              helperText: 'Leave empty if this store does not count it.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('store-stock-save'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    final qty = result.isEmpty ? null : int.tryParse(result);
    if (result.isNotEmpty && (qty == null || qty < 0)) {
      showMessage(context, 'Enter a whole number, or leave it empty.');
      return;
    }
    await ref.read(catalogRepositoryProvider).setStoreStock(
          p.id,
          storeId,
          // The store's own switch, left as it is.
          inStock: p.storeStock[storeId]?.inStock ?? true,
          stockQty: qty,
        );
  }

  @override
  Widget build(BuildContext context) {
    // The store whose stock is shown; null shows the default stock.
    final store = ref.watch(activeStoreIdProvider);
    // A store login keeps its own store's stock and nothing else: no
    // adding, editing or deleting products. The database rules refuse
    // the same.
    final storeStaff = ref.watch(isStoreStaffProvider);
    final stores = ref.watch(storesProvider).valueOrNull ?? const <Store>[];
    final products = ref.watch(productsProvider);
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final categoryNames = {for (final c in categories) c.id: c.name};

    return AdminPage(
      title: 'Products',
      subtitle: 'Changes show up in the customer app straight away.',
      actions: [
        if (!storeStaff)
        FilledButton.icon(
          key: const ValueKey('add-product-button'),
          onPressed: categories.isEmpty ? null : () => _openForm(categories),
          style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add product'),
        ),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                key: const ValueKey('product-search'),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: Icon(Icons.search_rounded),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: InputDecorator(
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _categoryId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All categories'),
                      ),
                      for (final c in categories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: products,
          data: (all) {
            final list = all.where((p) {
              if (_categoryId != null && p.categoryId != _categoryId) {
                return false;
              }
              return _query.isEmpty || p.name.toLowerCase().contains(_query);
            }).toList();

            if (list.isEmpty) {
              return Panel(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      all.isEmpty
                          ? 'No products yet. Add your first one.'
                          : 'No products match this search.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              );
            }

            // On a narrower window the less-needed columns are left out
            // so the stock switch and the edit buttons stay in view.
            final pageWidth = MediaQuery.sizeOf(context).width;
            final showDiscount = pageWidth >= 1650;
            final showCategory = pageWidth >= 1350;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TableScroller(
                    child: DataTable(
                      dataRowMinHeight: 60,
                      // Rows grow when a product is kept in many stores.
                      dataRowMaxHeight: double.infinity,
                      columnSpacing: 28,
                      horizontalMargin: 20,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                      columns: [
                        const DataColumn(label: Text('Product')),
                        if (showCategory)
                          const DataColumn(label: Text('Category')),
                        const DataColumn(label: Text('Price'), numeric: true),
                        const DataColumn(label: Text('MRP'), numeric: true),
                        if (showDiscount)
                          const DataColumn(
                            label: Text('Discount'),
                            numeric: true,
                          ),
                        const DataColumn(
                          label: Text('Stock left'),
                          numeric: true,
                        ),
                        const DataColumn(label: Text('All India')),
                        const DataColumn(label: Text('In stock')),
                        const DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final p in list)
                          DataRow(
                            cells: [
                              // Clicking the product opens it for editing.
                              DataCell(
                                _ProductCell(product: p),
                                onTap: () => storeStaff && store != null
                                    ? _editStoreStock(p, store)
                                    : _openForm(categories, p),
                              ),
                              if (showCategory)
                                DataCell(
                                  Text(
                                    categoryNames[p.categoryId] ??
                                        p.categoryId,
                                  ),
                                ),
                              DataCell(
                                Text(
                                  formatPaise(p.pricePaise),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(Text(formatPaise(p.mrpPaise))),
                              if (showDiscount)
                                DataCell(
                                  Text(
                                    p.discountPercent == 0
                                        ? '–'
                                        : '${p.discountPercent}%',
                                  ),
                                ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // All stores together: each store's
                                    // own count, one under the other so
                                    // the table stays narrow.
                                    if (store == null &&
                                        _byStore(p, stores).isNotEmpty)
                                      Column(
                                        key: ValueKey('stock-left-${p.id}'),
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          for (final line
                                              in _byStore(p, stores))
                                            ConstrainedBox(
                                              constraints:
                                                  const BoxConstraints(
                                                maxWidth: 190,
                                              ),
                                              child: Text(
                                                line,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  height: 1.35,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                            ),
                                        ],
                                      )
                                    else
                                      Text(
                                        p.stockQtyAt(store) == null
                                            ? '–'
                                            : '${p.stockQtyAt(store)}',
                                        key: ValueKey('stock-left-${p.id}'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: p.stockQtyAt(store) == 0
                                              ? AppColors.danger
                                              : AppColors.textDark,
                                        ),
                                      ),
                                    // With a store chosen, its own count
                                    // is edited right here.
                                    if (store != null)
                                      IconButton(
                                        key: ValueKey('store-stock-${p.id}'),
                                        tooltip: 'Set this store\'s stock',
                                        iconSize: 16,
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            _editStoreStock(p, store),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(
                                p.allIndia
                                    ? StatusPill(
                                        key: ValueKey('all-india-${p.id}'),
                                        'Outstation',
                                        AppColors.primary,
                                      )
                                    : const Text('–'),
                              ),
                              DataCell(
                                Tooltip(
                                  // The main switch (under "All stores")
                                  // turns a product off everywhere; a
                                  // store cannot turn it back on.
                                  message: store != null && p.offEverywhere
                                      ? 'Switched off for all stores. Choose '
                                          '"All stores" to switch it on.'
                                      : '',
                                  child: Switch(
                                  key: ValueKey('stock-${p.id}'),
                                  value: p.inStockAt(store),
                                  onChanged: store != null && p.offEverywhere
                                      ? null
                                      : (v) => store == null
                                      ? ref
                                          .read(catalogRepositoryProvider)
                                          .setInStock(p.id, inStock: v)
                                      // Only this store's switch changes.
                                      : ref
                                          .read(catalogRepositoryProvider)
                                          .setStoreStock(
                                            p.id,
                                            store,
                                            inStock: v,
                                            stockQty: p.stockQtyAt(store),
                                          ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!storeStaff)
                                    IconButton(
                                      key: ValueKey('edit-${p.id}'),
                                      tooltip: 'Edit ${p.name}',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _openForm(categories, p),
                                    ),
                                    IconButton(
                                      key: ValueKey('reviews-${p.id}'),
                                      tooltip: 'Customer reviews',
                                      icon: const Icon(
                                        Icons.star_outline_rounded,
                                      ),
                                      onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (_) =>
                                            ProductReviewsDialog(product: p),
                                      ),
                                    ),
                                    if (!storeStaff)
                                    IconButton(
                                      key: ValueKey('delete-${p.id}'),
                                      tooltip: 'Delete ${p.name}',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      onPressed: () => _delete(p),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${list.length} of ${all.length} products · '
                  '${all.where((p) => !p.canBeOrderedAt(store)).length} out of stock'
                  '${store == null ? '' : ' in this store'}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProductCell extends StatelessWidget {
  const _ProductCell({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final art = Center(
      child: Text(
        product.emoji.isEmpty ? '🛒' : product.emoji,
        style: const TextStyle(
          fontSize: 22,
          fontFamilyFallback: ['Noto Color Emoji'],
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            color: AppColors.primarySoft,
            child: product.imageUrl.isEmpty
                ? art
                : Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => art,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            Text(
              product.unit,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}
