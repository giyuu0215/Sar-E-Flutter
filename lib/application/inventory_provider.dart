import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/local/daos/product_dao.dart';
import '../domain/entities/category.dart';
import '../domain/entities/product.dart';
import 'auth_provider.dart';
import 'sync_provider.dart';

const Uuid _uuid = Uuid();

class InventoryState {
  const InventoryState({
    this.products = const <Product>[],
    this.categories = const <Category>[],
    this.isLoading = false,
    this.searchQuery = '',
    this.selectedCategory,
  });

  final List<Product> products;
  final List<Category> categories;
  final bool isLoading;
  final String searchQuery;
  final String? selectedCategory;

  List<Product> get filtered {
    Iterable<Product> list = products;
    if (selectedCategory != null) {
      list = list.where((Product p) => p.categoryId == selectedCategory);
    }
    if (searchQuery.isNotEmpty) {
      final String q = searchQuery.toLowerCase();
      list = list.where((Product p) => p.name.toLowerCase().contains(q));
    }
    return list.toList();
  }

  int get lowStockCount => products.where((Product p) => p.isLowStock).length;
  double get totalValue => products.fold<double>(
      0, (double s, Product p) => s + p.unitPrice * p.stockQty);

  InventoryState copyWith({
    List<Product>? products,
    List<Category>? categories,
    bool? isLoading,
    String? searchQuery,
    String? selectedCategory,
    bool clearCategory = false,
  }) =>
      InventoryState(
        products: products ?? this.products,
        categories: categories ?? this.categories,
        isLoading: isLoading ?? this.isLoading,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedCategory:
            clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      );
}

class InventoryNotifier extends AsyncNotifier<InventoryState> {
  final ProductDao _dao = ProductDao();

  bool get _isOffline => ref.read(authProvider).value?.isOfflineMode ?? false;

  @override
  Future<InventoryState> build() async => _load();

  Future<InventoryState> _load() async {
    final List<Product> products = await _dao.getAllProducts();
    final List<Category> cats = await _dao.getAllCategories();
    return InventoryState(products: products, categories: cats);
  }

  Future<void> refresh() async {
    state = AsyncData<InventoryState>(state.value!.copyWith(isLoading: true));
    final InventoryState s = await _load();
    state = AsyncData<InventoryState>(s);
  }

  void setSearch(String q) {
    state = AsyncData<InventoryState>(state.value!.copyWith(searchQuery: q));
  }

  void setCategory(String? categoryId) {
    state = AsyncData<InventoryState>(state.value!.copyWith(
      selectedCategory: categoryId,
      clearCategory: categoryId == null,
    ));
  }

  // ── Products ─────────────────────────────────────────────────────────────

  Future<void> addProduct({
    required String name,
    String? barcode,
    required double unitPrice,
    required double costPrice,
    required int stockQty,
    required int threshold,
    String? categoryId,
  }) async {
    final Product product = Product(
      productId: _uuid.v4(),
      categoryId: categoryId,
      barcode: barcode,
      name: name,
      unitPrice: unitPrice,
      costPrice: costPrice,
      stockQty: stockQty,
      threshold: threshold,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _dao.insert(product);
    try {
      await _generateSuggestionFor(product);
    } catch (_) {}
    try {
      if (!_isOffline) {
        await SyncNotifier.enqueue(
          entityType: 'products',
          entityId: product.productId,
          operation: 'create',
          payload: product.toMap(),
        );
        ref.read(syncProvider.notifier).sync();
      }
    } catch (_) {}
    await refresh();
  }

  Future<void> updateProduct(Product product) async {
    await _dao.update(product);
    try {
      await _generateSuggestionFor(product);
    } catch (_) {}
    try {
      if (!_isOffline) {
        await SyncNotifier.enqueue(
          entityType: 'products',
          entityId: product.productId,
          operation: 'update',
          payload: product.toMap(),
        );
        ref.read(syncProvider.notifier).sync();
      }
    } catch (_) {}
    await refresh();
  }

  Future<void> deleteProduct(String productId) async {
    await _dao.deactivate(productId);
    if (!_isOffline) {
      await SyncNotifier.enqueue(
        entityType: 'products',
        entityId: productId,
        operation: 'delete',
        payload: <String, dynamic>{'product_id': productId},
      );
      ref.read(syncProvider.notifier).sync();
    }
    await refresh();
  }

  Future<void> _generateSuggestionFor(Product product) async {
    if (product.costPrice <= 0) return;
    final double suggested =
        double.parse((product.costPrice * 1.25).toStringAsFixed(2));
    final double diff = (suggested - product.unitPrice).abs();
    if (product.unitPrice > 0 && diff / product.unitPrice < 0.05) return;
    await _dao.insertPriceSuggestion(<String, dynamic>{
      'suggestion_id': _uuid.v4(),
      'product_id': product.productId,
      'suggested_price': suggested,
      'benchmark_source': 'cost_markup',
      'fetched_at': DateTime.now().toIso8601String(),
      'accepted': 0,
    });
  }

  Future<void> recalculateAllSuggestions() async {
    final List<Product> products = await _dao.getAllProducts();
    for (final Product p in products) {
      await _generateSuggestionFor(p);
    }
    await refresh();
  }

  Future<void> updateStock(String productId, int newQty) async {
    await _dao.updateStock(productId, newQty);
    if (!_isOffline) {
      try {
        final List<Product> products = await _dao.getAllProducts();
        final Product? p =
            products.where((Product x) => x.productId == productId).firstOrNull;
        if (p != null) {
          await SyncNotifier.enqueue(
            entityType: 'products',
            entityId: productId,
            operation: 'update',
            payload: p.copyWith(stockQty: newQty).toMap(),
          );
          ref.read(syncProvider.notifier).sync();
        }
      } catch (_) {}
    }
    await refresh();
  }

  Future<void> acceptSuggestedPrice(String productId, double price) async {
    await _dao.acceptPriceSuggestion(productId, price);
    await refresh();
  }

  // ── Categories ───────────────────────────────────────────────────────────

  Future<String> addCategory(String name, {String? description}) async {
    final Category cat = Category(
      categoryId: _uuid.v4(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );
    await _dao.insertCategory(cat);
    if (!_isOffline) {
      await SyncNotifier.enqueue(
        entityType: 'categories',
        entityId: cat.categoryId,
        operation: 'create',
        payload: cat.toMap(),
      );
      ref.read(syncProvider.notifier).sync();
    }
    await refresh();
    return cat.categoryId;
  }

  Future<void> deleteCategory(String categoryId) async {
    await _dao.deleteCategory(categoryId);
    if (!_isOffline) {
      await SyncNotifier.enqueue(
        entityType: 'categories',
        entityId: categoryId,
        operation: 'delete',
        payload: <String, dynamic>{'category_id': categoryId},
      );
      ref.read(syncProvider.notifier).sync();
    }
    await refresh();
  }
}

final AsyncNotifierProvider<InventoryNotifier, InventoryState>
    inventoryProvider =
    AsyncNotifierProvider<InventoryNotifier, InventoryState>(
        InventoryNotifier.new);

// Helper: check if a storeId looks like an offline UUID (not a Firebase UID)
// Firebase UIDs are 28 chars; offline UUIDs are 36 chars (with dashes)
Future<bool> isOfflineModeActive() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isOfflineMode') ?? false;
}
