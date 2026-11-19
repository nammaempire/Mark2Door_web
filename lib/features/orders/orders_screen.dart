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
      await ref.read(ordersRepositoryProvider).updateStatus(order.id, status);
      if (mounted) {
        showMessage(context, '${order.displayId} marked ${status.label}');
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
                                _RiderMenu(
                                  order: o,
                                  riders: riders,
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
        fontWeight: name == null && order.isActive
            ? FontWeight.w700
            : FontWeight.w400,
        color: name == null && order.isActive
            ? AppColors.primary
            : AppColors.textDark,
      ),
    );
    // Riders are only chosen for orders that still need delivering.
    if (!order.isActive) return label;
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

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.order, required this.onChanged});

  final Order order;
  final ValueChanged<OrderStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final pill = StatusPill(order.status.label, orderStatusColor(order.status));
    // Finished orders are final; only live ones can be moved.
    if (!order.isActive) return pill;
    return PopupMenuButton<OrderStatus>(
      key: ValueKey('status-${order.id}'),
      tooltip: 'Change status',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final s in OrderStatus.values)
          if (s != order.status)
            PopupMenuItem(value: s, child: Text('Mark ${s.label}')),
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

class _OrderDialog extends StatelessWidget {
  const _OrderDialog({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('Order ${order.displayId}')),
          StatusPill(order.status.label, orderStatusColor(order.status)),
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
              _line('Total', formatPaise(order.totalPaise), bold: true),
              _line('Payment', order.paymentLabel),
              _line('Rider', order.riderName ?? 'Not assigned'),
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
