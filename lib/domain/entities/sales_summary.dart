/// Domain entity – sales_summaries table (for analytics).
class SalesSummary {
  const SalesSummary({
    required this.summaryId,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.totalRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.txnCount,
  });

  final String summaryId;
  final String period; // 'daily' | 'weekly' | 'monthly'
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalRevenue;
  final double cogs;
  final double grossProfit;
  final int txnCount;

  double get profitMargin =>
      totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'summary_id': summaryId,
        'period': period,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        'total_revenue': totalRevenue,
        'cogs': cogs,
        'gross_profit': grossProfit,
        'txn_count': txnCount,
      };

  factory SalesSummary.fromMap(Map<String, dynamic> m) => SalesSummary(
        summaryId: m['summary_id'] as String,
        period: m['period'] as String,
        periodStart: DateTime.parse(m['period_start'] as String),
        periodEnd: DateTime.parse(m['period_end'] as String),
        totalRevenue: (m['total_revenue'] as num? ?? 0).toDouble(),
        cogs: (m['cogs'] as num? ?? 0).toDouble(),
        grossProfit: (m['gross_profit'] as num? ?? 0).toDouble(),
        txnCount: (m['txn_count'] as int? ?? 0),
      );
}

/// Top-selling product result (computed, not a stored entity).
class TopProduct {
  const TopProduct({
    required this.productId,
    required this.name,
    required this.totalQty,
    required this.totalRevenue,
  });

  final String productId;
  final String name;
  final int totalQty;
  final double totalRevenue;
}
