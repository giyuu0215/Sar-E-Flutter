import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../application/analytics_provider.dart';
import '../domain/entities/sales_summary.dart';
import '../domain/entities/transaction.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key, required this.onOpenTransactions});

  final VoidCallback onOpenTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(analyticsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(child: Text('Error: $e')),
          data: (AnalyticsState state) =>
              _AnalyticsContent(state: state, onOpenTransactions: onOpenTransactions),
        );
  }
}

class _AnalyticsContent extends ConsumerWidget {
  const _AnalyticsContent({
    required this.state,
    required this.onOpenTransactions,
  });

  final AnalyticsState state;
  final VoidCallback onOpenTransactions;

  Future<void> _exportPdf(BuildContext context) async {
    final pw.Document doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text('SarE Sales Report',
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  'Period: ${state.period.label}  •  Generated: ${DateFormat('MMM d, y HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: <String>[
                  'Metric',
                  'Value',
                ],
                data: <List<String>>[
                  <String>[
                    'Revenue',
                    'PHP ${state.revenue.toStringAsFixed(2)}'
                  ],
                  <String>[
                    'COGS',
                    'PHP ${state.cogs.toStringAsFixed(2)}'
                  ],
                  <String>[
                    'Gross Profit',
                    'PHP ${state.grossProfit.toStringAsFixed(2)}'
                  ],
                  <String>[
                    'Profit Margin',
                    '${state.profitMargin.toStringAsFixed(1)}%'
                  ],
                  <String>[
                    'Transactions',
                    '${state.txnCount}'
                  ],
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Top Products',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: <String>['Product', 'Qty Sold', 'Revenue'],
                data: state.topProducts
                    .map((TopProduct p) => <String>[
                          p.name,
                          '${p.totalQty}',
                          'PHP ${p.totalRevenue.toStringAsFixed(2)}',
                        ])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
        onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = appColors(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(children: <Widget>[
            const Icon(Icons.analytics_outlined),
            const SizedBox(width: 8),
            Text('Analytics',
                style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            // Refresh
            IconButton(
              onPressed: () =>
                  ref.read(analyticsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            // PDF export
            IconButton(
              onPressed: () => _exportPdf(context),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
            ),
          ]),
          const SizedBox(height: 10),

          // Period filter
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: AnalyticsPeriod.values.map((AnalyticsPeriod p) {
                final bool selected = state.period.label == p.label;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: selected,
                    onSelected: (_) => ref
                        .read(analyticsProvider.notifier)
                        .setPeriod(p),
                    selectedColor: c.primary.withValues(alpha: 0.15),
                    side: BorderSide(
                        color: selected ? c.primary : c.border),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // KPI cards
          Row(children: <Widget>[
            _KpiCard(
              label: 'Revenue',
              value: 'PHP ${state.revenue.toStringAsFixed(2)}',
              color: c.primary,
            ),
            const SizedBox(width: 8),
            _KpiCard(
              label: 'Profit',
              value: 'PHP ${state.grossProfit.toStringAsFixed(2)}',
              color: c.info,
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: <Widget>[
            _KpiCard(
              label: 'COGS',
              value: 'PHP ${state.cogs.toStringAsFixed(2)}',
              color: Colors.deepOrange,
            ),
            const SizedBox(width: 8),
            _KpiCard(
              label: 'Transactions',
              value: '${state.txnCount}',
              color: c.accent,
            ),
          ]),
          const SizedBox(height: 10),

          // Chart
          // Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Text('Revenue vs COGS',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Tooltip(
                        message:
                            'COGS = Cost of Goods Sold\nThe total cost price of all items sold.\nGross Profit = Revenue − COGS',
                        triggerMode: TooltipTriggerMode.tap,
                        child: Icon(Icons.info_outline,
                            size: 16, color: c.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.chartData.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No completed sales yet in this period',
                            style: TextStyle(
                                color: c.textTertiary, fontSize: 13)),
                      ),
                    )
                  else
                    SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _RevenueCogsChartPainter(
                          data: state.chartData
                              .map((Map<String, dynamic> r) =>
                                  <String, num>{
                                    'revenue':
                                        r['revenue'] as num? ?? 0,
                                    'cogs': r['cogs'] as num? ?? 0,
                                  })
                              .toList(),
                          revenueColor: c.primary,
                          cogsColor: Colors.deepOrange,
                          gridColor: c.border,
                          textColor: c.textTertiary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(children: <Widget>[
                    Container(
                        width: 12,
                        height: 3,
                        color: c.primary),
                    const SizedBox(width: 4),
                    Text('Revenue',
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 11)),
                    const SizedBox(width: 12),
                    Container(
                        width: 12,
                        height: 3,
                        color: Colors.deepOrange),
                    const SizedBox(width: 4),
                    Text('COGS (cost of goods sold)',
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 11)),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Top products
          if (state.topProducts.isNotEmpty) ...<Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Top Products'),
                    const SizedBox(height: 8),
                    ...state.topProducts
                        .take(5)
                        .toList()
                        .asMap()
                        .entries
                        .map((MapEntry<int, TopProduct> entry) {
                      final TopProduct p = entry.value;
                      final double maxRevenue =
                          state.topProducts.first.totalRevenue;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: <Widget>[
                          SizedBox(
                            width: 20,
                            child: Text(
                              '${entry.key + 1}.',
                              style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 11),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(p.name,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Expanded(
                            flex: 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maxRevenue > 0
                                    ? p.totalRevenue / maxRevenue
                                    : 0,
                                minHeight: 8,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        c.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${p.totalQty}x',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: c.primary)),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Recent transactions
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Recent Transactions'),
              subtitle: Text('${state.txnCount} in ${state.period.label}'),
              trailing: TextButton(
                onPressed: onOpenTransactions,
                child: const Text('View All'),
              ),
            ),
          ),

          // Recent list preview
          if (state.recentTransactions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...state.recentTransactions.take(5).map((Transaction t) {
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    t.paymentMethod == 'cash'
                        ? Icons.payments_outlined
                        : Icons.qr_code_outlined,
                    color: c.primary,
                    size: 20,
                  ),
                  title: Text(
                      'PHP ${t.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    DateFormat('MMM d, h:mm a').format(t.timestamp),
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.status == 'completed'
                          ? c.info.withValues(alpha: 0.12)
                          : c.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.status,
                      style: TextStyle(
                        color: t.status == 'completed'
                            ? c.info
                            : c.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _RevenueCogsChartPainter extends CustomPainter {
  _RevenueCogsChartPainter({
    required this.data,
    required this.revenueColor,
    required this.cogsColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<Map<String, num>> data;
  final Color revenueColor;
  final Color cogsColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double leftPad = 40;
    const double rightPad = 8;
    const double topPad = 8;
    const double bottomPad = 26;

    final Rect chart = Rect.fromLTWH(
      leftPad,
      topPad,
      math.max(1, size.width - leftPad - rightPad),
      math.max(1, size.height - topPad - bottomPad),
    );

    final double maxY = data
            .map((Map<String, num> d) => math.max(
                d['revenue']!.toDouble(), d['cogs']!.toDouble()))
            .reduce(math.max) *
        1.15;

    if (maxY <= 0) return;

    final Paint gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;

    for (int i = 0; i <= 4; i++) {
      final double y =
          chart.top + (chart.height / 4) * i;
      canvas.drawLine(
          Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final List<Offset> revPts = <Offset>[];
    final List<Offset> cogsPts = <Offset>[];
    // Use max(1, length-1) to avoid division by zero on single data point
    final int spread = math.max(1, data.length - 1);
    for (int i = 0; i < data.length; i++) {
      final double x = chart.left + (i / spread) * chart.width;
      revPts.add(Offset(
          x,
          chart.bottom -
              (data[i]['revenue']!.toDouble() / maxY) *
                  chart.height));
      cogsPts.add(Offset(
          x,
          chart.bottom -
              (data[i]['cogs']!.toDouble() / maxY) *
                  chart.height));
    }

    Path makePath(List<Offset> pts) {
      final Path p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        final Offset p0 = pts[i - 1];
        final Offset p1 = pts[i];
        final double cx = (p0.dx + p1.dx) / 2;
        p.quadraticBezierTo(cx, p0.dy, p1.dx, p1.dy);
      }
      return p;
    }

    canvas.drawPath(
        makePath(revPts),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = revenueColor);
    canvas.drawPath(
        makePath(cogsPts),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = cogsColor);
  }

  @override
  bool shouldRepaint(covariant _RevenueCogsChartPainter old) => true;
}
