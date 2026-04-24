import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/daos/transaction_dao.dart';
import '../domain/entities/sales_summary.dart';
import '../domain/entities/transaction.dart';

class AnalyticsPeriod {
  const AnalyticsPeriod._(this.label, this.days);

  final String label;
  final int days;

  static const AnalyticsPeriod daily = AnalyticsPeriod._('Today', 1);
  static const AnalyticsPeriod weekly = AnalyticsPeriod._('This Week', 7);
  static const AnalyticsPeriod monthly = AnalyticsPeriod._('This Month', 30);

  static const List<AnalyticsPeriod> values = <AnalyticsPeriod>[
    daily,
    weekly,
    monthly,
  ];
}

class AnalyticsState {
  const AnalyticsState({
    this.period = AnalyticsPeriod.weekly,
    this.revenue = 0,
    this.cogs = 0,
    this.grossProfit = 0,
    this.txnCount = 0,
    this.topProducts = const <TopProduct>[],
    this.chartData = const <Map<String, dynamic>>[],
    this.recentTransactions = const <Transaction>[],
    this.isLoading = false,
  });

  final AnalyticsPeriod period;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final int txnCount;
  final List<TopProduct> topProducts;
  final List<Map<String, dynamic>> chartData;
  final List<Transaction> recentTransactions;
  final bool isLoading;

  double get profitMargin =>
      revenue > 0 ? (grossProfit / revenue) * 100 : 0;

  AnalyticsState copyWith({
    AnalyticsPeriod? period,
    double? revenue,
    double? cogs,
    double? grossProfit,
    int? txnCount,
    List<TopProduct>? topProducts,
    List<Map<String, dynamic>>? chartData,
    List<Transaction>? recentTransactions,
    bool? isLoading,
  }) =>
      AnalyticsState(
        period: period ?? this.period,
        revenue: revenue ?? this.revenue,
        cogs: cogs ?? this.cogs,
        grossProfit: grossProfit ?? this.grossProfit,
        txnCount: txnCount ?? this.txnCount,
        topProducts: topProducts ?? this.topProducts,
        chartData: chartData ?? this.chartData,
        recentTransactions: recentTransactions ?? this.recentTransactions,
        isLoading: isLoading ?? this.isLoading,
      );
}

class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  final TransactionDao _dao = TransactionDao();

  @override
  Future<AnalyticsState> build() async => _load(AnalyticsPeriod.weekly);

  Future<AnalyticsState> _load(AnalyticsPeriod period) async {
    final DateTime now = DateTime.now();
    final DateTime start =
        DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: period.days - 1));
    final DateTime end =
        DateTime(now.year, now.month, now.day, 23, 59, 59);

    final Map<String, double> summary =
        await _dao.getSummaryForRange(start, end);
    final List<Map<String, dynamic>> topRaw =
        await _dao.getTopProducts(start, end);
    final List<Map<String, dynamic>> chart =
        await _dao.getDailyChart(period.days);
    final List<Transaction> recent = await _dao.getRecent(limit: 20);

    final List<TopProduct> top = topRaw
        .map((Map<String, dynamic> r) => TopProduct(
              productId: r['product_id'] as String,
              name: r['name'] as String,
              totalQty: (r['total_qty'] as num).toInt(),
              totalRevenue: (r['total_revenue'] as num).toDouble(),
            ))
        .toList();

    return AnalyticsState(
      period: period,
      revenue: summary['revenue'] ?? 0,
      cogs: summary['cogs'] ?? 0,
      grossProfit: summary['gross_profit'] ?? 0,
      txnCount: (summary['txn_count'] ?? 0).toInt(),
      topProducts: top,
      chartData: chart,
      recentTransactions: recent,
    );
  }

  Future<void> setPeriod(AnalyticsPeriod period) async {
    state = AsyncData<AnalyticsState>(
        state.value!.copyWith(isLoading: true, period: period));
    state = AsyncData<AnalyticsState>(await _load(period));
  }

  Future<void> refresh() async {
    final AnalyticsPeriod p =
        state.value?.period ?? AnalyticsPeriod.weekly;
    state = AsyncData<AnalyticsState>(
        state.value!.copyWith(isLoading: true));
    state = AsyncData<AnalyticsState>(await _load(p));
  }
}

final AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>
    analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(
        AnalyticsNotifier.new);
