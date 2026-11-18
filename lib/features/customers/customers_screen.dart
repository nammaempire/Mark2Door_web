import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../orders/orders_screen.dart';
import 'customer_stats.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers =
        ref.watch(ordersProvider).whenData(CustomerSummary.from);

    return AdminPage(
      title: 'Customers',
      subtitle: 'Everyone who has ordered, by total spend. Select a row to '
          'see their order history.',
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            key: const ValueKey('customer-search'),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Search name or mobile number',
              prefixIcon: Icon(Icons.search_rounded),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: customers,
          data: (all) {
            final list = all
                .where((c) =>
                    _query.isEmpty ||
                    c.name.toLowerCase().contains(_query) ||
                    c.phone.contains(_query))
                .toList();
            if (list.isEmpty) {
              return Panel(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      all.isEmpty
                          ? 'No customers yet. They appear after their '
                              'first order.'
                          : 'No customers match this search.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              );
            }
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
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Mobile')),
                        DataColumn(label: Text('Pincode')),
                        DataColumn(label: Text('Orders'), numeric: true),
                        DataColumn(label: Text('Total spent'), numeric: true),
                        DataColumn(label: Text('Last order')),
                      ],
                      rows: [
                        for (final c in list)
                          DataRow(
                            key: ValueKey('customer-${c.phone}'),
                            onSelectChanged: (_) => showDialog<void>(
                              context: context,
                              builder: (_) => _CustomerDialog(customer: c),
                            ),
                            cells: [
                              DataCell(Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              )),
                              DataCell(Text('+91 ${c.phone}')),
                              DataCell(Text(c.pincode)),
                              DataCell(Text('${c.orders.length}')),
                              DataCell(Text(
                                formatPaise(c.spentPaise),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              )),
                              DataCell(Text(formatDate(c.lastOrderAt))),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${list.length} of ${all.length} customers',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CustomerDialog extends StatelessWidget {
  const _CustomerDialog({required this.customer});

  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(customer.name),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '+91 ${customer.phone} · ${customer.orders.length} orders · '
              '${formatPaise(customer.spentPaise)} spent',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: customer.orders.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final o = customer.orders[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.displayId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                formatOrderDate(o.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(o.status.label, orderStatusColor(o.status)),
                        SizedBox(
                          width: 84,
                          child: Text(
                            formatPaise(o.totalPaise),
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
}
