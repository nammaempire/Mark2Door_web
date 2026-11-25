import 'rider_documents_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../stores/stores.dart';
import '../stores/stores_screen.dart';
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

    // What each rider has earned from customers and still owes the store:
    // star ratings on their deliveries, and cash collected but not yet
    // handed over.
    final ratingSum = <String, int>{};
    final ratingCount = <String, int>{};
    final cash = <String, int>{};
    for (final o in orders) {
      final id = o.riderId;
      if (id == null) continue;
      if (o.riderRating != null) {
        ratingSum.update(id, (n) => n + o.riderRating!,
            ifAbsent: () => o.riderRating!);
        ratingCount.update(id, (n) => n + 1, ifAbsent: () => 1);
      }
      if (o.cashWithRider) {
        cash.update(id, (n) => n + o.payablePaise,
            ifAbsent: () => o.payablePaise);
      }
    }

    Future<void> cashReceived(Rider r) async {
      final amount = formatPaise(cash[r.id] ?? 0);
      final ok = await confirm(
        context,
        title: 'Received $amount from ${r.name}?',
        message: 'Confirm only after the cash is in your hands. '
            "${r.name}'s app will then show nothing to hand over.",
        action: 'Cash received',
      );
      if (!ok) return;
      await ref.read(ordersRepositoryProvider).markCashReceived(r.id);
      if (context.mounted) {
        showMessage(context, '$amount received from ${r.name}');
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
                        // Wide screens: details on the left, controls on the
                        // right. Phones: the controls drop to their own line,
                        // so the name and details keep the full width.
                        LayoutBuilder(
                          builder: (context, box) {
                            final info = Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  backgroundColor: AppColors.primarySoft,
                                  child: Icon(
                                    Icons.delivery_dining_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      DefaultTextStyle.merge(
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textMuted,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '+91 ${r.phone} · ${active[r.id] ?? 0} active '
                                              'deliver'
                                              '${(active[r.id] ?? 0) == 1 ? 'y' : 'ies'}',
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 14,
                                              runSpacing: 2,
                                              children: [
                                                Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.star_rounded,
                                                        size: 18,
                                                        color:
                                                            Color(0xFFE8A200),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        (ratingCount[r.id] ??
                                                                    0) ==
                                                                0
                                                            ? 'No ratings yet'
                                                            : '${(ratingSum[r.id]! / ratingCount[r.id]!).toStringAsFixed(1)}'
                                                                ' · ${ratingCount[r.id]} rating'
                                                                '${ratingCount[r.id] == 1 ? '' : 's'}',
                                                        key: ValueKey(
                                                            'rider-rating-${r.id}'),
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: AppColors
                                                              .textDark,
                                                        ),
                                                      ),
                                                    ]),
                                                Text(
                                                  'Cash to hand over: '
                                                  '${formatPaise(cash[r.id] ?? 0)}',
                                                  key: ValueKey(
                                                      'rider-cash-${r.id}'),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: (cash[r.id] ?? 0) > 0
                                                        ? AppColors.danger
                                                        : AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                            final actions = Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if ((cash[r.id] ?? 0) > 0) ...[
                                  OutlinedButton(
                                    key: ValueKey('cash-received-${r.id}'),
                                    onPressed: () => cashReceived(r),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(140, 40),
                                    ),
                                    child: const Text('Cash received'),
                                  ),
                                ],
                                StatusPill(
                                  r.active ? 'Available' : 'Off duty',
                                  r.active
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                ),
                                Switch(
                                  key: ValueKey('rider-switch-${r.id}'),
                                  value: r.active,
                                  onChanged: (v) =>
                                      repo.saveRider(r.copyWith(active: v)),
                                ),
                                IconButton(
                                  key: ValueKey('rider-documents-${r.id}'),
                                  tooltip: 'Documents of ${r.name}',
                                  icon: const Icon(Icons.badge_outlined),
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) =>
                                        RiderDocumentsDialog(rider: r),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit ${r.name}',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _openForm(context, r),
                                ),
                                IconButton(
                                  tooltip: 'Remove ${r.name}',
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
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
                            );
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: box.maxWidth >= 720
                                  ? Row(
                                      children: [
                                        Expanded(child: info),
                                        const SizedBox(width: 12),
                                        actions,
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        info,
                                        const SizedBox(height: 6),
                                        actions,
                                      ],
                                    ),
                            );
                          },
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
  late String? _storeId = widget.rider?.storeId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final stores = ref.read(storesProvider).valueOrNull ?? const <Store>[];
    final storeId = ref.read(adminStoreIdProvider).valueOrNull ??
        _storeId ??
        ref.read(activeStoreIdProvider);
    if (stores.isNotEmpty && storeId == null) {
      showMessage(context, 'Choose the store this rider delivers for.');
      return;
    }
    setState(() => _saving = true);
    final rider = Rider(
      id: widget.rider?.id ?? '',
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      active: widget.rider?.active ?? true,
      storeId: storeId,
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
              const SizedBox(height: 14),
              StoreField(
                width: double.infinity,
                value: _storeId ?? ref.watch(activeStoreIdProvider),
                onChanged: (id) => setState(() => _storeId = id),
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
