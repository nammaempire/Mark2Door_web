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

  /// The month whose orders are counted; null means all time.
  DateTime? _month;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  static String _label(DateTime m) => '${_monthNames[m.month - 1]} ${m.year}';

  @override
  Widget build(BuildContext context) {
    final month = _month;
    // With a month chosen, only that month's orders are counted, so the
    // list is who ordered that month, with their orders and spend in it.
    final customers = ref.watch(topCustomersProvider(month));
    // A full mobile number finds a customer who is not among the biggest
    // spenders loaded on screen.
    final digits = _query.replaceAll(RegExp(r'[^0-9]'), '');
    final lookedUp = digits.length == 10 && digits == _query
        ? ref
            .watch(customerByPhoneProvider((phone: digits, month: month)))
            .valueOrNull
        : null;
    final now = DateTime.now();
    final months = [
      for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i),
    ];

    return AdminPage(
      title: 'Customers',
      subtitle: 'Everyone who has ordered, by total spend. Select a row to '
          'see their order history.',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                key: const ValueKey('customer-search'),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search name or mobile number',
                  prefixIcon: Icon(Icons.search_rounded),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Month',
                  prefixIcon: Icon(Icons.calendar_month_rounded),
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DateTime?>(
                    key: const ValueKey('customer-month'),
                    value: _month,
                    isExpanded: true,
                    isDense: true,
                    items: [
                      const DropdownMenuItem<DateTime?>(
                        value: null,
                        child: Text('All time'),
                      ),
                      for (final m in months)
                        DropdownMenuItem<DateTime?>(
                          value: m,
                          child: Text(_label(m)),
                        ),
                    ],
                    onChanged: (m) => setState(() => _month = m),
                  ),
                ),
              ),
            ),
            if (month != null)
              Text(
                '${customers.valueOrNull?.length ?? 0} customers ordered in '
                '${_label(month)}',
                key: const ValueKey('customer-month-count'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
          ],
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
            if (list.isEmpty && lookedUp != null) list.add(lookedUp);
            if (list.isEmpty) {
              return Panel(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      all.isEmpty
                          ? month != null
                              ? 'No customer ordered in ${_label(month)}.'
                              : 'No customers yet. They appear after their '
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
                              builder: (_) =>
                                  _CustomerDialog(customer: c, month: month),
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
                              DataCell(Text('${c.orderCount}')),
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
                  '${list.length} of ${all.length} customers'
                  '${all.length >= customerListLimit ? '. These are the '
                      '$customerListLimit biggest spenders; type a full '
                      'mobile number to find anyone else.' : ''}',
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

class _CustomerDialog extends ConsumerWidget {
  const _CustomerDialog({required this.customer, required this.month});

  final CustomerSummary customer;

  /// The month on screen; null for all time.
  final DateTime? month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Their orders are read when the row is opened.
    final history = ref.watch(
      customerOrdersProvider((phone: customer.phone, month: month)),
    );
    return AlertDialog(
      title: Text(customer.name),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '+91 ${customer.phone} · ${customer.orderCount} orders · '
              '${formatPaise(customer.spentPaise)} spent',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: history.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("Couldn't load their orders. Try again."),
                ),
                data: (orders) => ListView.separated(
                shrinkWrap: true,
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final o = orders[i];
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
                        StatusPill(o.statusLabel, orderStatusColor(o.status)),
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
