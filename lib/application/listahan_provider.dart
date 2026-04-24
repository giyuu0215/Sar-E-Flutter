import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/local/daos/credit_dao.dart';
import '../data/local/daos/customer_dao.dart';
import '../domain/entities/credit_entry.dart';
import '../domain/entities/customer.dart';
import 'auth_provider.dart';
import 'sync_provider.dart';

const Uuid _uuid = Uuid();

class ListahanState {
  const ListahanState({
    this.entries = const <CreditEntry>[],
    this.customers = const <Customer>[],
    this.isLoading = false,
    this.filterStatus,
    this.searchQuery = '',
    this.totalOutstanding = 0,
  });

  final List<CreditEntry> entries;
  final List<Customer> customers;
  final bool isLoading;
  final String? filterStatus; // null=all | 'active' | 'overdue' | 'settled'
  final String searchQuery;
  final double totalOutstanding;

  List<CreditEntry> get filtered {
    Iterable<CreditEntry> list = entries;
    if (filterStatus != null) {
      list = list.where((CreditEntry e) => e.status == filterStatus);
    }
    if (searchQuery.isNotEmpty) {
      final String q = searchQuery.toLowerCase();
      list = list.where((CreditEntry e) =>
          (e.customerName ?? '').toLowerCase().contains(q) ||
          (e.customerPhone ?? '').contains(q));
    }
    return list.toList();
  }

  int get overdueCount => entries.where((CreditEntry e) => e.isOverdue).length;

  ListahanState copyWith({
    List<CreditEntry>? entries,
    List<Customer>? customers,
    bool? isLoading,
    String? filterStatus,
    bool clearFilter = false,
    String? searchQuery,
    double? totalOutstanding,
  }) =>
      ListahanState(
        entries: entries ?? this.entries,
        customers: customers ?? this.customers,
        isLoading: isLoading ?? this.isLoading,
        filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
        searchQuery: searchQuery ?? this.searchQuery,
        totalOutstanding: totalOutstanding ?? this.totalOutstanding,
      );
}

class ListahanNotifier extends AsyncNotifier<ListahanState> {
  final CreditDao _creditDao = CreditDao();
  final CustomerDao _customerDao = CustomerDao();

  @override
  Future<ListahanState> build() async => _load();

  Future<ListahanState> _load() async {
    final List<CreditEntry> entries = await _creditDao.getAll();
    final List<Customer> customers = await _customerDao.getAll();
    final double outstanding = await _creditDao.getTotalOutstanding();
    return ListahanState(
      entries: entries,
      customers: customers,
      totalOutstanding: outstanding,
    );
  }

  Future<void> refresh() async {
    state = AsyncData<ListahanState>(state.value!.copyWith(isLoading: true));
    state = AsyncData<ListahanState>(await _load());
  }

  void setFilter(String? status) {
    state = AsyncData<ListahanState>(state.value!.copyWith(
      filterStatus: status,
      clearFilter: status == null,
    ));
  }

  void setSearch(String q) {
    state = AsyncData<ListahanState>(state.value!.copyWith(searchQuery: q));
  }

  bool get _isOffline => ref.read(authProvider).value?.isOfflineMode ?? false;

  // ── Customers ─────────────────────────────────────────────────────────────

  /// Insert customer + sync + refresh UI. Use from top-level actions.
  Future<Customer> addCustomer(String name, {String? mobile}) async {
    final Customer customer = await addCustomerSilent(name, mobile: mobile);
    await refresh();
    return customer;
  }

  /// Insert customer + sync but **skip** refresh.
  /// Use from inside open dialogs to avoid orphaning widget contexts
  /// (which causes the grey overlay bug).
  Future<Customer> addCustomerSilent(String name, {String? mobile}) async {
    final Customer customer = Customer(
      customerId: _uuid.v4(),
      name: name,
      mobileNumber: mobile?.isEmpty == true ? null : mobile,
      creditBalance: 0,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await _customerDao.insert(customer);
    if (!_isOffline) {
      try {
        await SyncNotifier.enqueue(
          entityType: 'customers',
          entityId: customer.customerId,
          operation: 'create',
          payload: customer.toMap(),
        );
        ref.read(syncProvider.notifier).sync(); // fire-and-forget
      } catch (_) {}
    }
    return customer;
  }

  Future<List<Customer>> searchCustomers(String q) => _customerDao.search(q);

  // ── Credit entries ────────────────────────────────────────────────────────

  Future<void> addCreditEntry({
    required String customerId,
    required List<String> items,
    required double amount,
    required DateTime dueDate,
  }) async {
    final CreditEntry entry = CreditEntry(
      entryId: _uuid.v4(),
      customerId: customerId,
      items: jsonEncode(items),
      amount: amount,
      amountPaid: 0,
      dueDate: dueDate,
      status: 'active',
      reminderCount: 0,
      createdAt: DateTime.now(),
    );
    await _creditDao.insert(entry);

    // Update customer credit balance
    final Customer? customer = await _customerDao.getById(customerId);
    if (customer != null) {
      await _customerDao.updateCreditBalance(
        customerId,
        customer.creditBalance + amount,
      );
    }
    if (!_isOffline) {
      try {
        await SyncNotifier.enqueue(
          entityType: 'credit_entries',
          entityId: entry.entryId,
          operation: 'create',
          payload: entry.toMap(),
        );
        ref.read(syncProvider.notifier).sync(); // fire-and-forget
      } catch (_) {}
    }
    await refresh();
  }

  Future<void> recordRepayment(String entryId, double amountPaid,
      {String? notes}) async {
    final CreditEntry? entry = await _creditDao.getById(entryId);
    if (entry == null) return;

    final RepaymentRecord record = RepaymentRecord(
      repaymentId: _uuid.v4(),
      entryId: entryId,
      amountPaid: amountPaid,
      timestamp: DateTime.now(),
      notes: notes,
    );
    await _creditDao.insertRepayment(record);

    // Update entry
    final double newPaid = entry.amountPaid + amountPaid;
    String newStatus = entry.status;
    if (newPaid >= entry.amount) {
      newStatus = 'settled';
    } else if (entry.dueDate.isBefore(DateTime.now())) {
      newStatus = 'overdue';
    }
    final CreditEntry updated =
        entry.copyWith(amountPaid: newPaid, status: newStatus);
    await _creditDao.update(updated);

    // Update customer balance
    final Customer? customer = await _customerDao.getById(entry.customerId);
    if (customer != null) {
      final double newBalance =
          (customer.creditBalance - amountPaid).clamp(0, double.infinity);
      await _customerDao.updateCreditBalance(entry.customerId, newBalance);
    }
    if (!_isOffline) {
      try {
        await SyncNotifier.enqueue(
          entityType: 'repayments',
          entityId: record.repaymentId,
          operation: 'create',
          payload: record.toMap(),
        );
        ref.read(syncProvider.notifier).sync(); // fire-and-forget
      } catch (_) {}
    }
    await refresh();
  }

  Future<void> markOverdue() async {
    final List<CreditEntry> overdue = await _creditDao.getOverdue();
    for (final CreditEntry e in overdue) {
      if (e.status != 'overdue') {
        await _creditDao.update(e.copyWith(status: 'overdue'));
      }
    }
    await refresh();
  }

  Future<List<RepaymentRecord>> getRepayments(String entryId) =>
      _creditDao.getRepayments(entryId);
}

final AsyncNotifierProvider<ListahanNotifier, ListahanState> listahanProvider =
    AsyncNotifierProvider<ListahanNotifier, ListahanState>(
        ListahanNotifier.new);
