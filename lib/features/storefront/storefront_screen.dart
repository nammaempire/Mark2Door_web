import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              '${s.deliveryEtaMinutes}',
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
  bool _saving = false;

  @override
  void dispose() {
    _fee.dispose();
    _threshold.dispose();
    _eta.dispose();
    super.dispose();
  }

  String? _money(String? v) => parseRupeesToPaise(v ?? '') == null
      ? 'Enter an amount like 30 or 29.50'
      : null;

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

/// Miniature of the banner as it appears in the app.
class BannerPreview extends StatelessWidget {
  const BannerPreview({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.colors,
    this.width = 250,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> colors;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 0.48,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.isEmpty ? 'Banner title' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 44,
              fontFamilyFallback: ['Noto Color Emoji'],
            ),
          ),
        ],
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
  late final _emoji = TextEditingController(text: widget.banner?.emoji ?? '🛒');
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
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final banner = PromoBanner(
      id: widget.banner?.id ?? '',
      title: _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      emoji: _emoji.text.trim(),
      theme: _theme,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.banner == null ? 'Add banner' : 'Edit banner'),
      content: SizedBox(
        width: 480,
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
                    emoji: _emoji.text,
                    colors: kBannerThemes[_theme] ?? kBannerThemes.values.first,
                    width: 300,
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
                      width: 100,
                      child: TextFormField(
                        controller: _emoji,
                        validator: _required,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Emoji'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Colour',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final entry in kBannerThemes.entries)
                      Tooltip(
                        message: entry.key,
                        child: InkWell(
                          key: ValueKey('theme-${entry.key}'),
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _theme = entry.key),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: entry.value),
                              border: Border.all(
                                color: entry.key == _theme
                                    ? AppColors.textDark
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
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
