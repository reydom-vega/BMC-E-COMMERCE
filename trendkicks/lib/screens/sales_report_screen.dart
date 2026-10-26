import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/ui.dart';
import '../core/theme.dart';
import '../services/store_backend.dart';

DateTime manilaToday([DateTime? instant]) {
  final p = (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  return DateTime.utc(p.year, p.month, p.day);
}

(DateTime, DateTime) reportRange(String preset, [DateTime? instant]) {
  final today = manilaToday(instant);
  return (
    switch (preset) {
      'Last 7 days' => today.subtract(const Duration(days: 6)),
      'Last 30 days' => today.subtract(const Duration(days: 29)),
      'This month' => DateTime.utc(today.year, today.month),
      _ => today,
    },
    today,
  );
}

String _day(DateTime d) => d.toIso8601String().substring(0, 10);

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});
  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  String preset = 'Last 30 days';
  late DateTime start = reportRange(preset).$1, end = reportRange(preset).$2;
  int version = 0;
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Sales analytics')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: preset,
                items: [
                  for (final v in [
                    'Today',
                    'Last 7 days',
                    'Last 30 days',
                    'This month',
                    'Custom',
                  ])
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) async {
                  if (v == 'Custom') {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      initialDateRange: DateTimeRange(start: start, end: end),
                    );
                    if (range == null || !mounted) return;
                    setState(() {
                      preset = v!;
                      start = range.start;
                      end = range.end;
                      version++;
                    });
                  } else {
                    final range = reportRange(v!);
                    setState(() {
                      preset = v;
                      start = range.$1;
                      end = range.$2;
                      version++;
                    });
                  }
                },
              ),
              Text('${_day(start)} – ${_day(end)} · Asia/Manila'),
            ],
          ),
        ),
        Expanded(
          child: AsyncContent<Map<String, dynamic>>(
            key: ValueKey(version),
            load: () async => Map<String, dynamic>.from(
              await context.read<StoreBackend>().db.rpc(
                'tk_sales_report',
                params: {'p_start': _day(start), 'p_end': _day(end)},
              ),
            ),
            builder: (context, data, refresh) => ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const Text(
                  'Collected payments',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
                ),
                const Text(
                  'PHP · Verified Xendit receipts and delivered COD collection. Refunds use their settlement date. Gross includes shipping; discounts reduce merchandise. Pending payments are excluded.',
                ),
                if ((data['legacy_payment_dates'] as num) > 0)
                  const Text(
                    'Some historical paid orders use their last update date because a verified timestamp was not stored by the old app.',
                  ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final e in {
                      'Gross sales': 'gross_cents',
                      'Voucher discounts': 'voucher_cents',
                      'Rewards discounts': 'loyalty_cents',
                      'Collected': 'collected_cents',
                      'Refunds settled': 'refund_cents',
                      'Net collected': 'net_cents',
                      'Average paid order': 'average_cents',
                      'Sales today': 'today_cents',
                      'Last 7 days sales': 'week_cents',
                      'This month sales': 'month_cents',
                      'All time collected': 'all_time_cents',
                    }.entries)
                      SizedBox(
                        width: 215,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.key),
                                Text(
                                  money((data[e.value] as num).round()),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Orders ${data['orders']} · Paid ${data['paid_orders']} · Pending ${data['pending_orders']} · Cancelled ${data['cancelled_orders']}',
                ),
                Text(
                  'Low-stock variants ${data['low_stock']} · Out-of-stock variants ${data['out_of_stock']}',
                ),
                Text(
                  'Voucher uses ${data['voucher_uses']} · Redeemed points ${data['redeemed_points']}',
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          await perform(
                            context,
                            () => downloadSalesReport(data),
                          );
                          if (mounted) setState(() => busy = false);
                        },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(busy ? 'Preparing…' : 'Download report'),
                ),
                _ReportBars(
                  title: 'Daily collected sales',
                  rows: List<Map<String, dynamic>>.from(data['daily']),
                  labelKey: 'sale_day',
                  valueKey: 'cents',
                  currency: true,
                ),
                _ReportBars(
                  title: 'Monthly collected sales',
                  rows: List<Map<String, dynamic>>.from(data['monthly']),
                  labelKey: 'sale_month',
                  valueKey: 'cents',
                  currency: true,
                ),
                _ReportBars(
                  title: 'Bestselling sneakers / product performance',
                  rows: List<Map<String, dynamic>>.from(data['products']),
                  labelKey: 'name',
                  valueKey: 'quantity',
                ),
                _ReportBars(
                  title: 'Order status distribution',
                  rows: List<Map<String, dynamic>>.from(data['statuses']),
                  labelKey: 'status',
                  valueKey: 'count',
                ),
                _ReportBars(
                  title: 'Payment method breakdown',
                  rows: List<Map<String, dynamic>>.from(data['methods']),
                  labelKey: 'payment_method',
                  valueKey: 'cents',
                  currency: true,
                ),
                TextButton(
                  onPressed: refresh,
                  child: const Text('Refresh report'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReportBars extends StatelessWidget {
  const _ReportBars({
    required this.title,
    required this.rows,
    required this.labelKey,
    required this.valueKey,
    this.currency = false,
  });
  final String title, labelKey, valueKey;
  final List<Map<String, dynamic>> rows;
  final bool currency;
  @override
  Widget build(BuildContext context) {
    final max = rows.fold<num>(
      1,
      (s, e) => (e[valueKey] as num) > s ? e[valueKey] as num : s,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (rows.isEmpty) const Text('No data for this range.'),
          for (final r in rows.take(31))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r[labelKey]} · ${currency ? money((r[valueKey] as num).round()) : r[valueKey]}',
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (r[valueKey] as num) / max,
                    minHeight: 10,
                    color: context.accentColor,
                    backgroundColor: context.borderColor,
                  ),
                ],
              ),
            ),
          if (rows.length > 31)
            const Text('Showing 31 rows. The PDF includes the complete range.'),
        ],
      ),
    );
  }
}

