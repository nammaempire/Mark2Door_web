import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class ServiceAreasScreen extends ConsumerStatefulWidget {
  const ServiceAreasScreen({super.key});

  @override
  ConsumerState<ServiceAreasScreen> createState() => _ServiceAreasScreenState();
}

class _ServiceAreasScreenState extends ConsumerState<ServiceAreasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (!_formKey.currentState!.validate()) return;
    final pincode = _controller.text.trim();
    try {
      await ref.read(areasRepositoryProvider).addArea(pincode);
      _controller.clear();
      if (mounted) showMessage(context, 'Now delivering to $pincode');
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't add that pincode.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(areasProvider);
    final repo = ref.read(areasRepositoryProvider);

    return AdminPage(
      title: 'Service areas',
      subtitle: 'Customers can only order to pincodes that are switched on.',
      children: [
        Panel(
          title: 'Add a pincode',
          child: Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    key: const ValueKey('pincode-field'),
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: Validators.pincode,
                    onFieldSubmitted: (_) => _add(),
                    decoration: const InputDecoration(hintText: '560034'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: FilledButton(
                    key: const ValueKey('add-pincode-button'),
                    onPressed: _add,
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AsyncView(
          value: areas,
          data: (list) => Panel(
            title:
                '${list.where((a) => a.active).length} of ${list.length} '
                'pincodes active',
            child: Column(
              children: [
                for (final (i, area) in list.indexed) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            area.pincode,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        StatusPill(
                          area.active ? 'Delivering' : 'Paused',
                          area.active ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          key: ValueKey('area-switch-${area.pincode}'),
                          value: area.active,
                          onChanged: (v) =>
                              repo.setActive(area.pincode, active: v),
                        ),
                        IconButton(
                          tooltip: 'Remove ${area.pincode}',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              title: 'Remove ${area.pincode}?',
                              message:
                                  'Customers in this pincode will no '
                                  'longer be able to order.',
                              action: 'Remove',
                            );
                            if (ok) await repo.removeArea(area.pincode);
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
