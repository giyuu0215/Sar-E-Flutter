import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' as sql;

import '../application/locale_provider.dart';
import '../data/local/daos/transaction_dao.dart';
import '../data/local/database.dart';
import '../domain/entities/transaction.dart';
import '../theme/app_theme.dart';

final AutoDisposeFutureProvider<List<Transaction>> allTransactionsProvider =
    FutureProvider.autoDispose<List<Transaction>>((Ref ref) async {
  final TransactionDao dao = TransactionDao();
  return dao.getRecent(limit: 200);
});

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  /// Format payment method for display
  String _formatPaymentMethod(String method, AppLocale locale) {
    if (method.startsWith('ewallet:')) {
      return method.substring(8);
    }
    switch (method) {
      case 'cash':
        return t(locale, 'cash');
      case 'ewallet':
        return t(locale, 'ewallet_qr');
      default:
        return method;
    }
  }

  Future<PaymentRecord?> _getPayment(String transactionId) async {
    // Get payment record from DB
    final sql.Database db = await AppDatabase.instance;
    final List<Map<String, dynamic>> rows = await db.query(
      'payment_records',
      where: 'transaction_id = ?',
      whereArgs: <String>[transactionId],
    );
    if (rows.isEmpty) return null;
    return PaymentRecord.fromMap(rows.first);
  }

  Future<void> _showTransactionDetail(
      BuildContext context, Transaction txn, AppLocale locale, AppColors c) async {
    final TransactionDao dao = TransactionDao();
    final List<TransactionLineItem> lineItems =
        await dao.getLineItems(txn.transactionId);
    final PaymentRecord? payment = await _getPayment(txn.transactionId);

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Header
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(children: <Widget>[
                  const Icon(Icons.receipt_long_outlined,
                      color: Colors.white, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    t(locale, 'transaction_detail'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, y – h:mm a').format(txn.timestamp),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ]),
              ),

              // Line items
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (lineItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(t(locale, 'no_line_items'),
                              style: TextStyle(
                                  color: c.textTertiary, fontSize: 13)),
                        )
                      else
                        ...lineItems.map((TransactionLineItem li) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: <Widget>[
                              Expanded(
                                child: Text(
                                  '${li.qty}× ${li.productName ?? li.productId}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                '₱${li.subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ]),
                          );
                        }),
                      Divider(color: c.border, height: 20),
                      // Payment method
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(t(locale, 'payment'),
                              style: const TextStyle(fontSize: 12)),
                          Text(
                            _formatPaymentMethod(
                                payment?.method ?? txn.paymentMethod, locale),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(t(locale, 'total').toUpperCase(),
                              style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)),
                          Text(
                            '₱${txn.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: c.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 18),
                          ),
                        ],
                      ),
                      if (txn.changeDue > 0) ...<Widget>[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(t(locale, 'change'),
                                style:
                                    TextStyle(color: c.info, fontSize: 12)),
                            Text(
                              '₱${txn.changeDue.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: c.info,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Status
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: txn.status == 'completed'
                                ? c.info.withValues(alpha: 0.12)
                                : c.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            txn.status.toUpperCase(),
                            style: TextStyle(
                              color: txn.status == 'completed'
                                  ? c.info
                                  : c.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Close
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                    ),
                    child: Text(t(locale, 'close')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = appColors(context);
    final AppLocale locale = ref.watch(localeProvider);
    final AsyncValue<List<Transaction>> txnsAsync =
        ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t(locale, 'transactions')),
      ),
      body: txnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('${t(locale, 'error')}: $e')),
        data: (List<Transaction> txns) {
          if (txns.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(allTransactionsProvider),
              child: ListView(
                children: <Widget>[
                  const SizedBox(height: 80),
                  Icon(Icons.receipt_long_outlined,
                      size: 56, color: c.textTertiary),
                  const SizedBox(height: 12),
                  Text(t(locale, 'no_data'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary)),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(t(locale, 'refresh'),
                        style: TextStyle(color: c.textTertiary, fontSize: 12)),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
              onRefresh: () async => ref.invalidate(allTransactionsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: txns.length,
                itemBuilder: (BuildContext context, int i) {
                  final Transaction tObj = txns[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _showTransactionDetail(context, tObj, locale, c),
                      leading: CircleAvatar(
                        backgroundColor: tObj.status == 'completed'
                            ? c.info.withValues(alpha: 0.15)
                            : c.warning.withValues(alpha: 0.15),
                        child: Icon(
                          tObj.paymentMethod == 'cash'
                              ? Icons.payments_outlined
                              : Icons.qr_code_outlined,
                          color: tObj.status == 'completed' ? c.info : c.warning,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'PHP ${tObj.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(DateFormat('MMM d, y – h:mm a')
                              .format(tObj.timestamp)),
                          Text(_formatPaymentMethod(tObj.paymentMethod, locale).toUpperCase(),
                              style: TextStyle(
                                  color: c.textTertiary, fontSize: 11)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tObj.status == 'completed'
                              ? c.info.withValues(alpha: 0.12)
                              : c.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tObj.status.toUpperCase(),
                          style: TextStyle(
                            color: tObj.status == 'completed' ? c.info : c.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ));
        },
      ),
    );
  }
}
