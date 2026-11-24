import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repositories.dart';
import '../../models/product.dart';
import '../../models/storefront.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _openForm(BuildContext context, [Category? category]) {
    showDialog<void>(
      context: context,
      builder: (_) => _CategoryDialog(category: category),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final ok = await confirm(
      context,
      title: 'Delete ${category.name}?',
      message: 'The category disappears from the customer app.',
      action: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(catalogRepositoryProvider).deleteCategory(category.id);
      if (context.mounted) showMessage(context, '${category.name} deleted');
    } on AdminFailure catch (e) {
      if (context.mounted) showMessage(context, e.message);
    } catch (_) {
      if (context.mounted) showMessage(context, "Couldn't delete that category.");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final counts = <String, int>{};
    for (final p in products) {
      counts.update(p.categoryId, (n) => n + 1, ifAbsent: () => 1);
    }

    return AdminPage(
      title: 'Categories',
      subtitle: 'The tiles customers browse on the home page.',
      actions: [
        FilledButton.icon(
          key: const ValueKey('add-category-button'),
          onPressed: () => _openForm(context),
          style: FilledButton.styleFrom(minimumSize: const Size(170, 48)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add category'),
        ),
      ],
      children: [
        AsyncView(
          value: categories,
          data: (list) => list.isEmpty
              ? const Panel(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No categories yet. Add your first one.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                )
              : Panel(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      for (final (i, c) in list.indexed) ...[
                        if (i > 0) const Divider(indent: 20, endIndent: 20),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: _CategoryPicture(category: c),
                          title: Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${counts[c.id] ?? 0} '
                            'product${(counts[c.id] ?? 0) == 1 ? '' : 's'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: ValueKey('edit-category-${c.id}'),
                                tooltip: 'Edit ${c.name}',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openForm(context, c),
                              ),
                              IconButton(
                                key: ValueKey('delete-category-${c.id}'),
                                tooltip: 'Delete ${c.name}',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => _delete(context, ref, c),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// The category's picture, or its old drawn icon when it has none yet.
class _CategoryPicture extends StatelessWidget {
  const _CategoryPicture({super.key, required this.category, this.size = 48});

  final Category category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      categoryEmoji(category.icon),
      style: TextStyle(
        fontSize: size / 2,
        fontFamilyFallback: const ['Noto Color Emoji'],
      ),
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: category.imageUrl.isEmpty
          ? fallback
          : Image.network(
              category.imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({this.category});

  final Category? category;

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  late final _image = TextEditingController(text: widget.category?.imageUrl);
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _image.dispose();
    super.dispose();
  }

  String? _imageValidator(String? v) {
    final url = v?.trim() ?? '';
    if (url.isEmpty) return 'Add an image link or upload an image';
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? null
        : 'Must be an https:// link';
  }

  Future<void> _upload(ImageUploader uploader) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final url = await uploader.pickAndUpload();
      if (mounted && url != null) setState(() => _image.text = url);
    } on AdminFailure catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't upload that image.");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final category = Category(
      id: widget.category?.id ?? '',
      name: _name.text.trim(),
      // Kept for the tile colour in the customer app; no longer chosen.
      icon: widget.category?.icon ?? 'basket',
      imageUrl: _image.text.trim(),
    );
    try {
      await ref.read(catalogRepositoryProvider).saveCategory(category);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(context, '${category.name} saved');
    } on AdminFailure catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't save the category.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploader = ref.watch(imageUploaderProvider);
    final preview = Category(
      id: '',
      name: '',
      icon: widget.category?.icon ?? 'basket',
      imageUrl: _imageValidator(_image.text) == null ? _image.text.trim() : '',
    );
    return AlertDialog(
      title: Text(widget.category == null ? 'Add category' : 'Edit category'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              TextFormField(
                key: const ValueKey('category-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              const SizedBox(height: 18),
              const Text(
                'Category image',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Shown on the category tile in the customer app. A square '
                'picture works best.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryPicture(
                    key: const ValueKey('category-image-preview'),
                    category: preview,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('category-image'),
                      controller: _image,
                      keyboardType: TextInputType.url,
                      validator: _imageValidator,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Image link',
                        hintText: 'https://…',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (uploader != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('upload-category-image'),
                    onPressed: _uploading ? null : () => _upload(uploader),
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(_uploading ? 'Uploading…' : 'Upload image'),
                  ),
                )
              else
                const Text(
                  'Uploading from this computer is available once the app '
                  'is connected to Firebase.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-category-button'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
