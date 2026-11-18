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
                          leading: _EmojiTile(categoryEmoji(c.icon)),
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

class _EmojiTile extends StatelessWidget {
  const _EmojiTile(this.emoji, {this.selected = false});

  final String emoji;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Text(
        emoji,
        style: const TextStyle(
          fontSize: 24,
          fontFamilyFallback: ['Noto Color Emoji'],
        ),
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
  late String _icon = widget.category?.icon ?? kCategoryIcons.keys.first;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final category = Category(
      id: widget.category?.id ?? '',
      name: _name.text.trim(),
      icon: _icon,
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
                'Artwork',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in kCategoryIcons.entries)
                    Tooltip(
                      message: entry.value.label,
                      child: InkWell(
                        key: ValueKey('icon-${entry.key}'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _icon = entry.key),
                        child: _EmojiTile(
                          entry.value.emoji,
                          selected: entry.key == _icon,
                        ),
                      ),
                    ),
                ],
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
