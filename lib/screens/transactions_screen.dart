import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/local/daos/transaction_dao.dart';
import '../domain/entities/transaction.dart';
import '../theme/app_theme.dart';

final AutoDisposeFutureProvider<List<Transaction>> allTransactionsProvider =
    FutureProvider.autoDispose<List<Transaction>>(
        (Ref ref) async {
  final TransactionDao dao = TransactionDao();
  return dao.getRecent(limit: 200);
});

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = appColors(context);
    final AsyncValue<List<Transaction>> txnsAsync =
        ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: txnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Error: $e')),
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
                Text('No transactions yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary)),
                const SizedBox(height: 12),
                Center(
                  child: Text('Pull to refresh',
                      style:
                          TextStyle(color: c.textTertiary, fontSize: 12)),
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
              final Transaction t = txns[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.status == 'completed'
                        ? c.info.withValues(alpha: 0.15)
                        : c.warning.withValues(alpha: 0.15),
                    child: Icon(
                      t.paymentMethod == 'cash'
                          ? Icons.payments_outlined
                          : Icons.qr_code_outlined,
                      color: t.status == 'completed' ? c.info : c.warning,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'PHP ${t.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(DateFormat('MMM d, y – h:mm a')
                          .format(t.timestamp)),
                      Text(t.paymentMethod.toUpperCase(),
                          style: TextStyle(
                              color: c.textTertiary, fontSize: 11)),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.status == 'completed'
                          ? c.info.withValues(alpha: 0.12)
                          : c.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.status.toUpperCase(),
                      style: TextStyle(
                        color: t.status == 'completed' ? c.info : c.warning,
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
