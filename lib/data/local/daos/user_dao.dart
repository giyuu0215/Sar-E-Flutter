import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/user_credential.dart';
import '../database.dart';

class UserDao {
  Future<Database> get _db => AppDatabase.instance;

  Future<UserCredential?> getOwner() async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      'user_credentials',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserCredential.fromMap(rows.first);
  }

  Future<List<UserCredential>> getAllUsers() async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query('user_credentials');
    return rows.map(UserCredential.fromMap).toList();
  }

  Future<UserCredential?> getUserByPinHash(String pinHash) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      'user_credentials',
      where: 'pin_hash = ?',
      whereArgs: <String>[pinHash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserCredential.fromMap(rows.first);
  }

  Future<void> insert(UserCredential user) async {
    final Database db = await _db;
    await db.insert('user_credentials', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(UserCredential user) async {
    final Database db = await _db;
    await db.update(
      'user_credentials',
      user.toMap(),
      where: 'user_id = ?',
      whereArgs: <String>[user.userId],
    );
  }

  Future<bool> exists() async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows =
        await db.rawQuery('SELECT COUNT(*) as c FROM user_credentials');
    return ((rows.first['c'] as int?) ?? 0) > 0;
  }
}
