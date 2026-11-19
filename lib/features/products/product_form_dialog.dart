import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/emoji_picker.dart';
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
  late String _emoji = widget.product?.emoji ?? '';
  /// One field per photo link, in display order; the first is the main
  /// photo. At most [Product.maxImages].
  late final List<TextEditingController> _images = [
    for (final url in widget.product?.imageUrls ?? const <String>[])
      TextEditingController(text: url),
  ];
  bool _uploading = false;
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
      _description,
      ..._images,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canAddPhoto => _images.length < Product.maxImages;

  void _addPhotoField([String url = '']) {
    if (!_canAddPhoto) return;
    setState(() => _images.add(TextEditingController(text: url)));
  }

  void _removePhotoField(int index) {
    final removed = _images[index];
    setState(() => _images.removeAt(index));
    // Disposed after the frame so the field being removed is not using it.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  Future<void> _upload(ImageUploader uploader) async {
    if (_uploading || !_canAddPhoto) return;
    setState(() => _uploading = true);
    try {
      final url = await uploader.pickAndUpload();
      if (mounted && url != null) _addPhotoField(url);
    } on AdminFailure catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't upload that image.");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _photoLink(String? v) {
    final url = v?.trim() ?? '';
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? null
        : 'Must be an https:// link';
  }

  /// Up to five photos for the product page slider.
  List<Widget> _photoSection() {
    final uploader = ref.watch(imageUploaderProvider);
    return [
      Text(
        'Photos (${_images.length} of ${Product.maxImages})',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      const SizedBox(height: 2),
      const Text(
        'Customers swipe through these on the product page. The first one '
        'is also used in lists.',
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
      const SizedBox(height: 10),
      for (final (i, controller) in _images.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 52,
                  color: AppColors.primarySoft,
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) =>
                        _photoLink(controller.text) != null ||
                                controller.text.trim().isEmpty
                            ? const Icon(
                                Icons.image_outlined,
                                color: AppColors.textMuted,
                              )
                            : Image.network(
                                controller.text.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.textMuted,
                                ),
                              ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  key: ValueKey('product-image-$i'),
                  controller: controller,
                  keyboardType: TextInputType.url,
                  validator: _photoLink,
                  decoration: InputDecoration(
                    labelText: i == 0 ? 'Main photo link' : 'Photo ${i + 1} link',
                    hintText: 'https://',
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('remove-image-$i'),
                tooltip: 'Remove photo',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _removePhotoField(i),
              ),
            ],
          ),
        ),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('add-image-link'),
            onPressed: _canAddPhoto ? _addPhotoField : null,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.link_rounded),
            label: const Text('Add photo link'),
          ),
          if (uploader != null)
            OutlinedButton.icon(
              key: const ValueKey('upload-image'),
              onPressed:
                  _canAddPhoto && !_uploading ? () => _upload(uploader) : null,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.upload_rounded),
              label: Text(_uploading ? 'Uploading…' : 'Upload photo'),
            ),
        ],
      ),
    ];
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
      emoji: _emoji,
      imageUrls: [
        for (final c in _images)
          if (c.text.trim().isNotEmpty) c.text.trim(),
      ],
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
                      child: EmojiPickerField(
                        key: const ValueKey('product-emoji'),
                        value: _emoji,
                        allowNone: true,
                        onChanged: (v) => setState(() => _emoji = v),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Shown when the product has no photo, and while '
                          'photos load.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._photoSection(),
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
