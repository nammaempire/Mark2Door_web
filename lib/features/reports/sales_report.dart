import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/formatters.dart';
import '../../models/order.dart';

@immutable
class ReportDay {
  const ReportDay({
    required this.date,
    required this.orders,
    required this.revenuePaise,
  });

  final DateTime date;

  /// Orders that count as revenue.
  final int orders;
  final int revenuePaise;
}

/// Sales for an inclusive date range. Pure, so the on-screen numbers, the
/// CSV and the PDF all come from the same calculation.
@immutable
class SalesReport {
  const SalesReport({
    required this.from,
    required this.to,
    required this.revenuePaise,
    required this.revenueOrders,
    required this.cancelledOrders,
    required this.unpaidOrders,
    required this.codPaise,
    required this.onlinePaise,
    required this.deliveryFeesPaise,
    required this.days,
    required this.orders,
  });

  final DateTime from;
  final DateTime to;
  final int revenuePaise;
  final int revenueOrders;
  final int cancelledOrders;

  /// Online orders whose payment has not arrived (excluded from revenue).
  final int unpaidOrders;
  final int codPaise;
  final int onlinePaise;
  final int deliveryFeesPaise;

  /// One entry per calendar day in the range, oldest first, including
  /// days with no sales.
  final List<ReportDay> days;

  /// Every order placed in the range, newest first.
  final List<Order> orders;

  int get avgOrderPaise =>
      revenueOrders == 0 ? 0 : revenuePaise ~/ revenueOrders;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  factory SalesReport.from(List<Order> all, DateTime from, DateTime to) {
    final start = _day(from);
    final end = _day(to);
    final totals = <DateTime, (int orders, int paise)>{};
    for (var d = start;
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      totals[d] = (0, 0);
    }

    final inRange = <Order>[];
    var revenue = 0, count = 0, cancelled = 0, unpaid = 0;
    var cod = 0, online = 0, fees = 0;

    for (final order in all) {
      final day = _day(order.createdAt);
      if (!totals.containsKey(day)) continue;
      inRange.add(order);

      if (order.status == OrderStatus.cancelled) {
        cancelled++;
        continue;
      }
      if (!order.countsAsRevenue) {
        unpaid++;
        continue;
      }
      revenue += order.totalPaise;
      count++;
      fees += order.deliveryFeePaise;
      if (order.paymentMethod == PaymentMethod.cod) {
        cod += order.totalPaise;
      } else {
        online += order.totalPaise;
      }
      final t = totals[day]!;
      totals[day] = (t.$1 + 1, t.$2 + order.totalPaise);
    }
    inRange.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SalesReport(
      from: start,
      to: end,
      revenuePaise: revenue,
      revenueOrders: count,
      cancelledOrders: cancelled,
      unpaidOrders: unpaid,
      codPaise: cod,
      onlinePaise: online,
      deliveryFeesPaise: fees,
      days: [
        for (final e in totals.entries)
          ReportDay(date: e.key, orders: e.value.$1, revenuePaise: e.value.$2),
      ],
      orders: inRange,
    );
  }

  String get rangeLabel => from == to
      ? formatDate(from)
      : '${formatDate(from)} to ${formatDate(to)}';

  /// e.g. mart2door-sales-2026-11-01-to-2026-11-19
  String get fileStem => 'mart2door-sales-${_iso(from)}-to-${_iso(to)}';

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Plain rupees with two decimals: spreadsheet-friendly, no symbol.
  static String _rupees(int paise) => (paise / 100).toStringAsFixed(2);

  /// CSV that opens directly in Excel or Google Sheets: a summary, the
  /// day-by-day totals, then every order in the range.
  String toCsv() {
    final rows = <List<Object>>[
      ['mart2door sales report'],
      ['From', _iso(from)],
      ['To', _iso(to)],
      [],
      ['Summary'],
      ['Revenue (Rs)', _rupees(revenuePaise)],
      ['Orders counted', revenueOrders],
      ['Average order (Rs)', _rupees(avgOrderPaise)],
      ['Cash on delivery (Rs)', _rupees(codPaise)],
      ['Paid online (Rs)', _rupees(onlinePaise)],
      ['Delivery fees included (Rs)', _rupees(deliveryFeesPaise)],
      ['Cancelled orders', cancelledOrders],
      ['Online orders awaiting payment', unpaidOrders],
      [],
      ['Daily totals'],
      ['Date', 'Orders', 'Revenue (Rs)'],
      for (final d in days) [_iso(d.date), d.orders, _rupees(d.revenuePaise)],
      [],
      ['Orders'],
      [
        'Order', 'Placed', 'Customer', 'Phone', 'Pincode', 'Items',
        'Total (Rs)', 'Payment', 'Status', 'Rider', 'Counted as revenue',
      ],
      for (final o in orders)
        [
          o.displayId,
          '${_iso(o.createdAt)} ${formatTime(o.createdAt)}',
          o.address.name,
          o.address.phone,
          o.address.pincode,
          o.itemCount,
          _rupees(o.totalPaise),
          o.paymentLabel,
          o.status.label,
          o.riderName ?? '',
          o.countsAsRevenue ? 'Yes' : 'No',
        ],
    ];
    return rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
  }

  static String _csvCell(Object value) {
    var text = value.toString();
    // Neutralise spreadsheet formulas in user-entered text (CSV injection).
    if (text.isNotEmpty && '=+-@'.contains(text[0]) && value is String) {
      text = "'$text";
    }
    return text.contains(RegExp(r'[",\r\n]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  /// UTF-8 with a byte-order mark so Excel reads names correctly.
  Uint8List toCsvBytes() =>
      Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(toCsv())]);

  /// One-page-per-40-days PDF summary. Amounts use "Rs" because the PDF's
  /// built-in fonts have no rupee sign.
  Future<Uint8List> toPdfBytes() async {
    String rs(int paise) => 'Rs ${_rupees(paise)}';
    final doc = pw.Document(title: 'mart2door sales report');
    final heading = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            'mart2door sales report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(rangeLabel, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 18),
          pw.Text('Summary', style: heading),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Measure', 'Value'],
            cellAlignments: const {1: pw.Alignment.centerRight},
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            data: [
              ['Revenue', rs(revenuePaise)],
              ['Orders counted', '$revenueOrders'],
              ['Average order', rs(avgOrderPaise)],
              ['Cash on delivery', rs(codPaise)],
              ['Paid online', rs(onlinePaise)],
              ['Delivery fees included', rs(deliveryFeesPaise)],
              ['Cancelled orders', '$cancelledOrders'],
              ['Online orders awaiting payment', '$unpaidOrders'],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Daily totals', style: heading),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Orders', 'Revenue'],
            cellAlignments: const {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            data: [
              for (final d in days)
                [formatDate(d.date), '${d.orders}', rs(d.revenuePaise)],
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }
}
