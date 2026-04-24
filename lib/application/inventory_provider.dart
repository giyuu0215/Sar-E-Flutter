import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/local/daos/product_dao.dart';
import '../domain/entities/category.dart';
import '../domain/entities/product.dart';

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
  final String? selectedCategory; // category_id or null = all

  List<Product> get filtered {
    Iterable<Product> list = products;
    if (selectedCategory != null) {
      list = list.where((Product p) => p.categoryId == selectedCategory);
    }
    if (searchQuery.isNotEmpty) {
      final String q = searchQuery.toLowerCase();
      list = list.where(
          (Product p) => p.name.toLowerCase().contains(q));
    }
    return list.toList();
  }

  int get lowStockCount =>
      products.where((Product p) => p.isLowStock).length;

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

  @override
  Future<InventoryState> build() async {
    return _load();
  }

  Future<InventoryState> _load() async {
    final List<Product> products = await _dao.getAllProducts();
    final List<Category> cats = await _dao.getAllCategories();
    return InventoryState(products: products, categories: cats);
  }

  Future<void> refresh() async {
    state = AsyncData<InventoryState>(
        state.value!.copyWith(isLoading: true));
    final InventoryState s = await _load();
    state = AsyncData<InventoryState>(s);
  }

  void setSearch(String q) {
    state = AsyncData<InventoryState>(
        state.value!.copyWith(searchQuery: q));
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
    await _generateSuggestionFor(product);
    await refresh();
  }

  Future<void> updateProduct(Product product) async {
    await _dao.update(product);
    await _generateSuggestionFor(product);
    await refresh();
  }

  /// Generates a cost-based price suggestion (cost × 1.25) for a single product.
  /// Only inserts if the suggestion differs from the current price by > 5%.
  Future<void> _generateSuggestionFor(Product product) async {
    if (product.costPrice <= 0) return;
    final double suggested =
        double.parse((product.costPrice * 1.25).toStringAsFixed(2));
    final double diff = (suggested - product.unitPrice).abs();
    if (diff / product.unitPrice < 0.05) return; // < 5% diff — skip
    await _dao.insertPriceSuggestion(<String, dynamic>{
      'suggestion_id': _uuid.v4(),
      'product_id': product.productId,
      'suggested_price': suggested,
      'fetched_at': DateTime.now().toIso8601String(),
      'accepted': 0,
    });
  }

  /// Recalculates suggestions for ALL products. Call manually from UI if needed.
  Future<void> recalculateAllSuggestions() async {
    final List<Product> products = await _dao.getAllProducts();
    for (final Product p in products) {
      await _generateSuggestionFor(p);
    }
    await refresh();
  }

  Future<void> updateStock(String productId, int newQty) async {
    await _dao.updateStock(productId, newQty);
    await refresh();
  }

  Future<void> deleteProduct(String productId) async {
    await _dao.deactivate(productId);
    await refresh();
  }

  Future<void> acceptSuggestedPrice(String productId, double price) async {
    await _dao.acceptPriceSuggestion(productId, price);
    await refresh();
  }

  // ── Categories ───────────────────────────────────────────────────────────

  Future<void> addCategory(String name, {String? description}) async {
    final Category cat = Category(
      categoryId: _uuid.v4(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );
    await _dao.insertCategory(cat);
    await refresh();
  }

  Future<void> deleteCategory(String categoryId) async {
    await _dao.deleteCategory(categoryId);
    await refresh();
  }
}

final AsyncNotifierProvider<InventoryNotifier, InventoryState>
    inventoryProvider =
    AsyncNotifierProvider<InventoryNotifier, InventoryState>(
        InventoryNotifier.new);
