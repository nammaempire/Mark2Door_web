import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/order.dart';
import '../../models/storefront.dart';

Color orderStatusColor(OrderStatus status) => switch (status) {
      OrderStatus.placed => AppColors.accentDark,
      OrderStatus.accepted => const Color(0xFF155FCB),
      OrderStatus.pickedUp => const Color(0xFF4B2FCB),
      OrderStatus.delivered => AppColors.success,
      OrderStatus.cancelled => AppColors.danger,
    };

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const _pageSize = 25;

  OrderStatus? _filter;
  int _visible = _pageSize;

  Future<void> _setStatus(Order order, OrderStatus status) async {
    if (status == order.status) return;
    if (status == OrderStatus.cancelled) {
      final ok = await confirm(
        context,
        title: 'Cancel order ${order.displayId}?',
        message: 'The customer will see this order as cancelled.',
        action: 'Cancel order',
      );
      if (!ok) return;
    }
    try {
      if (order.isCourier && status == OrderStatus.pickedUp) {
        // Shipping needs the courier and tracking number for the customer.
        final details = await showDialog<({String courier, String tracking})>(
          context: context,
          builder: (_) => _ShipDialog(order: order),
        );
        if (details == null) return;
        await ref.read(ordersRepositoryProvider).shipOrder(
              order.id,
              courier: details.courier,
              tracking: details.tracking,
            );
      } else {
        await ref.read(ordersRepositoryProvider).updateStatus(order.id, status);
      }
      if (mounted) {
        showMessage(
          context,
          '${order.displayId} marked ${order.labelFor(status)}',
        );
      }
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't update that order.");
    }
  }

  Future<void> _assign(Order order, Rider? rider) async {
    try {
      await ref.read(ordersRepositoryProvider).assignRider(order.id, rider);
      if (mounted) {
        showMessage(
          context,
          rider == null
              ? '${order.displayId} unassigned'
              : '${order.displayId} assigned to ${rider.name}',
        );
      }
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't update that order.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final riders = (ref.watch(ridersProvider).valueOrNull ?? const <Rider>[])
        .where((r) => r.active)
        .toList(growable: false);

    return AdminPage(
      title: 'Orders',
      subtitle: 'Newest first. Change a status to move an order along.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('All', null),
            for (final s in OrderStatus.values) _chip(s.label, s),
          ],
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: orders,
          data: (all) {
            final list = _filter == null
                ? all
                : all.where((o) => o.status == _filter).toList();
            if (list.isEmpty) {
              return const Panel(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No orders in this view.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              );
            }
            final shown = list.take(_visible).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TableScroller(
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                      columns: const [
                        DataColumn(label: Text('Order')),
                        DataColumn(label: Text('Placed')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Items'), numeric: true),
                        DataColumn(label: Text('Total'), numeric: true),
                        DataColumn(label: Text('Payment')),
                        DataColumn(label: Text('Rider')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: [
                        for (final o in shown)
                          DataRow(
                            onSelectChanged: (_) => showDialog<void>(
                              context: context,
                              builder: (_) => _OrderDialog(order: o),
                            ),
                            cells: [
                              DataCell(
                                Text(
                                  o.displayId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(Text(formatOrderDate(o.createdAt))),
                              DataCell(
                                Text(
                                  '${o.address.name} · ${o.address.pincode}',
                                ),
                              ),
                              DataCell(Text('${o.itemCount}')),
                              DataCell(
                                Text(
                                  formatPaise(o.totalPaise),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(Text(o.paymentLabel)),
                              DataCell(
                                o.isCourier
                                    ? _CourierCell(order: o)
                                    : _RiderMenu(
                                        order: o,
                                        // Only riders of the order's
                                        // own store can take it.
                                        riders: o.storeId == null
                                            ? riders
                                            : riders
                                                .where((r) =>
                                                    r.storeId == o.storeId)
                                                .toList(),
                                        onChanged: (r) => _assign(o, r),
                                      ),
                              ),
                              DataCell(
                                _StatusMenu(
                                  order: o,
                                  onChanged: (s) => _setStatus(o, s),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${shown.length} of ${list.length}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    if (shown.length < list.length)
                      TextButton(
                        onPressed: () => setState(() => _visible += _pageSize),
                        child: const Text('Show more'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _chip(String label, OrderStatus? status) {
    final selected = _filter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : AppColors.textDark,
      ),
      onSelected: (_) => setState(() {
        _filter = status;
        _visible = _pageSize;
      }),
    );
  }
}

/// The rider column for an Outstation order: it goes by courier, so there
/// is no rider to choose; shows the tracking number once shipped.
class _CourierCell extends StatelessWidget {
  const _CourierCell({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final tracking = order.trackingNumber ?? '';
    return Column(
      key: ValueKey('courier-${order.id}'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_shipping_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              order.courierName ?? 'Outstation',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (tracking.isNotEmpty)
          SelectableText(
            tracking,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

/// Asks for the courier's name and the tracking number when a courier
/// order is marked shipped. The customer sees both on their order.
class _ShipDialog extends StatefulWidget {
  const _ShipDialog({required this.order});

  final Order order;

  @override
  State<_ShipDialog> createState() => _ShipDialogState();
}

class _ShipDialogState extends State<_ShipDialog> {
  final _formKey = GlobalKey<FormState>();
  final _courier = TextEditingController();
  final _tracking = TextEditingController();

  @override
  void dispose() {
    _courier.dispose();
    _tracking.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      (courier: _courier.text.trim(), tracking: _tracking.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ship order ${widget.order.displayId}'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The customer is told the order has shipped and sees these '
                'details. After this the order can no longer be cancelled by '
                'the customer.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('ship-courier'),
                controller: _courier,
                autofocus: true,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Enter the delivery service, like DTDC'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Delivery service',
                  hintText: 'DTDC',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('ship-tracking'),
                controller: _tracking,
                maxLength: 40,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Enter the tracking number'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Tracking number',
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          key: const ValueKey('ship-confirm'),
          onPressed: _submit,
          child: const Text('Mark shipped'),
        ),
      ],
    );
  }
}

/// Sentinel so "Unassign" can be a real menu value (null means dismissed).
const _noRider = Rider(id: '', name: '', phone: '');

class _RiderMenu extends StatelessWidget {
  const _RiderMenu({
    required this.order,
    required this.riders,
    required this.onChanged,
  });

  final Order order;
  final List<Rider> riders;
  final ValueChanged<Rider?> onChanged;

  @override
  Widget build(BuildContext context) {
    final name = order.riderName;
    final label = Text(
      name ?? (order.isActive ? 'Assign' : '–'),
      style: TextStyle(
        fontWeight:
            name == null && order.isActive ? FontWeight.w700 : FontWeight.w400,
        color: name == null && order.isActive
            ? AppColors.primary
            : AppColors.textDark,
      ),
    );
    // Riders are only chosen for orders that still need delivering.
    if (!order.isActive) return label;
    // Not paid yet: nothing to deliver until the customer pays online.
    if (order.awaitingPayment && name == null) {
      return Text(
        'Awaiting payment',
        key: ValueKey('awaiting-payment-${order.id}'),
        style: const TextStyle(color: AppColors.textMuted),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _menu(label),
        if (order.hasOpenRejection)
          _RiderAlert(
            key: ValueKey('rejected-${order.id}'),
            text: 'Rejected: ${order.rejectReason}',
            tooltip: '${order.rejectedByName ?? 'Rider'} rejected this order: '
                '${order.rejectReason}',
          )
        else
          _AwaitingRider(order: order),
      ],
    );
  }

  Widget _menu(Widget label) {
    return PopupMenuButton<Rider>(
      key: ValueKey('rider-${order.id}'),
      tooltip: 'Assign rider',
      onSelected: (r) => onChanged(identical(r, _noRider) ? null : r),
      itemBuilder: (context) => [
        if (riders.isEmpty)
          const PopupMenuItem(
            enabled: false,
            child: Text('No riders available. Add one under Riders.'),
          ),
        for (final r in riders)
          if (r.id != order.riderId)
            PopupMenuItem(value: r, child: Text(r.name)),
        if (order.riderId != null)
          const PopupMenuItem(value: _noRider, child: Text('Unassign')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          label,
          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// The rider's proof-of-delivery photo. Clicking it opens a larger view
/// that can be zoomed.
class _DeliveryPhoto extends StatelessWidget {
  const _DeliveryPhoto({super.key, required this.url});

  final String url;

  Widget _image({required BoxFit fit}) => Image.network(
        url,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stack) => const Center(
          child: Text(
            "Couldn't load the photo",
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('delivery-photo'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
            child: InteractiveViewer(child: _image(fit: BoxFit.contain)),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: ColoredBox(
            color: AppColors.primarySoft,
            child: _image(fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// Small red line under the rider's name in the orders table.
class _RiderAlert extends StatelessWidget {
  const _RiderAlert({super.key, required this.text, required this.tooltip});

  final String text;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: AppColors.danger,
          ),
        ),
      ),
    );
  }
}

/// Warns when the assigned rider has not accepted within five minutes.
/// Checks the clock itself so the warning appears without a data change.
class _AwaitingRider extends StatefulWidget {
  const _AwaitingRider({required this.order});

  final Order order;

  @override
  State<_AwaitingRider> createState() => _AwaitingRiderState();
}

class _AwaitingRiderState extends State<_AwaitingRider> {
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final order = widget.order;
    if (!order.isAwaitingRiderAt(now)) return const SizedBox.shrink();
    final minutes = now.difference(order.assignedAt!).inMinutes;
    return _RiderAlert(
      key: ValueKey('awaiting-${order.id}'),
      text: 'Not accepted · $minutes min',
      tooltip: '${order.riderName} has not accepted this order for '
          '$minutes minutes. You can assign another rider.',
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.order, required this.onChanged});

  final Order order;
  final ValueChanged<OrderStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final pill = StatusPill(order.statusLabel, orderStatusColor(order.status));
    // Finished orders are final; only live ones can be moved.
    if (!order.isActive) return pill;
    return PopupMenuButton<OrderStatus>(
      key: ValueKey('status-${order.id}'),
      tooltip: 'Change status',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final s in OrderStatus.values)
          if (s != order.status)
            PopupMenuItem(
              value: s,
              child: Text('Mark ${order.labelFor(s)}'),
            ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill,
          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _OrderDialog extends ConsumerWidget {
  const _OrderDialog({required this.order});

  final Order order;

  Future<void> _markRefunded(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Mark ${order.displayId} as refunded?',
      message:
          'Do this after you have returned ${formatPaise(order.totalPaise)} '
          'to the customer. They will see the order as refunded.',
      action: 'Mark refunded',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(ordersRepositoryProvider).markRefunded(order.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showMessage(context, '${order.displayId} marked refunded');
    } catch (_) {
      if (context.mounted) showMessage(context, "Couldn't update that order.");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('Order ${order.displayId}')),
          StatusPill(order.statusLabel, orderStatusColor(order.status)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatOrderDate(order.createdAt),
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.name} (${item.unit}) × ${item.quantity}',
                        ),
                      ),
                      Text(formatPaise(item.lineTotalPaise)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              _line('Item total', formatPaise(order.subtotalPaise)),
              _line(
                'Delivery fee',
                order.deliveryFeePaise == 0
                    ? 'FREE'
                    : formatPaise(order.deliveryFeePaise),
              ),
              if (order.handlingFeePaise > 0)
                _line('Handling fee', formatPaise(order.handlingFeePaise)),
              if (order.rainFeePaise > 0)
                _line('Rain charge', formatPaise(order.rainFeePaise)),
              if (order.couponDiscountPaise > 0)
                _line(
                  'Coupon ${order.couponCode ?? ''}'.trim(),
                  '- ${formatPaise(order.couponDiscountPaise)}',
                ),
              _line('Total', formatPaise(order.totalPaise), bold: true),
              if (order.walletAppliedPaise > 0) ...[
                _line(
                  'Paid from m2d wallet',
                  '- ${formatPaise(order.walletAppliedPaise)}',
                ),
                _line(
                  order.paymentMethod == PaymentMethod.cod
                      ? 'Cash to collect'
                      : 'Paid online',
                  formatPaise(order.payablePaise),
                ),
              ],
              _line('Payment', order.paymentLabel),
              if (order.status == OrderStatus.cancelled &&
                  order.cancelledBy == 'customer')
                _line('Cancelled by', 'Customer, in the app'),
              if (order.status == OrderStatus.cancelled &&
                  order.cancelledForPrice)
                _line(
                  'Cancelled by',
                  'Price check. ${order.priceCheckNote ?? 'The total was '
                      'below the store prices.'}',
                ),
              _line('Rider', order.riderName ?? 'Not assigned'),
              if (order.riderRating != null)
                _line('Delivery rating', '${order.riderRating} of 5 stars'),
              if (order.status == OrderStatus.delivered &&
                  order.paymentMethod == PaymentMethod.cod &&
                  !order.paidByQr &&
                  order.riderId != null)
                _line(
                  'Cash from rider',
                  order.cashHandedOver ? 'Received' : 'With rider',
                ),
              if (order.paidByQr) ...[
                _line(
                  'Paid at the door',
                  (order.paymentProofUrl ?? '').startsWith('http')
                      ? 'By QR scan · proof photo below'
                      : 'By QR scan',
                ),
                if ((order.paymentProofUrl ?? '').startsWith('http')) ...[
                  const SizedBox(height: 8),
                  _DeliveryPhoto(
                    key: const ValueKey('payment-proof-photo'),
                    url: order.paymentProofUrl!,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (order.status == OrderStatus.delivered)
                _line(
                  'Delivery photo',
                  (order.deliveryPhotoUrl ?? '').isEmpty
                      ? 'None'
                      : 'Below · click to enlarge',
                ),
              if ((order.deliveryPhotoUrl ?? '').startsWith('http')) ...[
                const SizedBox(height: 8),
                _DeliveryPhoto(url: order.deliveryPhotoUrl!),
              ],
              if ((order.rejectReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('reject-reason'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rejected by '
                        '${(order.rejectedByName ?? '').isEmpty ? 'rider' : order.rejectedByName}'
                        '${order.rejectedAt == null ? '' : ' · ${formatOrderDate(order.rejectedAt!)}'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(order.rejectReason!),
                    ],
                  ),
                ),
              ],
              const Divider(height: 24),
              Text(
                order.address.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(order.address.singleLine),
              Text(order.address.phone),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (order.needsRefund)
          FilledButton(
            key: const ValueKey('mark-refunded-button'),
            onPressed: () => _markRefunded(context, ref),
            style: FilledButton.styleFrom(minimumSize: const Size(150, 48)),
            child: const Text('Mark refunded'),
          ),
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      color: AppColors.textDark,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
