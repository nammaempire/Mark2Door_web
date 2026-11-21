import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/product.dart';
import 'product_form_dialog.dart';

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

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final categoryNames = {for (final c in categories) c.id: c.name};

    return AdminPage(
      title: 'Products',
      subtitle: 'Changes show up in the customer app straight away.',
      actions: [
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TableScroller(
                    child: DataTable(
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 60,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Price'), numeric: true),
                        DataColumn(label: Text('MRP'), numeric: true),
                        DataColumn(label: Text('Discount'), numeric: true),
                        DataColumn(label: Text('Stock left'), numeric: true),
                        DataColumn(label: Text('In stock')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final p in list)
                          DataRow(
                            cells: [
                              DataCell(_ProductCell(product: p)),
                              DataCell(
                                Text(
                                  categoryNames[p.categoryId] ?? p.categoryId,
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
                              DataCell(
                                Text(
                                  p.discountPercent == 0
                                      ? '–'
                                      : '${p.discountPercent}%',
                                ),
                              ),
                              DataCell(
                                Text(
                                  p.stockQty == null ? '–' : '${p.stockQty}',
                                  key: ValueKey('stock-left-${p.id}'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: p.stockQty == 0
                                        ? AppColors.danger
                                        : AppColors.textDark,
                                  ),
                                ),
                              ),
                              DataCell(
                                Switch(
                                  key: ValueKey('stock-${p.id}'),
                                  value: p.inStock,
                                  onChanged: (v) => ref
                                      .read(catalogRepositoryProvider)
                                      .setInStock(p.id, inStock: v),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      key: ValueKey('edit-${p.id}'),
                                      tooltip: 'Edit ${p.name}',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _openForm(categories, p),
                                    ),
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
                  '${all.where((p) => !p.canBeOrdered).length} out of stock',
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
