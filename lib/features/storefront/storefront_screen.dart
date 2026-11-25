import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/banner_art.dart';
import '../../core/emoji_picker.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repositories.dart';
import '../../models/product.dart';
import '../../models/storefront.dart';
import '../products/product_form_dialog.dart';

/// What customers see around the catalogue: delivery charges and promise,
/// and the promo banners on the home page.
class StorefrontScreen extends ConsumerWidget {
  const StorefrontScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(storeSettingsProvider);
    final banners = ref.watch(bannersProvider);
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];

    void openBanner([PromoBanner? banner]) => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _BannerDialog(banner: banner, categories: categories),
        );

    return AdminPage(
      title: 'Storefront',
      subtitle: 'Delivery settings and the banners on the app home page.',
      children: [
        AsyncView(
          value: settings,
          // Re-keyed on every saved change so the form shows stored values.
          data: (s) => _SettingsForm(
            key: ValueKey(
              '${s.deliveryFeePaise}-${s.freeDeliveryThresholdPaise}-'
              '${s.deliveryEtaMinutes}-${s.handlingFeeEnabled}-'
              '${s.handlingFeePaise}-${s.rainFeeEnabled}-${s.rainFeePaise}-'
              '${s.storeName}-${s.storeAddress}-${s.supportEmail}-'
              '${s.courierFeePaise}-${s.courierFreeAbovePaise}-${s.courierEta}-'
              '${s.paymentQrUrl}',
            ),
            settings: s,
          ),
        ),
        const SizedBox(height: 20),
        AsyncView(
          value: banners,
          data: (list) => Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Home banners',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('add-banner-button'),
                      onPressed:
                          categories.isEmpty ? null : () => openBanner(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(150, 44),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add banner'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No banners. The home page hides the carousel.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                for (final (i, b) in list.indexed) ...[
                  if (i > 0) const Divider(),
                  _BannerRow(
                    banner: b,
                    categoryName: categories
                            .where((c) => c.id == b.categoryId)
                            .map((c) => c.name)
                            .firstOrNull ??
                        b.categoryId,
                    onEdit: () => openBanner(b),
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

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.settings});

  final StoreSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _fee = TextEditingController(
    text: paiseToRupeesText(widget.settings.deliveryFeePaise),
  );
  late final _threshold = TextEditingController(
    text: paiseToRupeesText(widget.settings.freeDeliveryThresholdPaise),
  );
  late final _eta = TextEditingController(
    text: '${widget.settings.deliveryEtaMinutes}',
  );
  late final _handling = TextEditingController(
    text: paiseToRupeesText(widget.settings.handlingFeePaise),
  );
  late final _rain = TextEditingController(
    text: paiseToRupeesText(widget.settings.rainFeePaise),
  );
  late final _storeName =
      TextEditingController(text: widget.settings.storeName);
  late final _storeAddress =
      TextEditingController(text: widget.settings.storeAddress);
  late final _supportEmail =
      TextEditingController(text: widget.settings.supportEmail);
  late final _paymentQr =
      TextEditingController(text: widget.settings.paymentQrUrl);
  late final _courierFee = TextEditingController(
    text: paiseToRupeesText(widget.settings.courierFeePaise),
  );
  late final _courierFree = TextEditingController(
    text: paiseToRupeesText(widget.settings.courierFreeAbovePaise),
  );
  late final _courierEta =
      TextEditingController(text: widget.settings.courierEta);
  late bool _handlingOn = widget.settings.handlingFeeEnabled;
  late bool _rainOn = widget.settings.rainFeeEnabled;
  bool _saving = false;

  @override
  void dispose() {
    _fee.dispose();
    _threshold.dispose();
    _eta.dispose();
    _handling.dispose();
    _rain.dispose();
    _storeName.dispose();
    _storeAddress.dispose();
    _supportEmail.dispose();
    _paymentQr.dispose();
    _courierFee.dispose();
    _courierFree.dispose();
    _courierEta.dispose();
    super.dispose();
  }

  String? _money(String? v) => parseRupeesToPaise(v ?? '') == null
      ? 'Enter an amount like 30 or 29.50'
      : null;

  /// An enabled charge must be a real amount, or it would show as ₹0.
  String? _charge(String? v) {
    final paise = parseRupeesToPaise(v ?? '');
    if (paise == null) return 'Enter an amount like 5 or 9.50';
    return paise == 0 ? 'Must be more than 0' : null;
  }

  String? _minutes(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 5 || n > 240 ? 'Enter 5 to 240 minutes' : null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(storefrontRepositoryProvider).saveSettings(
            StoreSettings(
              deliveryFeePaise: parseRupeesToPaise(_fee.text)!,
              freeDeliveryThresholdPaise: parseRupeesToPaise(_threshold.text)!,
              deliveryEtaMinutes: int.parse(_eta.text),
              handlingFeeEnabled: _handlingOn,
              // A switched-off charge keeps its last amount for next time.
              handlingFeePaise: parseRupeesToPaise(_handling.text) ?? 0,
              rainFeeEnabled: _rainOn,
              rainFeePaise: parseRupeesToPaise(_rain.text) ?? 0,
              storeName: _storeName.text.trim(),
              storeAddress: _storeAddress.text.trim(),
              supportEmail: _supportEmail.text.trim(),
              paymentQrUrl: _paymentQr.text.trim(),
              courierFeePaise: parseRupeesToPaise(_courierFee.text)!,
              courierFreeAbovePaise: parseRupeesToPaise(_courierFree.text)!,
              courierEta: _courierEta.text.trim(),
            ),
          );
      if (mounted) showMessage(context, 'Delivery settings saved');
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't save the settings.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))];
    Widget field(
      String key,
      TextEditingController c,
      String label,
      String helper, {
      String? prefix,
      String? suffix,
      required String? Function(String?) validator,
      List<TextInputFormatter>? formatters,
    }) {
      return SizedBox(
        width: 250,
        child: TextFormField(
          key: ValueKey(key),
          controller: c,
          validator: validator,
          inputFormatters: formatters,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            prefixText: prefix,
            suffixText: suffix,
          ),
        ),
      );
    }

    return Panel(
      title: 'Delivery settings',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                field(
                  'setting-fee',
                  _fee,
                  'Delivery fee',
                  'Charged on smaller orders',
                  prefix: '₹ ',
                  validator: _money,
                  formatters: money,
                ),
                field(
                  'setting-threshold',
                  _threshold,
                  'Free delivery above',
                  'Order value that waives the fee',
                  prefix: '₹ ',
                  validator: _money,
                  formatters: money,
                ),
                field(
                  'setting-eta',
                  _eta,
                  'Delivery time',
                  'Shown to customers as the promise',
                  suffix: 'min',
                  validator: _minutes,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Extra charges',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Added to every order while switched on. Customers only see a '
              'charge that is on.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _ChargeControl(
                  keyName: 'handling',
                  title: 'Handling fee',
                  hint: 'Packing and handling',
                  enabled: _handlingOn,
                  controller: _handling,
                  onToggle: (v) => setState(() => _handlingOn = v),
                  validator: (v) => _handlingOn ? _charge(v) : null,
                ),
                _ChargeControl(
                  keyName: 'rain',
                  title: 'Rain charge',
                  hint: 'Switch on when it rains',
                  enabled: _rainOn,
                  controller: _rain,
                  onToggle: (v) => setState(() => _rainOn = v),
                  validator: (v) => _rainOn ? _charge(v) : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Outstation orders',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'For customers outside your service areas. They pay online, '
              'and see this charge and delivery time before ordering.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    key: const ValueKey('setting-courier-fee'),
                    controller: _courierFee,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _money,
                    decoration: const InputDecoration(
                      labelText: 'Outstation delivery charge',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    key: const ValueKey('setting-courier-free'),
                    controller: _courierFree,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _money,
                    decoration: const InputDecoration(
                      labelText: 'Free delivery above',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    key: const ValueKey('setting-courier-eta'),
                    controller: _courierEta,
                    maxLength: 30,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter a time like 3 to 5 days'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Delivery time',
                      hintText: '3 to 5 days',
                      helperText: 'Shown as "Reaches you in ..."',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Store and support',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Riders see the store name and address as their pickup '
              'point. Customers can write to the support email from the '
              'help page.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 250,
                  child: TextFormField(
                    key: const ValueKey('setting-store-name'),
                    controller: _storeName,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Store name',
                      counterText: '',
                    ),
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: TextFormField(
                    key: const ValueKey('setting-store-address'),
                    controller: _storeAddress,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Store address',
                      helperText: 'Used for "Navigate to store"',
                      counterText: '',
                    ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    key: const ValueKey('setting-support-email'),
                    controller: _supportEmail,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      if (email.isEmpty) return null;
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(email)
                          ? null
                          : 'Enter a valid email address';
                    },
                    decoration: const InputDecoration(
                      labelText: 'Support email',
                      helperText: 'Leave empty to hide the email button',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment QR for cash orders',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Some cash-on-delivery customers prefer to pay by UPI at the '
              'door. Paste a link to a picture of your shop\'s UPI QR code. '
              'The rider shows it, the customer scans and pays into your '
              'account, and the rider photographs the customer\'s payment '
              'screen as proof, which you see on the order.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 480,
                  child: TextFormField(
                    key: const ValueKey('setting-payment-qr'),
                    controller: _paymentQr,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final link = v?.trim() ?? '';
                      if (link.isEmpty) return null;
                      return link.startsWith('https://')
                          ? null
                          : 'Enter a link that starts with https://';
                    },
                    decoration: const InputDecoration(
                      labelText: 'QR image link',
                      hintText: 'https://…/my-upi-qr.png',
                      helperText: 'Leave empty to take cash only',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (_paymentQr.text.trim().startsWith('https://'))
                  Container(
                    key: const ValueKey('payment-qr-preview'),
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      _paymentQr.text.trim(),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: FilledButton(
                key: const ValueKey('save-settings-button'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// On/off switch with the amount for one optional order charge.
class _ChargeControl extends StatelessWidget {
  const _ChargeControl({
    required this.keyName,
    required this.title,
    required this.hint,
    required this.enabled,
    required this.controller,
    required this.onToggle,
    required this.validator,
  });

  final String keyName;
  final String title;
  final String hint;
  final bool enabled;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      enabled ? 'On: added to orders' : 'Off: not charged',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            enabled ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: ValueKey('setting-$keyName-switch'),
                value: enabled,
                onChanged: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('setting-$keyName'),
            controller: controller,
            enabled: enabled,
            validator: validator,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: InputDecoration(
              labelText: 'Amount',
              helperText: hint,
              prefixText: '₹ ',
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniature of the banner as it appears in the app.
class BannerPreview extends StatelessWidget {
  const BannerPreview({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.colors,
    this.layout = 'classic',
    this.width = 250,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> colors;
  final String layout;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      // Same proportions as the card on a typical phone.
      height: width * 0.5,
      child: BannerArt(
        title: title.isEmpty ? 'Banner title' : title,
        subtitle: subtitle,
        emoji: emoji,
        colors: colors,
        layout: layout,
      ),
    );
  }
}

class _BannerRow extends ConsumerWidget {
  const _BannerRow({
    required this.banner,
    required this.categoryName,
    required this.onEdit,
  });

  final PromoBanner banner;
  final String categoryName;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(storefrontRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: banner.active ? 1 : 0.45,
                child: BannerPreview(
                  title: banner.title,
                  subtitle: banner.subtitle,
                  emoji: banner.emoji,
                  colors: banner.colors,
                  layout: banner.layout,
                  width: 210,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title.replaceAll('\n', ' '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Opens $categoryName',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusPill(
                banner.active ? 'Showing' : 'Hidden',
                banner.active ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Switch(
                key: ValueKey('banner-switch-${banner.id}'),
                value: banner.active,
                onChanged: (v) => repo.saveBanner(banner.copyWith(active: v)),
              ),
              IconButton(
                tooltip: 'Edit banner',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                key: ValueKey('delete-banner-${banner.id}'),
                tooltip: 'Delete banner',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: 'Delete this banner?',
                    message: 'It will be removed from the app home page.',
                    action: 'Delete',
                  );
                  if (ok) await repo.deleteBanner(banner.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerDialog extends ConsumerStatefulWidget {
  const _BannerDialog({this.banner, required this.categories});

  final PromoBanner? banner;
  final List<Category> categories;

  @override
  ConsumerState<_BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends ConsumerState<_BannerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.banner?.title);
  late final _subtitle = TextEditingController(text: widget.banner?.subtitle);
  late String _emoji = (widget.banner?.emoji.isEmpty ?? true)
      ? '🛒'
      : widget.banner!.emoji;
  // An old banner may carry a design key that no longer exists.
  late String _layout = kBannerLayouts.containsKey(widget.banner?.layout)
      ? widget.banner!.layout
      : kBannerLayouts.keys.first;
  // An old banner may carry a theme key that no longer exists.
  late String _theme = kBannerThemes.containsKey(widget.banner?.theme)
      ? widget.banner!.theme
      : kBannerThemes.keys.first;
  late String _categoryId = widget.categories
          .any((c) => c.id == widget.banner?.categoryId)
      ? widget.banner!.categoryId
      : widget.categories.first.id;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final banner = PromoBanner(
      id: widget.banner?.id ?? '',
      title: _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      emoji: _emoji,
      theme: _theme,
      layout: _layout,
      categoryId: _categoryId,
      active: widget.banner?.active ?? true,
      sortOrder: widget.banner?.sortOrder ?? 0,
    );
    try {
      await ref.read(storefrontRepositoryProvider).saveBanner(banner);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(context, 'Banner saved');
    } on AdminFailure catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't save the banner.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) =>
      (v?.trim().isEmpty ?? true) ? 'Required' : null;

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = kBannerThemes[_theme] ?? kBannerThemes.values.first;
    return AlertDialog(
      title: Text(widget.banner == null ? 'Add banner' : 'Edit banner'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: BannerPreview(
                    title: _title.text,
                    subtitle: _subtitle.text,
                    emoji: _emoji,
                    colors: colors,
                    layout: _layout,
                    width: 320,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('banner-title'),
                  controller: _title,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 2,
                  maxLength: 40,
                  validator: _required,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    helperText: 'Up to two short lines',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('banner-subtitle'),
                        controller: _subtitle,
                        maxLength: 40,
                        validator: _required,
                        onChanged: (_) => setState(() {}),
                        decoration:
                            const InputDecoration(labelText: 'Subtitle'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 120,
                      child: EmojiPickerField(
                        key: const ValueKey('banner-emoji'),
                        value: _emoji,
                        onChanged: (v) => setState(() => _emoji = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _sectionLabel('Design'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in kBannerLayouts.entries)
                      _LayoutChoice(
                        key: ValueKey('layout-${entry.key}'),
                        label: entry.value,
                        selected: entry.key == _layout,
                        onTap: () => setState(() => _layout = entry.key),
                        preview: BannerPreview(
                          title: 'Title',
                          subtitle: 'Subtitle',
                          emoji: _emoji,
                          colors: colors,
                          layout: entry.key,
                          width: 150,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _sectionLabel('Colour'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in kBannerThemes.entries)
                      Tooltip(
                        message: entry.key,
                        child: InkWell(
                          key: ValueKey('theme-${entry.key}'),
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _theme = entry.key),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: entry.value,
                              ),
                              border: Border.all(
                                color: entry.key == _theme
                                    ? AppColors.textDark
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: entry.key == _theme
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Opens category',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categoryId,
                      isExpanded: true,
                      items: [
                        for (final c in widget.categories)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v!),
                    ),
                  ),
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
          key: const ValueKey('save-banner-button'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

/// One selectable banner design: a small preview with its name.
class _LayoutChoice extends StatelessWidget {
  const _LayoutChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The preview is a picture here, not a control.
            ExcludeSemantics(child: preview),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
