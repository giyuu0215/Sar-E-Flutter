import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
        final bool online = results
            .any((ConnectivityResult r) => r != ConnectivityResult.none);
        state = AsyncData<SyncState>(
            state.value!.copyWith(isOnline: online));
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

  /// Manually trigger a sync.
  Future<void> sync() async {
    if (state.value?.isSyncing == true) return;
    state = AsyncData<SyncState>(
        state.value!.copyWith(isSyncing: true, clearError: true));
    await _drain();
  }

  Future<void> _drain() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? storeId = prefs.getString('storeId');
      if (storeId == null) return; // Cannot sync without tenant isolation

      final Database db = await AppDatabase.instance;
      final List<Map<String, dynamic>> pending = await db.rawQuery(
        "SELECT * FROM sync_queue WHERE status = 'pending' AND retry_count < $_maxRetries ORDER BY created_at ASC LIMIT 50",
      );

      if (pending.isEmpty) {
        state = AsyncData<SyncState>(state.value!
            .copyWith(isSyncing: false, pendingCount: 0));
        return;
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference<Map<String, dynamic>> storeRef = firestore.collection('stores').doc(storeId);

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
        } catch (_) {
          await db.rawUpdate(
            'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE queue_id = ?',
            <String>[queueId],
          );
        }
      }

      final int remaining = await _pendingCount();
      state = AsyncData<SyncState>(state.value!.copyWith(
        isSyncing: false,
        pendingCount: remaining,
        lastSyncedAt: DateTime.now(),
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
