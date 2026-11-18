import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repositories.dart';
import '../../models/product.dart';

/// "42" / "42.5" / "42.50" -> 4200 / 4250 / 4250. Null when not a valid
/// amount. Parsed as text, never via double, so paise are exact.
int? parseRupeesToPaise(String input) {
  final match = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(input.trim());
  if (match == null) return null;
  final rupees = int.parse(match.group(1)!);
  final paise = int.parse((match.group(2) ?? '').padRight(2, '0'));
  return rupees * 100 + paise;
}

String paiseToRupeesText(int paise) {
  final rest = paise % 100;
  return rest == 0
      ? '${paise ~/ 100}'
      : '${paise ~/ 100}.${rest.toString().padLeft(2, '0')}';
}

/// Add (when [product] is null) or edit a product.
class ProductFormDialog extends ConsumerStatefulWidget {
  const ProductFormDialog({super.key, this.product, required this.categories});

  final Product? product;
  final List<Category> categories;

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _unit = TextEditingController(text: widget.product?.unit);
  late final _price = TextEditingController(
    text: widget.product == null
        ? ''
        : paiseToRupeesText(widget.product!.pricePaise),
  );
  late final _mrp = TextEditingController(
    text: widget.product == null
        ? ''
        : paiseToRupeesText(widget.product!.mrpPaise),
  );
  late final _emoji = TextEditingController(text: widget.product?.emoji);
  late final _imageUrl = TextEditingController(text: widget.product?.imageUrl);
  late final _description = TextEditingController(
    text: widget.product?.description,
  );
  late String? _categoryId =
      widget.product?.categoryId ??
      (widget.categories.isEmpty ? null : widget.categories.first.id);
  late bool _inStock = widget.product?.inStock ?? true;
  bool _saving = false;

  bool get _editing => widget.product != null;

  @override
  void dispose() {
    for (final c in [
      _name,
      _unit,
      _price,
      _mrp,
      _emoji,
      _imageUrl,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v?.trim().isEmpty ?? true) ? 'Required' : null;

  String? _money(String? v) {
    final paise = parseRupeesToPaise(v ?? '');
    if (paise == null) return 'Enter an amount like 42 or 42.50';
    if (paise == 0) return 'Must be more than 0';
    return null;
  }

  String? _mrpValidator(String? v) {
    final error = _money(v);
    if (error != null) return error;
    final price = parseRupeesToPaise(_price.text);
    if (price != null && parseRupeesToPaise(v!)! < price) {
      return "MRP can't be below the selling price";
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final product = Product(
      id: widget.product?.id ?? '',
      name: _name.text.trim(),
      categoryId: _categoryId!,
      unit: _unit.text.trim(),
      pricePaise: parseRupeesToPaise(_price.text)!,
      mrpPaise: parseRupeesToPaise(_mrp.text)!,
      emoji: _emoji.text.trim(),
      imageUrl: _imageUrl.text.trim(),
      description: _description.text.trim(),
      inStock: _inStock,
    );
    try {
      await ref.read(catalogRepositoryProvider).saveProduct(product);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(
        context,
        _editing ? '${product.name} updated' : '${product.name} added',
      );
    } on AdminFailure catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't save the product.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moneyFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
    ];

    return AlertDialog(
      title: Text(_editing ? 'Edit product' : 'Add product'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                TextFormField(
                  key: const ValueKey('product-name'),
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Product name'),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const ValueKey('product-category'),
                            value: _categoryId,
                            isExpanded: true,
                            items: [
                              for (final c in widget.categories)
                                DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                            ],
                            onChanged: (v) => setState(() => _categoryId = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: const ValueKey('product-unit'),
                        controller: _unit,
                        validator: _required,
                        decoration: const InputDecoration(
                          labelText: 'Pack size',
                          hintText: '500 g',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('product-price'),
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: moneyFormatters,
                        validator: _money,
                        decoration: const InputDecoration(
                          labelText: 'Selling price',
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('product-mrp'),
                        controller: _mrp,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: moneyFormatters,
                        validator: _mrpValidator,
                        decoration: const InputDecoration(
                          labelText: 'MRP',
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _emoji,
                        decoration: const InputDecoration(
                          labelText: 'Emoji',
                          hintText: '🍌',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _imageUrl,
                        keyboardType: TextInputType.url,
                        validator: (v) {
                          final url = v?.trim() ?? '';
                          if (url.isEmpty) return null;
                          final uri = Uri.tryParse(url);
                          return uri != null && uri.scheme == 'https'
                              ? null
                              : 'Must be an https:// link';
                        },
                        decoration: const InputDecoration(
                          labelText: 'Photo link (optional)',
                          hintText: 'https://',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('In stock'),
                  subtitle: const Text(
                    'Out-of-stock products stay visible but cannot be ordered.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  value: _inStock,
                  onChanged: (v) => setState(() => _inStock = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-product-button'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
          child: Text(
            _saving
                ? 'Saving…'
                : _editing
                ? 'Save changes'
                : 'Add product',
          ),
        ),
      ],
    );
  }
}
