import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/credit_entry.dart';
import '../database.dart';

class CreditDao {
  Future<Database> get _db => AppDatabase.instance;

  Future<List<CreditEntry>> getAll({String? status}) async {
    final Database db = await _db;
    final StringBuffer where = StringBuffer('1=1');
    final List<dynamic> args = <dynamic>[];
    if (status != null) {
      where.write(' AND ce.status = ?');
      args.add(status);
    }
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT ce.*,
             c.name AS customer_name,
             c.mobile_number AS customer_phone
      FROM credit_entries ce
      JOIN customers c ON ce.customer_id = c.customer_id
      WHERE $where
      ORDER BY ce.created_at DESC
    ''', args);
    return rows.map(CreditEntry.fromMap).toList();
  }

  Future<List<CreditEntry>> getOverdue() async {
    final Database db = await _db;
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT ce.*,
             c.name AS customer_name,
             c.mobile_number AS customer_phone
      FROM credit_entries ce
      JOIN customers c ON ce.customer_id = c.customer_id
      WHERE ce.status NOT IN ('settled','archived')
        AND date(ce.due_date) < date(?)
      ORDER BY ce.due_date ASC
    ''', <String>[today]);
    return rows.map(CreditEntry.fromMap).toList();
  }

  Future<CreditEntry?> getById(String entryId) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT ce.*,
             c.name AS customer_name,
             c.mobile_number AS customer_phone
      FROM credit_entries ce
      JOIN customers c ON ce.customer_id = c.customer_id
      WHERE ce.entry_id = ?
    ''', <String>[entryId]);
    if (rows.isEmpty) return null;
    return CreditEntry.fromMap(rows.first);
  }

  Future<void> insert(CreditEntry entry) async {
    final Database db = await _db;
    await db.insert('credit_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(CreditEntry entry) async {
    final Database db = await _db;
    await db.update(
      'credit_entries',
      entry.toMap(),
      where: 'entry_id = ?',
      whereArgs: <String>[entry.entryId],
    );
  }

  Future<void> insertRepayment(RepaymentRecord record) async {
    final Database db = await _db;
    await db.insert('repayment_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RepaymentRecord>> getRepayments(String entryId) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      'repayment_records',
      where: 'entry_id = ?',
      whereArgs: <String>[entryId],
      orderBy: 'timestamp DESC',
    );
    return rows.map(RepaymentRecord.fromMap).toList();
  }

  Future<double> getTotalOutstanding() async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount - amount_paid),0) AS total FROM credit_entries WHERE status NOT IN ('settled','archived')",
    );
    return (rows.first['total'] as num? ?? 0).toDouble();
  }
}
