import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'product_requests.dart';

/// Products customers asked for because they could not find them in the
/// app. Each row has what to get and who to call.
class ProductRequestsScreen extends ConsumerWidget {
  const ProductRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(productRequestsProvider);
    final repo = ref.read(productRequestsRepositoryProvider);
    return AdminPage(
      title: 'Product requests',
      subtitle: 'Products customers asked for. Call them with how long it '
          'will take.',
      children: [
        AsyncView(
          value: requests,
          data: (list) => Panel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No requests yet. When a customer cannot find a '
                      'product and asks for it in the app, it shows here.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : TableScroller(
                    child: DataTable(
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: double.infinity,
                      columnSpacing: 28,
                      horizontalMargin: 20,
                      columns: const [
                        DataColumn(label: Text('Asked on')),
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Quantity')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Number')),
                        DataColumn(label: Text('Pincode')),
                        DataColumn(label: Text('Called')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final r in list)
                          DataRow(
                            key: ValueKey('request-${r.id}'),
                            cells: [
                              DataCell(Text(formatOrderDate(r.createdAt))),
                              DataCell(
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 260),
                                  child: Text(
                                    r.product,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(r.quantity)),
                              DataCell(
                                Text(
                                  r.customerName.isEmpty
                                      ? '–'
                                      : r.customerName,
                                ),
                              ),
                              DataCell(SelectableText(r.phone)),
                              DataCell(
                                Text(r.pincode.isEmpty ? '–' : r.pincode),
                              ),
                              DataCell(
                                Switch(
                                  key: ValueKey('request-called-${r.id}'),
                                  value: r.contacted,
                                  onChanged: (v) =>
                                      repo.setContacted(r.id, v),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  key: ValueKey('request-delete-${r.id}'),
                                  tooltip: 'Delete request',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  onPressed: () async {
                                    final yes = await confirm(
                                      context,
                                      title: 'Delete this request?',
                                      message: '${r.product} for '
                                          '${r.customerName.isEmpty ? r.phone : r.customerName} '
                                          'will be removed from the list.',
                                      action: 'Delete',
                                    );
                                    if (yes) await repo.delete(r.id);
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
