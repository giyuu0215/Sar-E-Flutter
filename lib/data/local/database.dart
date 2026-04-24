import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Central sqflite database initialiser.
/// All 16 tables from the ER diagram are created here.
class AppDatabase {
  AppDatabase._();

  static const String _dbName = 'sare.db';
  static const int _version = 3;

  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return openDatabase(
        _dbName,
        version: _version,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else {
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      final String dbPath = p.join(await getDatabasesPath(), _dbName);
      return openDatabase(
        dbPath,
        version: _version,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_credentials (
        user_id         TEXT PRIMARY KEY,
        pin_hash        TEXT NOT NULL,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        role            TEXT NOT NULL DEFAULT 'owner',
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until    TEXT,
        last_login_at   TEXT,
        store_name      TEXT NOT NULL DEFAULT 'My Store'
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        category_id TEXT PRIMARY KEY,
        name        TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        product_id  TEXT PRIMARY KEY,
        category_id TEXT REFERENCES categories(category_id),
        barcode     TEXT UNIQUE,
        name        TEXT NOT NULL,
        unit_price  REAL NOT NULL,
        cost_price  REAL NOT NULL DEFAULT 0,
        stock_qty   INTEGER NOT NULL DEFAULT 0,
        threshold   INTEGER NOT NULL DEFAULT 0,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_products_name ON products(name, category_id)');

    await db.execute('''
      CREATE TABLE customers (
        customer_id    TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        mobile_number  TEXT UNIQUE,
        credit_balance REAL NOT NULL DEFAULT 0,
        is_active      INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_customers_mobile ON customers(mobile_number)');

    await db.execute('''
      CREATE TABLE credit_entries (
        entry_id        TEXT PRIMARY KEY,
        customer_id     TEXT NOT NULL REFERENCES customers(customer_id),
        items           TEXT NOT NULL,
        amount          REAL NOT NULL,
        amount_paid     REAL NOT NULL DEFAULT 0,
        due_date        TEXT NOT NULL,
        status          TEXT NOT NULL DEFAULT 'active',
        reminder_count  INTEGER NOT NULL DEFAULT 0,
        last_reminder_at TEXT,
        created_at      TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_credit_customer_status ON credit_entries(customer_id, status)');

    await db.execute('''
      CREATE TABLE repayment_records (
        repayment_id TEXT PRIMARY KEY,
        entry_id     TEXT NOT NULL REFERENCES credit_entries(entry_id),
        amount_paid  REAL NOT NULL,
        timestamp    TEXT NOT NULL,
        notes        TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        transaction_id TEXT PRIMARY KEY,
        receipt_id     TEXT,
        timestamp      TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        total_amount   REAL NOT NULL,
        change_due     REAL NOT NULL DEFAULT 0,
        status         TEXT NOT NULL DEFAULT 'pending',
        created_at     TEXT NOT NULL,
        synced_at      TEXT
      )
    ''');
    await db
        .execute('CREATE INDEX idx_txn_timestamp ON transactions(timestamp)');
    await db.execute('CREATE INDEX idx_txn_status ON transactions(status)');

    await db.execute('''
      CREATE TABLE transaction_line_items (
        line_item_id   TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL REFERENCES transactions(transaction_id),
        product_id     TEXT NOT NULL REFERENCES products(product_id),
        qty            INTEGER NOT NULL,
        unit_price     REAL NOT NULL,
        subtotal       REAL NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_line_items_txn ON transaction_line_items(transaction_id)');

    await db.execute('''
      CREATE TABLE payment_records (
        payment_id     TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL UNIQUE REFERENCES transactions(transaction_id),
        method         TEXT NOT NULL,
        amount         REAL NOT NULL,
        gateway_ref    TEXT,
        confirmed_at   TEXT,
        status         TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE receipts (
        receipt_id      TEXT PRIMARY KEY,
        transaction_id  TEXT NOT NULL UNIQUE REFERENCES transactions(transaction_id),
        store_name      TEXT NOT NULL,
        timestamp       TEXT NOT NULL,
        qr_payload      TEXT NOT NULL,
        customer_mobile TEXT,
        delivery_status TEXT NOT NULL DEFAULT 'pending',
        sms_delivered_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_summaries (
        summary_id    TEXT PRIMARY KEY,
        period        TEXT NOT NULL,
        period_start  TEXT NOT NULL,
        period_end    TEXT NOT NULL,
        total_revenue REAL NOT NULL DEFAULT 0,
        cogs          REAL NOT NULL DEFAULT 0,
        gross_profit  REAL NOT NULL DEFAULT 0,
        txn_count     INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_sales_period ON sales_summaries(period, period_start)');

    await db.execute('''
      CREATE TABLE price_suggestions (
        suggestion_id    TEXT PRIMARY KEY,
        product_id       TEXT NOT NULL REFERENCES products(product_id),
        suggested_price  REAL NOT NULL,
        benchmark_source TEXT NOT NULL DEFAULT 'cost_markup',
        fetched_at       TEXT NOT NULL,
        accepted         INTEGER NOT NULL DEFAULT 0,
        accepted_at      TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        log_id      TEXT PRIMARY KEY,
        user_id     TEXT REFERENCES user_credentials(user_id),
        action      TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id   TEXT NOT NULL,
        timestamp   TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_audit_user ON audit_logs(user_id, timestamp)');

    await db.execute('''
      CREATE TABLE sync_queue (
        queue_id    TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id   TEXT NOT NULL,
        operation   TEXT NOT NULL,
        payload     TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status      TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_sync_status ON sync_queue(status, created_at)');

    await db.execute('''
      CREATE TABLE outbound_messages (
        message_id  TEXT PRIMARY KEY,
        type        TEXT NOT NULL DEFAULT 'sms',
        recipient   TEXT NOT NULL,
        content     TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        sent_at     TEXT,
        status      TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_outbound_status ON outbound_messages(status, created_at)');

    await _seedDefaultCategories(db);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT UNIQUE');
    }
    if (oldVersion < 3) {
      // Create sync_queue for installs that upgraded from v1 before this table existed
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          queue_id    TEXT PRIMARY KEY,
          entity_type TEXT NOT NULL,
          entity_id   TEXT NOT NULL,
          operation   TEXT NOT NULL,
          payload     TEXT NOT NULL,
          created_at  TEXT NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0,
          status      TEXT NOT NULL DEFAULT 'pending'
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_status ON sync_queue(status, created_at)');
      // Add default column if missing
      try {
        await db.execute(
            "ALTER TABLE price_suggestions ADD COLUMN benchmark_source TEXT NOT NULL DEFAULT 'cost_markup'");
      } catch (_) {} // Already exists on fresh installs
      await _seedDefaultCategories(db);
    }
  }

  static Future<void> _seedDefaultCategories(Database db) async {
    final List<String> names = <String>[
      'Beverages', 'Snacks', 'Canned Goods', 'Instant Noodles',
      'Condiments', 'Dairy & Eggs', 'Frozen Foods', 'Personal Care',
      'Household', 'Tobacco', 'Alcohol', 'Other',
    ];
    final String now = DateTime.now().toIso8601String();
    for (final String name in names) {
      try {
        await db.execute(
          "INSERT OR IGNORE INTO categories (category_id, name, created_at) VALUES (lower(hex(randomblob(16))), ?, ?)",
          <Object>[name, now],
        );
      } catch (_) {}
    }
  }

  /// Close the database (useful in tests).
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