Future<void> downloadSalesReport(Map<String, dynamic> data) async {
  await Printing.sharePdf(
    bytes: await salesReportBytes(data),
    filename: 'TrendKicks-sales-${data['start']}-${data['end']}.pdf',
  );
}

Future<Uint8List> salesReportBytes(Map<String, dynamic> data) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope.ttf'));
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/branding/wordmark.png')).buffer
        .asUint8List(),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Image(logo, height: 50),
        pw.Text('Sales report', style: pw.TextStyle(fontSize: 24)),
        pw.Text('${data['start']} – ${data['end']} · Asia/Manila · PHP'),
        pw.Text(
          'Collected payments only. Pending invoices and uncollected COD are excluded. Refunds use verified settlement dates. Gross includes shipping. Discounts apply to merchandise. Net = collected minus settlements in this period.',
        ),
        pw.SizedBox(height: 16),
        for (final e in {
          'Gross': 'gross_cents',
          'Voucher discounts': 'voucher_cents',
          'Rewards discounts': 'loyalty_cents',
          'Collected': 'collected_cents',
          'Refunds': 'refund_cents',
          'Net collected': 'net_cents',
          'Average order': 'average_cents',
        }.entries)
          pw.Text(
            '${e.key}: PHP ${((data[e.value] as num) / 100).toStringAsFixed(2)}',
          ),
        pw.Text(
          'Orders: ${data['orders']} · Paid: ${data['paid_orders']} · Cancelled: ${data['cancelled_orders']}',
        ),
        pw.Text(
          'Voucher uses: ${data['voucher_uses']} · Redeemed points: ${data['redeemed_points']}',
        ),
        if ((data['legacy_payment_dates'] as num) > 0)
          pw.Text(
            'Historical paid orders without paid_at use their last update date.',
          ),
        pw.SizedBox(height: 16),
        pw.Text('Daily collected revenue'),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'PHP collected'],
          data: [
            for (final r in data['daily'])
              [r['sale_day'], ((r['cents'] as num) / 100).toStringAsFixed(2)],
          ],
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Monthly collected revenue'),
        pw.TableHelper.fromTextArray(
          headers: ['Month', 'PHP collected'],
          data: [
            for (final r in data['monthly'])
              [r['sale_month'], ((r['cents'] as num) / 100).toStringAsFixed(2)],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('Bestsellers / product gross before order discounts'),
        pw.TableHelper.fromTextArray(
          headers: ['Sneaker', 'Quantity', 'PHP gross merchandise'],
          data: [
            for (final p in data['products'])
              [
                p['name'],
                p['quantity'],
                ((p['gross_cents'] as num) / 100).toStringAsFixed(2),
              ],
          ],
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
      ],
    ),
  );
  return doc.save();
}

class OverviewSalesSummary extends StatelessWidget {
  const OverviewSalesSummary({super.key});
  @override
  Widget build(BuildContext context) => AsyncContent<Map<String, dynamic>>(
    load: () async {
      final range = reportRange('Last 30 days');
      return Map<String, dynamic>.from(
        await context.read<StoreBackend>().db.rpc(
          'tk_sales_report',
          params: {'p_start': _day(range.$1), 'p_end': _day(range.$2)},
        ),
      );
    },
    builder: (context, data, refresh) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Collected sales · last 30 days',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in {
                'Gross': 'gross_cents',
                'Discounts': 'voucher_cents',
                'Rewards used': 'loyalty_cents',
                'Refunds settled': 'refund_cents',
                'Net collected': 'net_cents',
              }.entries)
                SizedBox(
                  width: 180,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key),
                          Text(
                            money((data[e.value] as num).round()),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Text(
            'Unpaid invoices and uncollected COD are excluded. View Sales reports for date filters and the full breakdown.',
          ),
        ],
      ),
    ),
  );
}
