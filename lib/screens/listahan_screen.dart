import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/auth_provider.dart';
import '../application/listahan_provider.dart';
import '../domain/entities/credit_entry.dart';
import '../domain/entities/customer.dart';
import '../theme/app_theme.dart';

class ListahanScreen extends ConsumerWidget {
  const ListahanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(listahanProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(child: Text('Error: $e')),
          data: (ListahanState state) => _ListahanContent(state: state),
        );
  }
}

class _ListahanContent extends ConsumerStatefulWidget {
  const _ListahanContent({required this.state});

  final ListahanState state;

  @override
  ConsumerState<_ListahanContent> createState() => _ListahanContentState();
}

class _ListahanContentState extends ConsumerState<_ListahanContent> {
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openAddCreditDialog() async {
    Customer? selectedCustomer;
    final TextEditingController customerSearchCtrl =
        TextEditingController();
    List<Customer> searchResults = List<Customer>.from(widget.state.customers);
    final TextEditingController itemsCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (_, StateSetter setS) {
            return AlertDialog(
              title: const Text('New Credit Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Customer search/select
                    if (selectedCustomer == null) ...<Widget>[
                      TextField(
                        controller: customerSearchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Search customer',
                          prefixIcon: Icon(Icons.person_search_outlined),
                        ),
                        onChanged: (String v) async {
                          if (v.isEmpty) {
                            setS(() => searchResults =
                                List<Customer>.from(widget.state.customers));
                          } else {
                            final List<Customer> results = await ref
                                .read(listahanProvider.notifier)
                                .searchCustomers(v);
                            setS(() => searchResults = results);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      if (searchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: appColors(ctx).border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            itemBuilder: (_, int i) => ListTile(
                              dense: true,
                              title: Text(searchResults[i].name),
                              subtitle:
                                  Text(searchResults[i].mobileNumber ?? ''),
                              onTap: () => setS(
                                  () => selectedCustomer = searchResults[i]),
                            ),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () async {
                          final Customer? newCustomer =
                              await _showAddCustomerDialog(ctx);
                          if (newCustomer != null) {
                            setS(() => selectedCustomer = newCustomer);
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('New customer'),
                      ),
                    ] else ...<Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.person, color: appColors(ctx).primary),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(selectedCustomer!.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () =>
                                setS(() => selectedCustomer = null),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: itemsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Items (comma separated)',
                        hintText: 'e.g. Lucky Me x5, Bear Brand x2',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Amount (PHP) *',
                        prefixText: '₱ ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Due date picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(
                          'Due: ${DateFormat('MMM d, y').format(dueDate)}'),
                      trailing: TextButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setS(() => dueDate = picked);
                        },
                        child: const Text('Change'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedCustomer == null) {
                      _showMessage('Please select a customer.');
                      return;
                    }
                    final double amount =
                        double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0) {
                      _showMessage('Please enter a valid amount.');
                      return;
                    }
                    final List<String> items = itemsCtrl.text
                        .split(',')
                        .map((String s) => s.trim())
                        .where((String s) => s.isNotEmpty)
                        .toList();
                    Navigator.pop(ctx);
                    await ref
                        .read(listahanProvider.notifier)
                        .addCreditEntry(
                          customerId: selectedCustomer!.customerId,
                          items: items,
                          amount: amount,
                          dueDate: dueDate,
                        );
                    _showMessage('Credit entry added');
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: appColors(ctx).primary,
                      foregroundColor: Colors.white),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Customer?> _showAddCustomerDialog(BuildContext ctx) async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController mobileCtrl = TextEditingController();
    return showDialog<Customer>(
      context: ctx,
      builder: (BuildContext ctx2) {
        return AlertDialog(
          title: const Text('New Customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 10),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile (optional)',
                  hintText: '09xxxxxxxxx',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                // Create the customer, then close ONLY this inner dialog.
                final Customer c =
                    await ref.read(listahanProvider.notifier).addCustomer(
                          nameCtrl.text.trim(),
                          mobile: mobileCtrl.text.trim().isEmpty
                              ? null
                              : mobileCtrl.text.trim(),
                        );
                if (ctx2.mounted) Navigator.pop(ctx2, c);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: appColors(ctx2).primary,
                  foregroundColor: Colors.white),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRepayDialog(CreditEntry entry) async {
    final TextEditingController amountCtrl = TextEditingController();
    final TextEditingController notesCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Repayment – ${entry.customerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Outstanding: PHP ${entry.remaining.toStringAsFixed(2)}',
                style: TextStyle(
                    color: appColors(ctx).primary,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount paid (PHP) *',
                  prefixText: '₱ ',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final double amount =
                    double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) {
                  _showMessage('Please enter a valid amount.');
                  return;
                }
                Navigator.pop(ctx);
                await ref
                    .read(listahanProvider.notifier)
                    .recordRepayment(entry.entryId, amount,
                        notes: notesCtrl.text.isNotEmpty
                            ? notesCtrl.text
                            : null);
                _showMessage('Repayment recorded');
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: appColors(ctx).primary,
                  foregroundColor: Colors.white),
              child: const Text('Record'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final ListahanState state = widget.state;
    final List<CreditEntry> filtered = state.filtered;

    final List<String> filters = <String>[
      'All',
      'active',
      'overdue',
      'settled',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              const Icon(Icons.menu_book_outlined),
              const SizedBox(width: 8),
              Text('Listahan',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _openAddCreditDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats row
          Row(children: <Widget>[
            _StatCard(
              label: 'Entries',
              value: '${state.entries.length}',
              color: c.primary,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Overdue',
              value: '${state.overdueCount}',
              color: c.error,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Outstanding',
              value: 'PHP ${(state.totalOutstanding / 1000).toStringAsFixed(1)}k',
              color: c.warning,
            ),
          ]),
          const SizedBox(height: 10),

          // Search
          TextField(
            onChanged: (String v) =>
                ref.read(listahanProvider.notifier).setSearch(v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search customer...',
            ),
          ),
          const SizedBox(height: 8),

          // Status filter chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: filters.asMap().entries.map((MapEntry<int, String> e) {
                final String filter = e.value;
                final String? filterVal =
                    filter == 'All' ? null : filter;
                final bool selected = state.filterStatus == filterVal;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(filter[0].toUpperCase() +
                        filter.substring(1)),
                    selected: selected,
                    onSelected: (_) => ref
                        .read(listahanProvider.notifier)
                        .setFilter(filterVal),
                    selectedColor: c.primary.withValues(alpha: 0.15),
                    side: BorderSide(
                        color: selected ? c.primary : c.border),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text('No credit entries',
                    style: TextStyle(color: c.textSecondary)),
              ),
            )
          else
            ...filtered.map((CreditEntry entry) {
              final bool overdue = entry.isOverdue;
              final bool settled = entry.isSettled;
              final Color statusColor = settled
                  ? c.info
                  : overdue
                      ? c.error
                      : c.primary;
              final String statusLabel =
                  entry.status[0].toUpperCase() + entry.status.substring(1);

              List<String> items = <String>[];
              try {
                final dynamic decoded = jsonDecode(entry.items);
                if (decoded is List<dynamic>) {
                  items = decoded.cast<String>();
                }
              } catch (_) {
                items = <String>[entry.items];
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(children: <Widget>[
                        Expanded(
                          child: Text(
                            entry.customerName ?? 'Unknown',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ]),
                      if (entry.customerPhone != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(entry.customerPhone!,
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 12)),
                      ],
                      const SizedBox(height: 6),
                      if (items.isNotEmpty)
                        Text(items.join(', '),
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'PHP ${entry.remaining.toStringAsFixed(2)} remaining',
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Due: ${DateFormat('MMM d').format(entry.dueDate)}',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Progress bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              '${((entry.amountPaid / entry.amount) * 100).round()}% paid',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value:
                                      entry.amountPaid / entry.amount,
                                  minHeight: 6,
                                  backgroundColor:
                                      c.border,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          statusColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ]),
                      if (!settled) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _showRepayDialog(entry),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: c.primary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: Text('Record Payment',
                                    style:
                                        TextStyle(color: c.primary)),
                              ),
                            ),
                            if (entry.customerPhone != null) ...<Widget>[
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: () async {
                                  final double amt = entry.remaining;
                                  final String storeName = ref.read(authProvider).value?.user?.storeName ?? 'our store';
                                  final String msg = 'Hi ${entry.customerName}, reminder for your balance of PHP ${amt.toStringAsFixed(2)} at $storeName. Thank you!';
                                  final Uri uri = Uri(
                                    scheme: 'sms',
                                    path: entry.customerPhone!,
                                    queryParameters: <String, String>{'body': msg},
                                  );
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  } else {
                                    _showMessage('Could not launch SMS app');
                                  }
                                },
                                icon: Icon(Icons.sms_outlined, color: c.primary),
                                style: IconButton.styleFrom(
                                  backgroundColor: c.primary.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(value,
                style:
                    TextStyle(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    TextStyle(color: c.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
