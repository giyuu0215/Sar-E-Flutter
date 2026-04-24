import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/category.dart';
import '../../../domain/entities/product.dart';
import '../database.dart';

class ProductDao {
  Future<Database> get _db => AppDatabase.instance;

  // ── Categories ──────────────────────────────────────────────────────────────

  Future<List<Category>> getAllCategories() async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      'categories',
      orderBy: 'name ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<void> insertCategory(Category cat) async {
    final Database db = await _db;
    await db.insert('categories', cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCategory(Category cat) async {
    final Database db = await _db;
    await db.update(
      'categories',
      cat.toMap(),
      where: 'category_id = ?',
      whereArgs: <String>[cat.categoryId],
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final Database db = await _db;
    await db.delete(
      'categories',
      where: 'category_id = ?',
      whereArgs: <String>[categoryId],
    );
  }

  // ── Products ─────────────────────────────────────────────────────────────────

  /// Returns all active products with category name joined.
  Future<List<Product>> getAllProducts({bool includeInactive = false}) async {
    final Database db = await _db;
    final String where = includeInactive ? '' : 'WHERE p.is_active = 1';
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT
        p.*,
        c.name AS category_name,
        (
          SELECT ps.suggested_price
          FROM price_suggestions ps
          WHERE ps.product_id = p.product_id
          ORDER BY ps.fetched_at DESC
          LIMIT 1
        ) AS suggested_price
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.category_id
      $where
      ORDER BY p.name ASC
    ''');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getById(String productId) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.category_id
      WHERE p.product_id = ?
    ''', <String>[productId]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<List<Product>> search(String query) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.category_id
      WHERE p.is_active = 1 AND (LOWER(p.name) LIKE ? OR p.barcode = ?)
      ORDER BY p.name ASC
      LIMIT 30
    ''', <String>['%${query.toLowerCase()}%', query]);
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> getLowStock() async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.category_id
      WHERE p.is_active = 1 AND p.stock_qty <= p.threshold
      ORDER BY p.stock_qty ASC
    ''');
    return rows.map(Product.fromMap).toList();
  }

  Future<void> insert(Product product) async {
    final Database db = await _db;
    await db.insert('products', product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Product product) async {
    final Database db = await _db;
    await db.update(
      'products',
      product.toMap(),
      where: 'product_id = ?',
      whereArgs: <String>[product.productId],
    );
  }

  Future<void> updateStock(String productId, int newQty) async {
    final Database db = await _db;
    await db.rawUpdate(
      '''UPDATE products SET stock_qty = ?, updated_at = ?
         WHERE product_id = ?''',
      <dynamic>[newQty, DateTime.now().toIso8601String(), productId],
    );
  }

  Future<void> deactivate(String productId) async {
    final Database db = await _db;
    await db.rawUpdate(
      '''UPDATE products SET is_active = 0, updated_at = ?
         WHERE product_id = ?''',
      <dynamic>[DateTime.now().toIso8601String(), productId],
    );
  }

  // ── Price Suggestions ────────────────────────────────────────────────────────

  Future<void> insertPriceSuggestion(Map<String, dynamic> row) async {
    final Database db = await _db;
    await db.insert('price_suggestions', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> acceptPriceSuggestion(
      String productId, double newPrice) async {
    final Database db = await _db;
    // Update the product price
    await db.rawUpdate(
      'UPDATE products SET unit_price = ?, updated_at = ? WHERE product_id = ?',
      <dynamic>[newPrice, DateTime.now().toIso8601String(), productId],
    );
    // Mark suggestion accepted
    await db.rawUpdate(
      '''UPDATE price_suggestions SET accepted = 1, accepted_at = ?
         WHERE product_id = ? AND accepted = 0''',
      <dynamic>[DateTime.now().toIso8601String(), productId],
    );
  }
}
