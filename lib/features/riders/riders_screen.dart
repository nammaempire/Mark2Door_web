import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repositories.dart';
import '../../models/storefront.dart';

class RidersScreen extends ConsumerWidget {
  const RidersScreen({super.key});

  void _openForm(BuildContext context, [Rider? rider]) {
    showDialog<void>(
      context: context,
      builder: (_) => _RiderDialog(rider: rider),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riders = ref.watch(ridersProvider);
    final orders = ref.watch(ordersProvider).valueOrNull ?? const [];
    final repo = ref.read(ridersRepositoryProvider);

    // Live workload per rider: orders assigned and not yet finished.
    final active = <String, int>{};
    for (final o in orders) {
      if (o.riderId != null && o.isActive) {
        active.update(o.riderId!, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    return AdminPage(
      title: 'Riders',
      subtitle: 'Delivery partners you can assign orders to.',
      actions: [
        FilledButton.icon(
          key: const ValueKey('add-rider-button'),
          onPressed: () => _openForm(context),
          style: FilledButton.styleFrom(minimumSize: const Size(150, 48)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add rider'),
        ),
      ],
      children: [
        AsyncView(
          value: riders,
          data: (list) => list.isEmpty
              ? const Panel(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No riders yet. Add your first one.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                )
              : Panel(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      for (final (i, r) in list.indexed) ...[
                        if (i > 0) const Divider(indent: 20, endIndent: 20),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primarySoft,
                            child: Icon(
                              Icons.delivery_dining_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            r.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '+91 ${r.phone} · ${active[r.id] ?? 0} active '
                            'deliver${(active[r.id] ?? 0) == 1 ? 'y' : 'ies'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusPill(
                                r.active ? 'Available' : 'Off duty',
                                r.active
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                key: ValueKey('rider-switch-${r.id}'),
                                value: r.active,
                                onChanged: (v) =>
                                    repo.saveRider(r.copyWith(active: v)),
                              ),
                              IconButton(
                                tooltip: 'Edit ${r.name}',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openForm(context, r),
                              ),
                              IconButton(
                                tooltip: 'Remove ${r.name}',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async {
                                  final ok = await confirm(
                                    context,
                                    title: 'Remove ${r.name}?',
                                    message: 'Orders already assigned keep '
                                        'their record of this rider.',
                                    action: 'Remove',
                                  );
                                  if (ok) await repo.deleteRider(r.id);
                                },
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

class _RiderDialog extends ConsumerStatefulWidget {
  const _RiderDialog({this.rider});

  final Rider? rider;

  @override
  ConsumerState<_RiderDialog> createState() => _RiderDialogState();
}

class _RiderDialogState extends ConsumerState<_RiderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.rider?.name);
  late final _phone = TextEditingController(text: widget.rider?.phone);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final rider = Rider(
      id: widget.rider?.id ?? '',
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      active: widget.rider?.active ?? true,
    );
    try {
      await ref.read(ridersRepositoryProvider).saveRider(rider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(context, '${rider.name} saved');
    } on AdminFailure catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't save the rider.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rider == null ? 'Add rider' : 'Edit rider'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              TextFormField(
                key: const ValueKey('rider-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('rider-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: Validators.phone,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91 ',
                ),
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
          key: const ValueKey('save-rider-button'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
