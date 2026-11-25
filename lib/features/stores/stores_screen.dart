import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'stores.dart';

/// The business's shops. Adding a store here lets pincodes, riders and
/// stock be kept for it separately.
class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, [Store? store]) async {
    final saved = await showDialog<Store>(
      context: context,
      builder: (_) => _StoreDialog(store: store),
    );
    if (saved == null) return;
    try {
      await ref.read(storesRepositoryProvider).save(saved);
      if (context.mounted) {
        showMessage(context, store == null ? 'Store added' : 'Store saved');
      }
    } catch (_) {
      if (context.mounted) showMessage(context, 'Could not save. Try again.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storesProvider);
    final ownStore = ref.watch(adminStoreIdProvider).valueOrNull;
    return AdminPage(
      title: 'Stores',
      subtitle: 'Each store has its own delivery pincodes, stock, riders and '
          'orders. A customer is served by the store that delivers to their '
          'pincode.',
      actions: [
        if (ownStore == null)
          FilledButton.icon(
            key: const ValueKey('add-store-button'),
            onPressed: () => _open(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add store'),
          ),
      ],
      children: [
        AsyncView(
          value: stores,
          data: (list) => Panel(
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No stores added. The business runs as one shop: every '
                      'pincode, rider and product belongs to it. Add a store '
                      'when you open a second shop.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : Column(
                    children: [
                      for (final s in list)
                        ListTile(
                          key: ValueKey('store-${s.id}'),
                          leading: const Icon(
                            Icons.store_mall_directory_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            s.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${s.address.isEmpty ? 'No address' : s.address}\n'
                            'Store ID: ${s.id}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusPill(
                                s.active ? 'Open' : 'Closed',
                                s.active
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                              if (ownStore == null)
                                IconButton(
                                  tooltip: 'Edit ${s.name}',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _open(context, ref, s),
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
            '1. Add each shop here.\n'
            '2. Service areas: choose the store for every pincode.\n'
            '3. Riders: choose the store each rider delivers for.\n'
            '4. Products: pick a store at the top of the menu, then set that '
            'store\'s stock on the Products page. A product can be in stock in '
            'one store and sold out in another.\n'
            '5. Store staff logins: create the login in Firebase '
            'Authentication, then in Firestore add admins/{their user id} '
            'with a field storeId set to the Store ID shown above. They then '
            'see only their own store. A login without storeId is a main '
            'admin and sees every store.',
            style: TextStyle(height: 1.6, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}

class _StoreDialog extends StatefulWidget {
  const _StoreDialog({this.store});

  final Store? store;

  @override
  State<_StoreDialog> createState() => _StoreDialogState();
}

class _StoreDialogState extends State<_StoreDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.store?.name ?? '');
  late final _address =
      TextEditingController(text: widget.store?.address ?? '');
  late bool _active = widget.store?.active ?? true;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Store(
        id: widget.store?.id ?? '',
        name: _name.text.trim(),
        address: _address.text.trim(),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.store == null ? 'Add store' : 'Edit store'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('store-name'),
                controller: _name,
                autofocus: true,
                maxLength: 40,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Enter the store name, like Nagercoil'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Store name',
                  hintText: 'Nagercoil',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('store-address'),
                controller: _address,
                maxLength: 160,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  counterText: '',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Open'),
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
          key: const ValueKey('save-store-button'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// In the menu: which store's data is on screen. A main admin chooses
/// "All stores" or one store; a store admin sees their own store's name.
/// Takes no space until a store has been added.
class StoreSwitcher extends ConsumerWidget {
  const StoreSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storesProvider).valueOrNull ?? const <Store>[];
    if (stores.isEmpty) return const SizedBox.shrink();
    final own = ref.watch(adminStoreIdProvider).valueOrNull;
    final active = ref.watch(activeStoreIdProvider);
    const light = TextStyle(color: Colors.white, fontWeight: FontWeight.w700);
    return Container(
      key: const ValueKey('store-switcher'),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: own != null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.store_mall_directory_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      storeName(stores, own).isEmpty
                          ? 'Your store'
                          : storeName(stores, own),
                      overflow: TextOverflow.ellipsis,
                      style: light,
                    ),
                  ),
                ],
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                key: const ValueKey('store-dropdown'),
                value: stores.any((s) => s.id == active) ? active : null,
                isExpanded: true,
                dropdownColor: AppColors.primary,
                iconEnabledColor: Colors.white,
                style: light,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All stores', style: light),
                  ),
                  for (final s in stores)
                    DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(
                        s.name,
                        overflow: TextOverflow.ellipsis,
                        style: light,
                      ),
                    ),
                ],
                onChanged: (id) =>
                    ref.read(selectedStoreProvider.notifier).choose(id),
              ),
            ),
    );
  }
}

/// A "Store" dropdown for forms (pincode, rider). Hidden until a store
/// exists. A store admin's own store is chosen for them.
class StoreField extends ConsumerWidget {
  const StoreField({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 220,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storesProvider).valueOrNull ?? const <Store>[];
    final own = ref.watch(adminStoreIdProvider).valueOrNull;
    if (stores.isEmpty || own != null) return const SizedBox.shrink();
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Store',
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            key: const ValueKey('store-field'),
            value: stores.any((s) => s.id == value) ? value : null,
            isExpanded: true,
            isDense: true,
            hint: const Text('Choose a store'),
            items: [
              for (final s in stores)
                DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
