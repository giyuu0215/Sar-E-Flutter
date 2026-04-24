import 'package:sqflite/sqflite.dart' hide Transaction;

import '../../../domain/entities/transaction.dart';
import '../database.dart';

class TransactionDao {
  Future<Database> get _db => AppDatabase.instance;

  // ── Write (all in one DB transaction) ──────────────────────────────────────

  Future<void> insertCheckout({
    required Transaction txn,
    required List<TransactionLineItem> items,
    required PaymentRecord payment,
    Receipt? receipt,
  }) async {
    final Database db = await _db;
    await db.transaction((DatabaseExecutor tx) async {
      await tx.insert('transactions', txn.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final TransactionLineItem item in items) {
        await tx.insert('transaction_line_items', item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await tx.insert('payment_records', payment.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      if (receipt != null) {
        await tx.insert('receipts', receipt.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await tx.rawUpdate(
          'UPDATE transactions SET receipt_id = ? WHERE transaction_id = ?',
          <String>[receipt.receiptId, txn.transactionId],
        );
      }
    });
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  Future<List<Transaction>> getRecent({int limit = 50}) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      'transactions',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map((Map<String, dynamic> r) => Transaction.fromMap(r)).toList();
  }

  Future<Transaction?> getById(String transactionId) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      'transactions',
      where: 'transaction_id = ?',
      whereArgs: <String>[transactionId],
    );
    if (rows.isEmpty) return null;
    return Transaction.fromMap(rows.first);
  }

  Future<List<TransactionLineItem>> getLineItems(
      String transactionId) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT li.*, p.name AS product_name
      FROM transaction_line_items li
      JOIN products p ON li.product_id = p.product_id
      WHERE li.transaction_id = ?
    ''', <String>[transactionId]);
    return rows.map(TransactionLineItem.fromMap).toList();
  }

  Future<Receipt?> getReceipt(String transactionId) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      'receipts',
      where: 'transaction_id = ?',
      whereArgs: <String>[transactionId],
    );
    if (rows.isEmpty) return null;
    return Receipt.fromMap(rows.first);
  }

  // ── Analytics helpers ────────────────────────────────────────────────────────

  Future<Map<String, double>> getSummaryForRange(
      DateTime start, DateTime end) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(t.total_amount), 0) AS revenue,
        COALESCE(SUM(
          (SELECT COALESCE(SUM(li.qty * p.cost_price), 0)
           FROM transaction_line_items li
           JOIN products p ON li.product_id = p.product_id
           WHERE li.transaction_id = t.transaction_id)
        ), 0) AS cogs,
        COUNT(*) AS txn_count
      FROM transactions t
      WHERE t.status = 'completed'
        AND t.timestamp >= ? AND t.timestamp <= ?
    ''', <String>[start.toIso8601String(), end.toIso8601String()]);

    final Map<String, dynamic> r = rows.first;
    final double revenue = (r['revenue'] as num? ?? 0).toDouble();
    final double cogs = (r['cogs'] as num? ?? 0).toDouble();
    return <String, double>{
      'revenue': revenue,
      'cogs': cogs,
      'gross_profit': revenue - cogs,
      'txn_count': (r['txn_count'] as num? ?? 0).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> getTopProducts(
      DateTime start, DateTime end, {int limit = 10}) async {
    final Database db = await _db;
    return db.rawQuery('''
      SELECT
        p.product_id,
        p.name,
        SUM(li.qty) AS total_qty,
        SUM(li.subtotal) AS total_revenue
      FROM transaction_line_items li
      JOIN products p ON li.product_id = p.product_id
      JOIN transactions t ON li.transaction_id = t.transaction_id
      WHERE t.status = 'completed'
        AND t.timestamp >= ? AND t.timestamp <= ?
      GROUP BY p.product_id
      ORDER BY total_qty DESC
      LIMIT ?
    ''', <dynamic>[start.toIso8601String(), end.toIso8601String(), limit]);
  }

  /// Returns daily revenue/cogs for the last N days (for chart).
  Future<List<Map<String, dynamic>>> getDailyChart(int days) async {
    final Database db = await _db;
    // Compute start in local time — SQLite datetime('now') is UTC which
    // causes a timezone mismatch when transactions are stored as local ISO8601.
    final String startIso = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
    return db.rawQuery('''
      SELECT
        date(t.timestamp) AS day,
        COALESCE(SUM(t.total_amount), 0) AS revenue,
        COALESCE(SUM(
          (SELECT COALESCE(SUM(li.qty * p.cost_price), 0)
           FROM transaction_line_items li
           JOIN products p ON li.product_id = p.product_id
           WHERE li.transaction_id = t.transaction_id)
        ), 0) AS cogs
      FROM transactions t
      WHERE t.status = 'completed'
        AND t.timestamp >= ?
      GROUP BY date(t.timestamp)
      ORDER BY day ASC
    ''', <String>[startIso]);
  }
}
