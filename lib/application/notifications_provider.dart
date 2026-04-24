import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../data/local/database.dart';
import '../domain/entities/customer.dart';
import '../domain/entities/product.dart';

class NotificationState {
  const NotificationState({
    this.lowStockProducts = const [],
    this.overdueCredits = const [],
    this.isLoading = false,
  });

  final List<Product> lowStockProducts;
  final List<Customer> overdueCredits;
  final bool isLoading;

  int get totalAlerts => lowStockProducts.length + overdueCredits.length;

  NotificationState copyWith({
    List<Product>? lowStockProducts,
    List<Customer>? overdueCredits,
    bool? isLoading,
  }) {
    return NotificationState(
      lowStockProducts: lowStockProducts ?? this.lowStockProducts,
      overdueCredits: overdueCredits ?? this.overdueCredits,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationsNotifier extends AsyncNotifier<NotificationState> {
  @override
  Future<NotificationState> build() async {
    await fetchAlerts();
    return state.value ?? const NotificationState();
  }

  Future<void> fetchAlerts() async {
    state =
        const AsyncData<NotificationState>(NotificationState(isLoading: true));
    try {
      final Database db = await AppDatabase.instance;

      // 1. Fetch low stock products (stock <= threshold)
      final List<Map<String, dynamic>> productsRaw = await db.rawQuery(
        'SELECT * FROM products WHERE stock_quantity <= stock_threshold',
      );
      final List<Product> lowStockProducts =
          productsRaw.map((m) => Product.fromMap(m)).toList();

      // 2. Fetch overdue credits (due_date < NOW and status != 'settled')
      final String now = DateTime.now().toIso8601String();
      final List<Map<String, dynamic>> customersRaw = await db.rawQuery(
        "SELECT * FROM customers WHERE id IN (SELECT DISTINCT customer_id FROM credit_ledger WHERE due_date < ? AND status = 'active')",
        <String>[now],
      );
      final List<Customer> overdueCredits =
          customersRaw.map((m) => Customer.fromMap(m)).toList();

      state = AsyncData<NotificationState>(NotificationState(
        lowStockProducts: lowStockProducts,
        overdueCredits: overdueCredits,
        isLoading: false,
      ));
    } catch (e) {
      // Return empty state on error but don't crash
      state = const AsyncData<NotificationState>(
          NotificationState(isLoading: false));
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationState>(
        NotificationsNotifier.new);
