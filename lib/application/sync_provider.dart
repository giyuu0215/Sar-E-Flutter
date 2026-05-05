import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/local/database.dart';

const Uuid _uuid = Uuid();
const int _maxRetries = 5;

class SyncState {
  const SyncState({
    this.isOnline = false,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.isSyncing = false,
    this.lastError,
  });

  final bool isOnline;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final bool isSyncing;
  final String? lastError;

  SyncState copyWith({
    bool? isOnline,
    int? pendingCount,
    DateTime? lastSyncedAt,
    bool? isSyncing,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncState(
        isOnline: isOnline ?? this.isOnline,
        pendingCount: pendingCount ?? this.pendingCount,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        isSyncing: isSyncing ?? this.isSyncing,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

class SyncNotifier extends AsyncNotifier<SyncState> {
  @override
  Future<SyncState> build() async {
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        final bool online =
            results.any((ConnectivityResult r) => r != ConnectivityResult.none);
        state = AsyncData<SyncState>(state.value!.copyWith(isOnline: online));
        if (online) {
          await _drain();
        }
      },
    );

    final List<ConnectivityResult> initial =
        await Connectivity().checkConnectivity();
    final bool online =
        initial.any((ConnectivityResult r) => r != ConnectivityResult.none);
    final int pending = await _pendingCount();
    return SyncState(isOnline: online, pendingCount: pending);
  }

  Future<int> _pendingCount() async {
    final Database db = await AppDatabase.instance;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM sync_queue WHERE status = 'pending'",
    );
    return (rows.first['c'] as int? ?? 0);
  }

  /// Enqueue a change to be synced later.
  static Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation, // 'create' | 'update' | 'delete'
    required Map<String, dynamic> payload,
  }) async {
    final Database db = await AppDatabase.instance;
    await db.insert('sync_queue', <String, dynamic>{
      'queue_id': _uuid.v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'status': 'pending',
    });
  }

  /// Manually trigger a sync of pending queue items.
  Future<void> sync() async {
    if (state.value?.isSyncing == true) return;
    state = AsyncData<SyncState>(
        state.value!.copyWith(isSyncing: true, clearError: true));
    await _drain();
  }

  // ── Restore from Cloud ──────────────────────────────────────────────────────

  /// Downloads ALL data from Firestore into local SQLite.
  /// Called when user logs in on a device that has no local data.
  Future<bool> restoreFromCloud() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storeId = prefs.getString('storeId');
    if (storeId == null) return false;

    final bool isOffline = prefs.getBool('isOfflineMode') ?? false;
    if (isOffline) return false;

    state = AsyncData<SyncState>(
        state.value!.copyWith(isSyncing: true, clearError: true));

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference<Map<String, dynamic>> storeRef =
          firestore.collection('stores').doc(storeId);
      final Database db = await AppDatabase.instance;

      int totalRestored = 0;

      // ── 1. Restore categories ──
      totalRestored += await _restoreCollection(
        storeRef: storeRef,
        collectionName: 'categories',
        db: db,
        tableName: 'categories',
        primaryKey: 'category_id',
      );

      // ── 2. Restore products ──
      totalRestored += await _restoreCollection(
        storeRef: storeRef,
        collectionName: 'products',
        db: db,
        tableName: 'products',
        primaryKey: 'product_id',
      );

      // ── 3. Restore customers ──
      totalRestored += await _restoreCollection(
        storeRef: storeRef,
        collectionName: 'customers',
        db: db,
        tableName: 'customers',
        primaryKey: 'customer_id',
      );

      // ── 4. Restore credit entries ──
      totalRestored += await _restoreCollection(
        storeRef: storeRef,
        collectionName: 'credit_entries',
        db: db,
        tableName: 'credit_entries',
        primaryKey: 'entry_id',
      );

      // ── 5. Restore repayments ──
      totalRestored += await _restoreCollection(
        storeRef: storeRef,
        collectionName: 'repayments',
        db: db,
        tableName: 'repayment_records',
        primaryKey: 'repayment_id',
      );

      // ── 6. Restore transactions ──
      totalRestored += await _restoreCollection(
        storeRef: storeRef,
        collectionName: 'transactions',
        db: db,
        tableName: 'transactions',
        primaryKey: 'transaction_id',
      );

      // ── 7. Restore transaction line items ──
      totalRestored += await _restoreCollection(
        storeRef: storeRef,
        collectionName: 'transaction_line_items',
        db: db,
        tableName: 'transaction_line_items',
        primaryKey: 'line_item_id',
      );

      // ── 8. Restore payment records ──
      totalRestored += await _restoreCollection(
        storeRef: storeRef,
        collectionName: 'payment_records',
        db: db,
        tableName: 'payment_records',
        primaryKey: 'payment_id',
      );

      // ── 9. Restore receipts ──
      totalRestored += await _restoreCollection(
        storeRef: storeRef,
        collectionName: 'receipts',
        db: db,
        tableName: 'receipts',
        primaryKey: 'receipt_id',
      );

      debugPrint('[SyncNotifier] Restored $totalRestored records from cloud');

      await prefs.setString(
          'lastCloudRestore', DateTime.now().toIso8601String());

      state = AsyncData<SyncState>(state.value!.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
        pendingCount: 0,
      ));
      return totalRestored > 0;
    } catch (e) {
      debugPrint('[SyncNotifier] Cloud restore failed: $e');
      state = AsyncData<SyncState>(state.value!.copyWith(
        isSyncing: false,
        lastError: 'Cloud restore failed: $e',
      ));
      return false;
    }
  }

  /// Helper: downloads all docs from a Firestore subcollection and inserts
  /// them into the corresponding local SQLite table.
  Future<int> _restoreCollection({
    required DocumentReference<Map<String, dynamic>> storeRef,
    required String collectionName,
    required Database db,
    required String tableName,
    required String primaryKey,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await storeRef.collection(collectionName).get();
      if (snapshot.docs.isEmpty) return 0;

      int count = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());

        // Remove server-only fields that don't exist in local schema
        data.remove('server_updated_at');

        // Convert Timestamps to ISO strings and bools to 1/0 for SQLite
        for (final String key in data.keys.toList()) {
          if (data[key] is Timestamp) {
            data[key] = (data[key] as Timestamp).toDate().toIso8601String();
          } else if (data[key] is bool) {
            data[key] = (data[key] as bool) ? 1 : 0;
          }
        }

        try {
          await db.insert(tableName, data,
              conflictAlgorithm: ConflictAlgorithm.replace);
          count++;
        } catch (e) {
          debugPrint(
              '[SyncNotifier] Failed to insert $collectionName/${doc.id}: $e');
        }
      }
      debugPrint(
          '[SyncNotifier] Restored $count $collectionName records');
      return count;
    } catch (e) {
      debugPrint(
          '[SyncNotifier] Failed to restore $collectionName: $e');
      return 0;
    }
  }

  // ── Force Full Sync ─────────────────────────────────────────────────────────

  /// Force full sync: re-enqueues ALL local data to Firestore.
  /// Useful when sync queue was empty but Firestore is missing data.
  Future<void> forceFullSync() async {
    if (state.value?.isSyncing == true) return;
    state = AsyncData<SyncState>(
        state.value!.copyWith(isSyncing: true, clearError: true));
    try {
      final Database db = await AppDatabase.instance;

      // Clear any stale pending items to avoid duplicates
      await db.rawDelete("DELETE FROM sync_queue WHERE status = 'pending'");

      // Re-enqueue all products
      final List<Map<String, dynamic>> products =
          await db.query('products', where: 'is_active = 1');
      for (final Map<String, dynamic> p in products) {
        await enqueue(
          entityType: 'products',
          entityId: p['product_id'] as String,
          operation: 'create',
          payload: p,
        );
      }

      // Re-enqueue all categories
      final List<Map<String, dynamic>> categories =
          await db.query('categories');
      for (final Map<String, dynamic> c in categories) {
        await enqueue(
          entityType: 'categories',
          entityId: c['category_id'] as String,
          operation: 'create',
          payload: c,
        );
      }

      // Re-enqueue all customers
      final List<Map<String, dynamic>> customers =
          await db.query('customers', where: 'is_active = 1');
      for (final Map<String, dynamic> c in customers) {
        await enqueue(
          entityType: 'customers',
          entityId: c['customer_id'] as String,
          operation: 'create',
          payload: c,
        );
      }

      // Re-enqueue all credit entries
      final List<Map<String, dynamic>> entries =
          await db.query('credit_entries');
      for (final Map<String, dynamic> e in entries) {
        await enqueue(
          entityType: 'credit_entries',
          entityId: e['entry_id'] as String,
          operation: 'create',
          payload: e,
        );
      }

      // Re-enqueue all repayments
      final List<Map<String, dynamic>> repayments =
          await db.query('repayment_records');
      for (final Map<String, dynamic> r in repayments) {
        await enqueue(
          entityType: 'repayments',
          entityId: r['repayment_id'] as String,
          operation: 'create',
          payload: r,
        );
      }

      // Re-enqueue all completed transactions
      final List<Map<String, dynamic>> transactions =
          await db.query('transactions', where: "status = 'completed'");
      for (final Map<String, dynamic> t in transactions) {
        await enqueue(
          entityType: 'transactions',
          entityId: t['transaction_id'] as String,
          operation: 'create',
          payload: t,
        );
      }

      // Re-enqueue all transaction line items
      final List<Map<String, dynamic>> lineItems =
          await db.query('transaction_line_items');
      for (final Map<String, dynamic> li in lineItems) {
        await enqueue(
          entityType: 'transaction_line_items',
          entityId: li['line_item_id'] as String,
          operation: 'create',
          payload: li,
        );
      }

      // Re-enqueue all payment records
      final List<Map<String, dynamic>> paymentRecords =
          await db.query('payment_records');
      for (final Map<String, dynamic> pr in paymentRecords) {
        await enqueue(
          entityType: 'payment_records',
          entityId: pr['payment_id'] as String,
          operation: 'create',
          payload: pr,
        );
      }

      // Re-enqueue all receipts
      final List<Map<String, dynamic>> receiptRows =
          await db.query('receipts');
      for (final Map<String, dynamic> rc in receiptRows) {
        await enqueue(
          entityType: 'receipts',
          entityId: rc['receipt_id'] as String,
          operation: 'create',
          payload: rc,
        );
      }

      debugPrint(
          '[SyncNotifier] Force full sync: enqueued ${await _pendingCount()} items');

      // Now drain everything
      await _drain();
    } catch (e) {
      state = AsyncData<SyncState>(state.value!.copyWith(
        isSyncing: false,
        lastError: 'Force sync failed: $e',
      ));
    }
  }

  Future<void> _drain() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? storeId = prefs.getString('storeId');
      if (storeId == null) return; // Cannot sync without tenant isolation

      final bool isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
      if (isOfflineMode) {
        // Offline-only stores should never sync to Firestore
        state = AsyncData<SyncState>(
            state.value!.copyWith(isSyncing: false, pendingCount: 0));
        return;
      }

      final Database db = await AppDatabase.instance;
      final List<Map<String, dynamic>> pending = await db.rawQuery(
        "SELECT * FROM sync_queue WHERE status = 'pending' AND retry_count < $_maxRetries ORDER BY created_at ASC LIMIT 50",
      );

      if (pending.isEmpty) {
        state = AsyncData<SyncState>(
            state.value!.copyWith(isSyncing: false, pendingCount: 0));
        return;
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference<Map<String, dynamic>> storeRef =
          firestore.collection('stores').doc(storeId);

      int successCount = 0;
      for (final Map<String, dynamic> row in pending) {
        final String queueId = row['queue_id'] as String;
        final String entityType = row['entity_type'] as String;
        final String entityId = row['entity_id'] as String;
        final String operation = row['operation'] as String;
        final Map<String, dynamic> payload =
            jsonDecode(row['payload'] as String) as Map<String, dynamic>;

        try {
          final DocumentReference<Map<String, dynamic>> ref =
              storeRef.collection(entityType).doc(entityId);
          if (operation == 'delete') {
            await ref.delete();
          } else {
            // Include server timestamp for potential future pull syncs
            payload['server_updated_at'] = FieldValue.serverTimestamp();
            await ref.set(payload, SetOptions(merge: true));
          }

          await db.rawUpdate(
            "UPDATE sync_queue SET status = 'synced' WHERE queue_id = ?",
            <String>[queueId],
          );
          successCount++;
        } catch (e) {
          debugPrint('[SyncNotifier] Failed to sync $entityType/$entityId: $e');
          await db.rawUpdate(
            'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE queue_id = ?',
            <String>[queueId],
          );
        }
      }

      final int remaining = await _pendingCount();

      // If there are more pending items, continue draining
      if (remaining > 0 && successCount > 0) {
        // Recursive drain for remaining items
        state = AsyncData<SyncState>(state.value!.copyWith(
          pendingCount: remaining,
        ));
        await _drain();
        return;
      }

      state = AsyncData<SyncState>(state.value!.copyWith(
        isSyncing: false,
        pendingCount: remaining,
        lastSyncedAt: successCount > 0 ? DateTime.now() : null,
      ));
    } catch (e) {
      state = AsyncData<SyncState>(state.value!.copyWith(
        isSyncing: false,
        lastError: e.toString(),
      ));
    }
  }
}

final AsyncNotifierProvider<SyncNotifier, SyncState> syncProvider =
    AsyncNotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
