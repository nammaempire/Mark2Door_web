import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/download.dart';
import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'sales_report.dart';

enum _Preset {
  today('Today'),
  last7('Last 7 days'),
  thisMonth('This month'),
  lastMonth('Last month'),
  custom('Custom range');

  const _Preset(this.label);
  final String label;
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Preset _preset = _Preset.thisMonth;
  late DateTimeRange _range = _rangeFor(_Preset.thisMonth);
  bool _exporting = false;

  static DateTimeRange _rangeFor(_Preset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case _Preset.today:
        return DateTimeRange(start: today, end: today);
      case _Preset.last7:
        return DateTimeRange(
          start: DateTime(today.year, today.month, today.day - 6),
          end: today,
        );
      case _Preset.thisMonth:
      case _Preset.custom:
        return DateTimeRange(
          start: DateTime(today.year, today.month),
          end: today,
        );
      case _Preset.lastMonth:
        return DateTimeRange(
          start: DateTime(today.year, today.month - 1),
          // Day 0 of this month is the last day of the previous one.
          end: DateTime(today.year, today.month, 0),
        );
    }
  }

  Future<void> _select(_Preset preset) async {
    if (preset != _Preset.custom) {
      setState(() {
        _preset = preset;
        _range = _rangeFor(preset);
      });
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _range,
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
          child: child,
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _preset = _Preset.custom;
        _range = picked;
      });
    }
  }

  Future<void> _export(SalesReport report, {required bool pdf}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final ok = pdf
          ? downloadFile(
              '${report.fileStem}.pdf',
              'application/pdf',
              await report.toPdfBytes(),
            )
          : downloadFile(
              '${report.fileStem}.csv',
              'text/csv;charset=utf-8',
              report.toCsvBytes(),
            );
      if (mounted) {
        showMessage(
          context,
          ok
              ? 'Downloaded ${report.fileStem}.${pdf ? 'pdf' : 'csv'}'
              : 'Downloads work when the console runs in a browser.',
        );
      }
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't create the export.");
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(ordersProvider).whenData(
          (orders) => SalesReport.from(orders, _range.start, _range.end),
        );

    return AdminPage(
      title: 'Reports',
      subtitle: 'Sales for any period, with export for Excel or PDF.',
      actions: [
        if (report.valueOrNull case final r?) ...[
          OutlinedButton.icon(
            key: const ValueKey('export-csv-button'),
            onPressed: _exporting ? null : () => _export(r, pdf: false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(170, 48)),
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Export Excel'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('export-pdf-button'),
            onPressed: _exporting ? null : () => _export(r, pdf: true),
            style: OutlinedButton.styleFrom(minimumSize: const Size(150, 48)),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export PDF'),
          ),
        ],
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _Preset.values)
              ChoiceChip(
                key: ValueKey('preset-${p.name}'),
                label: Text(p.label),
                selected: _preset == p,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: _preset == p ? AppColors.primary : AppColors.border,
                ),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _preset == p ? Colors.white : AppColors.textDark,
                ),
                onSelected: (_) => _select(p),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: report,
          data: (r) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                r.rangeLabel,
                key: const ValueKey('report-range'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _Figure('Revenue', formatPaise(r.revenuePaise)),
                  _Figure('Orders counted', '${r.revenueOrders}'),
                  _Figure('Average order', formatPaise(r.avgOrderPaise)),
                  _Figure('Cash on delivery', formatPaise(r.codPaise)),
                  _Figure('Paid online', formatPaise(r.onlinePaise)),
                  _Figure('Cancelled', '${r.cancelledOrders}'),
                ],
              ),
              const SizedBox(height: 20),
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TableScroller(
                  child: DataTable(
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Orders'), numeric: true),
                      DataColumn(label: Text('Revenue'), numeric: true),
                    ],
                    rows: [
                      // Newest day first on screen; exports stay oldest first.
                      for (final d in r.days.reversed)
                        DataRow(
                          cells: [
                            DataCell(Text(formatDate(d.date))),
                            DataCell(Text('${d.orders}')),
                            DataCell(Text(
                              formatPaise(d.revenuePaise),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            )),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (r.unpaidOrders > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '${r.unpaidOrders} online order'
                  '${r.unpaidOrders == 1 ? ' is' : 's are'} awaiting payment '
                  'and not counted.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 188,
      child: Panel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
