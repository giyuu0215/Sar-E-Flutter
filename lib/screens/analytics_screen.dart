import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.onOpenTransactions});

  final VoidCallback onOpenTransactions;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _period = 'week';

  final List<Map<String, num>> _weekly = <Map<String, num>>[
    <String, num>{'revenue': 3200, 'cogs': 2000, 'tx': 28},
    <String, num>{'revenue': 4800, 'cogs': 3000, 'tx': 42},
    <String, num>{'revenue': 3900, 'cogs': 2450, 'tx': 35},
    <String, num>{'revenue': 6200, 'cogs': 3900, 'tx': 54},
    <String, num>{'revenue': 8100, 'cogs': 5100, 'tx': 71},
    <String, num>{'revenue': 9400, 'cogs': 5900, 'tx': 83},
    <String, num>{'revenue': 5600, 'cogs': 3500, 'tx': 49},
  ];

  final List<Map<String, num>> _monthly = <Map<String, num>>[
    <String, num>{'revenue': 42000, 'cogs': 26500},
    <String, num>{'revenue': 38000, 'cogs': 24000},
    <String, num>{'revenue': 51000, 'cogs': 32000},
    <String, num>{'revenue': 46000, 'cogs': 29000},
    <String, num>{'revenue': 63000, 'cogs': 39800},
    <String, num>{'revenue': 71000, 'cogs': 44700},
    <String, num>{'revenue': 58000, 'cogs': 36500},
    <String, num>{'revenue': 76000, 'cogs': 47900},
    <String, num>{'revenue': 82000, 'cogs': 51700},
    <String, num>{'revenue': 69000, 'cogs': 43500},
    <String, num>{'revenue': 91000, 'cogs': 57300},
    <String, num>{'revenue': 105000, 'cogs': 66200},
  ];

  List<Map<String, num>> get _data => _period == 'week' ? _weekly : _monthly;
  double get _revenue => _data.fold<double>(
    0,
    (double s, Map<String, num> d) => s + d['revenue']!.toDouble(),
  );
  double get _cogs => _data.fold<double>(
    0,
    (double s, Map<String, num> d) => s + d['cogs']!.toDouble(),
  );
  double get _profit => _revenue - _cogs;
  double get _margin => _revenue == 0 ? 0 : (_profit / _revenue) * 100;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.analytics_outlined),
              const SizedBox(width: 8),
              Text('Analytics', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'week', label: Text('Week')),
                  ButtonSegment<String>(value: 'month', label: Text('Month')),
                ],
                selected: <String>{_period},
                onSelectionChanged: (Set<String> value) =>
                    setState(() => _period = value.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _KpiCard(
                label: 'Revenue',
                value: 'PHP ${(_revenue / 1000).toStringAsFixed(1)}k',
                color: c.primary,
              ),
              const SizedBox(width: 8),
              _KpiCard(
                label: 'COGS',
                value: 'PHP ${(_cogs / 1000).toStringAsFixed(1)}k',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _KpiCard(
                label: 'Gross Profit',
                value: 'PHP ${(_profit / 1000).toStringAsFixed(1)}k',
                color: c.accent,
              ),
              const SizedBox(width: 8),
              _KpiCard(
                label: 'Margin',
                value: '${_margin.toStringAsFixed(1)}%',
                color: c.info,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Revenue vs COGS'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _RevenueCogsChartPainter(
                        data: _data,
                        revenueColor: c.primary,
                        cogsColor: Colors.deepOrange,
                        gridColor: c.border,
                        textColor: c.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Sales by Category'),
                  const SizedBox(height: 8),
                  _categoryBar('Beverages', 28, c.primary),
                  _categoryBar('Noodles', 22, c.accent),
                  _categoryBar('Snacks', 18, c.info),
                  _categoryBar('Canned Goods', 20, Colors.deepOrange),
                  _categoryBar('Others', 12, c.primaryDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Recent Transactions'),
              subtitle: const Text('Open full transaction history'),
              trailing: TextButton(
                onPressed: widget.onOpenTransactions,
                child: const Text('View All'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryBar(String label, int percent, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percent%',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
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
    if (data.isEmpty) {
      return;
    }

    const double leftPad = 36;
    const double rightPad = 8;
    const double topPad = 8;
    const double bottomPad = 26;

    final Rect chart = Rect.fromLTWH(
      leftPad,
      topPad,
      math.max(1, size.width - leftPad - rightPad),
      math.max(1, size.height - topPad - bottomPad),
    );

    final double maxY =
        data
            .map(
              (Map<String, num> d) =>
                  math.max(d['revenue']!.toDouble(), d['cogs']!.toDouble()),
            )
            .reduce(math.max) *
        1.1;

    final Paint gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final double y = chart.top + (chart.height / 4) * i;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final List<Offset> revenuePoints = <Offset>[];
    final List<Offset> cogsPoints = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final double x =
          chart.left + (i / math.max(1, data.length - 1)) * chart.width;
      final double revY =
          chart.bottom - (data[i]['revenue']!.toDouble() / maxY) * chart.height;
      final double cogsY =
          chart.bottom - (data[i]['cogs']!.toDouble() / maxY) * chart.height;
      revenuePoints.add(Offset(x, revY));
      cogsPoints.add(Offset(x, cogsY));
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

    final Path revenuePath = makePath(revenuePoints);
    final Path cogsPath = makePath(cogsPoints);

    final Paint revPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = revenueColor;
    final Paint cogsPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = cogsColor;

    canvas.drawPath(revenuePath, revPaint);
    canvas.drawPath(cogsPath, cogsPaint);

    final TextPainter yTop = TextPainter(
      text: TextSpan(
        text: maxY.toStringAsFixed(0),
        style: TextStyle(fontSize: 10, color: textColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    yTop.paint(canvas, Offset(2, chart.top - 4));

    final TextPainter yBottom = TextPainter(
      text: TextSpan(
        text: '0',
        style: TextStyle(fontSize: 10, color: textColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    yBottom.paint(canvas, Offset(14, chart.bottom - 6));

    final List<String> labels = data.length == 7
        ? <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : <String>[
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];

    for (int i = 0; i < data.length && i < labels.length; i++) {
      final double x =
          chart.left + (i / math.max(1, data.length - 1)) * chart.width;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(fontSize: 10, color: textColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - (tp.width / 2), chart.bottom + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueCogsChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.revenueColor != revenueColor ||
        oldDelegate.cogsColor != cogsColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
