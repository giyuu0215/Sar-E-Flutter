import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/local/daos/product_dao.dart';
import '../data/local/daos/transaction_dao.dart';
import '../domain/entities/product.dart';
import '../domain/entities/transaction.dart';

const Uuid _uuid = Uuid();

class CartItem {
  const CartItem({
    required this.product,
    required this.qty,
  });

  final Product product;
  final int qty;

  double get subtotal => product.unitPrice * qty;

  CartItem copyWith({int? qty}) =>
      CartItem(product: product, qty: qty ?? this.qty);
}

class CartState {
  const CartState({
    this.items = const <CartItem>[],
    this.paymentMethod = 'cash',
    this.tenderedCash,
    this.customerMobile,
    this.searchQuery = '',
    this.searchResults = const <Product>[],
    this.isProcessing = false,
    this.lastReceipt,
    this.error,
  });

  final List<CartItem> items;
  final String paymentMethod; // 'cash' | 'ewallet'
  final double? tenderedCash;
  final String? customerMobile;
  final String searchQuery;
  final List<Product> searchResults;
  final bool isProcessing;
  final Receipt? lastReceipt;
  final String? error;

  double get total =>
      items.fold<double>(0, (double s, CartItem i) => s + i.subtotal);

  double get changeDue =>
      paymentMethod == 'cash' && tenderedCash != null
          ? (tenderedCash! - total).clamp(0, double.infinity)
          : 0;

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? paymentMethod,
    double? tenderedCash,
    String? customerMobile,
    String? searchQuery,
    List<Product>? searchResults,
    bool? isProcessing,
    Receipt? lastReceipt,
    String? error,
    bool clearError = false,
    bool clearReceipt = false,
  }) =>
      CartState(
        items: items ?? this.items,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        tenderedCash: tenderedCash ?? this.tenderedCash,
        customerMobile: customerMobile ?? this.customerMobile,
        searchQuery: searchQuery ?? this.searchQuery,
        searchResults: searchResults ?? this.searchResults,
        isProcessing: isProcessing ?? this.isProcessing,
        lastReceipt: clearReceipt ? null : (lastReceipt ?? this.lastReceipt),
        error: clearError ? null : (error ?? this.error),
      );
}

class CartNotifier extends Notifier<CartState> {
  final ProductDao _productDao = ProductDao();
  final TransactionDao _txnDao = TransactionDao();

  @override
  CartState build() => const CartState();

  // ── Search ───────────────────────────────────────────────────────────────

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    if (query.isEmpty) {
      state = state.copyWith(searchResults: <Product>[]);
      return;
    }
    final List<Product> results = await _productDao.search(query);
    state = state.copyWith(searchResults: results);
  }

  // ── Cart management ──────────────────────────────────────────────────────

  void addProduct(Product product) {
    final List<CartItem> items = List<CartItem>.from(state.items);
    final int idx = items.indexWhere(
        (CartItem i) => i.product.productId == product.productId);
    if (idx >= 0) {
      final CartItem existing = items[idx];
      if (existing.qty >= product.stockQty) return; // respect stock
      items[idx] = existing.copyWith(qty: existing.qty + 1);
    } else {
      if (product.stockQty <= 0) return;
      items.add(CartItem(product: product, qty: 1));
    }
    state = state.copyWith(items: items);
  }

  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items
          .where((CartItem i) => i.product.productId != productId)
          .toList(),
    );
  }

  void changeQty(String productId, int delta) {
    final List<CartItem> items = List<CartItem>.from(state.items);
    final int idx = items
        .indexWhere((CartItem i) => i.product.productId == productId);
    if (idx < 0) return;
    final int newQty = items[idx].qty + delta;
    if (newQty <= 0) {
      items.removeAt(idx);
    } else if (newQty > items[idx].product.stockQty) {
      return; // can't exceed stock
    } else {
      items[idx] = items[idx].copyWith(qty: newQty);
    }
    state = state.copyWith(items: items);
  }

  void clearCart() {
    state = const CartState();
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method, tenderedCash: null);
  }

  void setTenderedCash(double amount) {
    state = state.copyWith(tenderedCash: amount);
  }

  void setCustomerMobile(String? mobile) {
    state = state.copyWith(customerMobile: mobile);
  }

  // ── Checkout ─────────────────────────────────────────────────────────────

  Future<bool> checkout() async {
    if (state.isEmpty) return false;
    if (state.paymentMethod == 'cash') {
      if (state.tenderedCash == null ||
          state.tenderedCash! < state.total) {
        state = state.copyWith(
            error: 'Tendered cash must be ≥ total amount');
        return false;
      }
    }

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final String txnId = _uuid.v4();
      final String receiptId = _uuid.v4();
      final DateTime now = DateTime.now();

      final bool isCash = state.paymentMethod == 'cash';
      final String txnStatus = isCash ? 'completed' : 'pending';
      final String payStatus = isCash ? 'confirmed' : 'pending';

      final Transaction txn = Transaction(
        transactionId: txnId,
        receiptId: receiptId,
        timestamp: now,
        paymentMethod: state.paymentMethod,
        totalAmount: state.total,
        changeDue: state.changeDue,
        status: txnStatus,
        createdAt: now,
      );

      final List<TransactionLineItem> items = state.items
          .map((CartItem ci) => TransactionLineItem(
                lineItemId: _uuid.v4(),
                transactionId: txnId,
                productId: ci.product.productId,
                qty: ci.qty,
                unitPrice: ci.product.unitPrice,
                subtotal: ci.subtotal,
              ))
          .toList();

      final PaymentRecord payment = PaymentRecord(
        paymentId: _uuid.v4(),
        transactionId: txnId,
        method: state.paymentMethod,
        amount: state.total,
        status: payStatus,
        confirmedAt: isCash ? now : null,
      );

      // Build QR payload (JSON with key receipt data)
      final Map<String, dynamic> qrData = <String, dynamic>{
        'receipt_id': receiptId,
        'transaction_id': txnId,
        'total': state.total,
        'timestamp': now.toIso8601String(),
        'items': state.items
            .map((CartItem ci) => <String, dynamic>{
                  'name': ci.product.name,
                  'qty': ci.qty,
                  'price': ci.product.unitPrice,
                })
            .toList(),
      };

      final Receipt receipt = Receipt(
        receiptId: receiptId,
        transactionId: txnId,
        storeName: 'SarE Store',
        timestamp: now,
        qrPayload: jsonEncode(qrData),
        customerMobile: state.customerMobile,
        deliveryStatus: 'pending',
      );

      // Save all & decrement stock
      await _txnDao.insertCheckout(
        txn: txn,
        items: items,
        payment: payment,
        receipt: receipt,
      );

      // Decrement stock in DB
      for (final CartItem ci in state.items) {
        await _productDao.updateStock(
          ci.product.productId,
          ci.product.stockQty - ci.qty,
        );
      }

      state = CartState(
        lastReceipt: receipt,
        isProcessing: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
          isProcessing: false, error: 'Checkout failed: $e');
      return false;
    }
  }
}

final NotifierProvider<CartNotifier, CartState> cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
