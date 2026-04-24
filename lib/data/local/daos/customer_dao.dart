import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/customer.dart';
import '../database.dart';

class CustomerDao {
  Future<Database> get _db => AppDatabase.instance;

  Future<List<Customer>> getAll() async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      'customers',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getById(String customerId) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      'customers',
      where: 'customer_id = ?',
      whereArgs: <String>[customerId],
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<List<Customer>> search(String query) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      '''SELECT * FROM customers
         WHERE is_active = 1
           AND (LOWER(name) LIKE ? OR mobile_number LIKE ?)
         ORDER BY name ASC LIMIT 30''',
      <String>['%${query.toLowerCase()}%', '%$query%'],
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<void> insert(Customer customer) async {
    final Database db = await _db;
    await db.insert('customers', customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Customer customer) async {
    final Database db = await _db;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'customer_id = ?',
      whereArgs: <String>[customer.customerId],
    );
  }

  Future<void> updateCreditBalance(String customerId, double newBalance) async {
    final Database db = await _db;
    await db.rawUpdate(
      'UPDATE customers SET credit_balance = ? WHERE customer_id = ?',
      <dynamic>[newBalance, customerId],
    );
  }
}
