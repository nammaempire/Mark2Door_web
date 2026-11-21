import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repositories.dart';
import '../../models/coupon.dart';
import '../products/product_form_dialog.dart'
    show paiseToRupeesText, parseRupeesToPaise;

/// Discount codes that customers type in "Apply coupon" at checkout.
class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  void _openForm(BuildContext context, [Coupon? coupon]) {
    showDialog<void>(
      context: context,
      builder: (_) => _CouponDialog(coupon: coupon),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(couponsProvider);
    final repo = ref.read(couponsRepositoryProvider);
    final now = DateTime.now();

    Future<void> delete(Coupon c) async {
      final ok = await confirm(
        context,
        title: 'Delete ${c.code}?',
        message: 'Customers will no longer be able to use this code. '
            'Orders that already used it keep their discount.',
        action: 'Delete',
      );
      if (!ok) return;
      await repo.deleteCoupon(c.code);
      if (context.mounted) showMessage(context, '${c.code} deleted');
    }

    return AdminPage(
      title: 'Coupons',
      subtitle: 'Discount codes customers can apply at checkout.',
      actions: [
        FilledButton.icon(
          key: const ValueKey('add-coupon-button'),
          onPressed: () => _openForm(context),
          style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add coupon'),
        ),
      ],
      children: [
        AsyncView(
          value: coupons,
          data: (list) => list.isEmpty
              ? const Panel(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No coupons yet. Add your first one.',
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
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          // Wide screens: one line. Phones: the controls
                          // drop below the details.
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final info = _CouponInfo(coupon: c, now: now);
                              final controls = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    key: ValueKey('coupon-active-${c.code}'),
                                    value: c.active,
                                    onChanged: (v) =>
                                        repo.setActive(c.code, active: v),
                                  ),
                                  IconButton(
                                    key: ValueKey('edit-coupon-${c.code}'),
                                    tooltip: 'Edit ${c.code}',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _openForm(context, c),
                                  ),
                                  IconButton(
                                    key: ValueKey('delete-coupon-${c.code}'),
                                    tooltip: 'Delete ${c.code}',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    onPressed: () => delete(c),
                                  ),
                                ],
                              );
                              if (box.maxWidth >= 620) {
                                return Row(
                                  children: [
                                    Expanded(child: info),
                                    const SizedBox(width: 12),
                                    controls,
                                  ],
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  info,
                                  const SizedBox(height: 4),
                                  controls,
                                ],
                              );
                            },
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

class _CouponInfo extends StatelessWidget {
  const _CouponInfo({required this.coupon, required this.now});

  final Coupon coupon;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = coupon;
    final expired = c.isExpiredAt(now);
    final (label, color) = expired
        ? ('Expired', AppColors.danger)
        : c.active
            ? ('Active', AppColors.success)
            : ('Switched off', AppColors.textMuted);
    final terms = [
      c.minOrderPaise > 0
          ? 'Item total of ${formatPaise(c.minOrderPaise)} or more'
          : 'No minimum order',
      c.oncePerCustomer ? 'Once per customer' : 'Any number of times',
      c.expiresAt == null
          ? 'No expiry'
          : '${expired ? 'Expired' : 'Valid until'} ${formatDate(c.expiresAt!)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              c.code,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.textDark,
              ),
            ),
            Text(
              c.offer,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            Container(
              key: ValueKey('coupon-status-${c.code}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withAlpha(28),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          terms.join(' · '),
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Add (when [coupon] is null) or edit a coupon. The code itself cannot be
/// changed once saved, because customers and past orders refer to it.
class _CouponDialog extends ConsumerStatefulWidget {
  const _CouponDialog({this.coupon});

  final Coupon? coupon;

  @override
  ConsumerState<_CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends ConsumerState<_CouponDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.coupon?.code);
  late CouponType _type = widget.coupon?.type ?? CouponType.percent;
  late final _value = TextEditingController(
    text: widget.coupon == null
        ? ''
        : widget.coupon!.type == CouponType.percent
            ? '${widget.coupon!.value}'
            : paiseToRupeesText(widget.coupon!.value),
  );
  late final _minOrder = TextEditingController(
    text: (widget.coupon?.minOrderPaise ?? 0) == 0
        ? ''
        : paiseToRupeesText(widget.coupon!.minOrderPaise),
  );
  late final _maxDiscount = TextEditingController(
    text: (widget.coupon?.maxDiscountPaise ?? 0) == 0
        ? ''
        : paiseToRupeesText(widget.coupon!.maxDiscountPaise),
  );
  late DateTime? _expiresAt = widget.coupon?.expiresAt;
  late bool _once = widget.coupon?.oncePerCustomer ?? false;
  late bool _active = widget.coupon?.active ?? true;
  bool _saving = false;

  bool get _editing => widget.coupon != null;

  @override
  void dispose() {
    for (final c in [_code, _value, _minOrder, _maxDiscount]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _codeValidator(String? v) {
    final code = Coupon.normalise(v ?? '');
    if (!Coupon.isValidCode(code)) {
      return '3 to 20 letters and numbers, no spaces';
    }
    if (!_editing) {
      final taken = (ref.read(couponsProvider).valueOrNull ?? const [])
          .any((c) => c.code == code);
      if (taken) return 'This code already exists';
    }
    return null;
  }

  String? _valueValidator(String? v) {
    final text = (v ?? '').trim();
    if (_type == CouponType.percent) {
      final n = int.tryParse(text);
      if (n == null || n < 1 || n > 100) return 'Enter 1 to 100';
      return null;
    }
    final paise = parseRupeesToPaise(text);
    if (paise == null || paise == 0) return 'Enter an amount like 50';
    return null;
  }

  String? _optionalMoney(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    return parseRupeesToPaise(text) == null
        ? 'Enter an amount like 199'
        : null;
  }

  Future<void> _pickExpiry() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt != null && _expiresAt!.isAfter(today)
          ? _expiresAt!
          : today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 5),
      helpText: 'Last day the coupon works',
    );
    if (picked == null) return;
    setState(() {
      // Valid through the end of the chosen day.
      _expiresAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final coupon = Coupon(
      code: Coupon.normalise(_code.text),
      type: _type,
      value: _type == CouponType.percent
          ? int.parse(_value.text.trim())
          : parseRupeesToPaise(_value.text)!,
      minOrderPaise: parseRupeesToPaise(_minOrder.text) ?? 0,
      maxDiscountPaise: _type == CouponType.percent
          ? parseRupeesToPaise(_maxDiscount.text) ?? 0
          : 0,
      expiresAt: _expiresAt,
      active: _active,
      oncePerCustomer: _once,
    );
    try {
      await ref.read(couponsRepositoryProvider).saveCoupon(coupon);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(
        context,
        _editing ? '${coupon.code} updated' : '${coupon.code} added',
      );
    } on AdminFailure catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't save the coupon.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))];
    final percent = _type == CouponType.percent;

    return AlertDialog(
      title: Text(_editing ? 'Edit ${widget.coupon!.code}' : 'Add coupon'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                TextFormField(
                  key: const ValueKey('coupon-code'),
                  controller: _code,
                  enabled: !_editing,
                  autofocus: !_editing,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  validator: _codeValidator,
                  decoration: InputDecoration(
                    labelText: 'Coupon code',
                    hintText: 'SAVE10',
                    helperText: _editing
                        ? 'The code cannot be changed. Delete it and add a '
                            'new one instead.'
                        : 'What customers type at checkout.',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<CouponType>(
                  key: const ValueKey('coupon-type'),
                  segments: [
                    for (final t in CouponType.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() {
                    _type = s.first;
                    _value.clear();
                  }),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('coupon-value'),
                  controller: _value,
                  keyboardType: TextInputType.number,
                  inputFormatters: percent
                      ? [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ]
                      : money,
                  validator: _valueValidator,
                  decoration: InputDecoration(
                    labelText: percent ? 'Percent off' : 'Amount off',
                    prefixText: percent ? null : '₹ ',
                    suffixText: percent ? '%' : null,
                    helperText: 'Taken off the item total, not the delivery '
                        'fee.',
                  ),
                ),
                if (percent) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('coupon-max-discount'),
                    controller: _maxDiscount,
                    keyboardType: TextInputType.number,
                    inputFormatters: money,
                    validator: _optionalMoney,
                    decoration: const InputDecoration(
                      labelText: 'Maximum discount (optional)',
                      prefixText: '₹ ',
                      helperText: 'The most this coupon can take off one '
                          'order.',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('coupon-min-order'),
                  controller: _minOrder,
                  keyboardType: TextInputType.number,
                  inputFormatters: money,
                  validator: _optionalMoney,
                  decoration: const InputDecoration(
                    labelText: 'Minimum item total (optional)',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  key: const ValueKey('coupon-expiry'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(
                    _expiresAt == null
                        ? 'No expiry date'
                        : 'Valid until ${formatDate(_expiresAt!)}',
                  ),
                  trailing: Wrap(
                    children: [
                      TextButton(
                        onPressed: _pickExpiry,
                        child: Text(_expiresAt == null ? 'Set date' : 'Change'),
                      ),
                      if (_expiresAt != null)
                        TextButton(
                          onPressed: () => setState(() => _expiresAt = null),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey('coupon-once'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Once per customer'),
                  subtitle: const Text(
                    'Off: a customer can use it on every order.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  value: _once,
                  onChanged: (v) => setState(() => _once = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text(
                    'Switch off to stop the code without deleting it.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
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
          key: const ValueKey('save-coupon-button'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
          child: Text(
            _saving
                ? 'Saving…'
                : _editing
                    ? 'Save changes'
                    : 'Add coupon',
          ),
        ),
      ],
    );
  }
}
