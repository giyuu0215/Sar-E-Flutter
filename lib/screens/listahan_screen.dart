import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CreditEntry {
  const CreditEntry({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.items,
    required this.amount,
    required this.amountPaid,
    required this.status,
    required this.notes,
  });

  final String id;
  final String customerName;
  final String phone;
  final String items;
  final double amount;
  final double amountPaid;
  final String status;
  final String notes;

  double get remaining => amount - amountPaid;

  CreditEntry copyWith({double? amountPaid, String? status}) {
    return CreditEntry(
      id: id,
      customerName: customerName,
      phone: phone,
      items: items,
      amount: amount,
      amountPaid: amountPaid ?? this.amountPaid,
      status: status ?? this.status,
      notes: notes,
    );
  }
}

class ListahanScreen extends StatefulWidget {
  const ListahanScreen({super.key});

  @override
  State<ListahanScreen> createState() => _ListahanScreenState();
}

class _ListahanScreenState extends State<ListahanScreen> {
  final List<CreditEntry> _entries = <CreditEntry>[
    const CreditEntry(
      id: '1',
      customerName: 'Mrs. Santos',
      phone: '09171234567',
      items: 'Lucky Me x5, Nescafe x10',
      amount: 142.5,
      amountPaid: 0,
      status: 'overdue',
      notes: 'Always pays on Saturday',
    ),
    const CreditEntry(
      id: '2',
      customerName: 'Mr. Cruz',
      phone: '09281234567',
      items: 'Century Tuna x3, Skyflakes x4',
      amount: 119.5,
      amountPaid: 50,
      status: 'active',
      notes: '',
    ),
    const CreditEntry(
      id: '3',
      customerName: 'Mrs. Reyes',
      phone: '09561234567',
      items: 'Bear Brand x6, Yakult x5',
      amount: 143.5,
      amountPaid: 143.5,
      status: 'settled',
      notes: 'Always pays early',
    ),
    const CreditEntry(
      id: '4',
      customerName: 'Ms. Dela Torre',
      phone: '09391234567',
      items: 'Oishi Prawn x8, Century Tuna x2',
      amount: 177,
      amountPaid: 100,
      status: 'active',
      notes: '',
    ),
    const CreditEntry(
      id: '5',
      customerName: 'Mr. Manalo',
      phone: '09221234567',
      items: 'Purefoods Corned Beef x4, Lucky Me x10',
      amount: 238,
      amountPaid: 0,
      status: 'overdue',
      notes: 'Not answering calls',
    ),
  ];

  final TextEditingController _payController = TextEditingController();
  String _activeTab = 'all';
  String? _expandedId;

  @override
  void dispose() {
    _payController.dispose();
    super.dispose();
  }

  List<CreditEntry> get _filtered {
    if (_activeTab == 'all') {
      return _entries;
    }
    return _entries.where((CreditEntry e) => e.status == _activeTab).toList();
  }

  int get _activeCount =>
      _entries.where((CreditEntry e) => e.status == 'active').length;
  int get _overdueCount =>
      _entries.where((CreditEntry e) => e.status == 'overdue').length;
  double get _totalOutstanding => _entries
      .where((CreditEntry e) => e.status != 'settled')
      .fold<double>(0, (double s, CreditEntry e) => s + e.remaining);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1300),
        ),
      );
  }

  void _sendSmsReminder(CreditEntry entry) {
    _showMessage('SMS reminder sent to ${entry.customerName}!');
  }

  void _recordPayment(CreditEntry entry) {
    _payController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: appColors(context).surface,
      builder: (BuildContext context) {
        final AppColors c = appColors(context);
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Record Payment',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Total: PHP ${entry.amount.toStringAsFixed(2)}',
                      style: TextStyle(color: c.textSecondary),
                    ),
                    Text(
                      'Paid: PHP ${entry.amountPaid.toStringAsFixed(2)}',
                      style: TextStyle(color: c.textSecondary),
                    ),
                    Text(
                      'Remaining: PHP ${entry.remaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: c.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _payController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'Max: PHP ${entry.remaining.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final double amount =
                        double.tryParse(_payController.text) ?? 0;
                    if (amount <= 0) {
                      return;
                    }
                    setState(() {
                      final int idx = _entries.indexWhere(
                        (CreditEntry e) => e.id == entry.id,
                      );
                      if (idx >= 0) {
                        final double nextPaid =
                            (_entries[idx].amountPaid + amount).clamp(
                              0,
                              _entries[idx].amount,
                            );
                        _entries[idx] = _entries[idx].copyWith(
                          amountPaid: nextPaid,
                          status: nextPaid >= _entries[idx].amount
                              ? 'settled'
                              : _entries[idx].status,
                        );
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Confirm Payment'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.menu_book_rounded),
              const SizedBox(width: 8),
              Text(
                'Credit Ledger',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Credit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _MiniStat(
                title: 'Active',
                value: '$_activeCount',
                color: c.primary,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                title: 'Overdue',
                value: '$_overdueCount',
                color: c.warning,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                title: 'Outstanding',
                value: 'PHP ${_totalOutstanding.toStringAsFixed(0)}',
                color: c.error,
              ),
            ],
          ),
          if (_overdueCount > 0) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.warning.withValues(alpha: 0.35)),
              ),
              child: Text(
                '$_overdueCount account(s) are overdue. Send reminders.',
                style: TextStyle(color: c.warning, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <String>['all', 'active', 'overdue', 'settled'].map((
                String tab,
              ) {
                final bool selected = _activeTab == tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 112,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _activeTab = tab),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selected ? c.primary : c.surfaceMuted,
                        foregroundColor: selected
                            ? Colors.white
                            : c.textSecondary,
                        side: BorderSide(
                          color: selected ? c.primary : c.border,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tab[0].toUpperCase() + tab.substring(1),
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          ..._filtered.map((CreditEntry entry) {
            final bool expanded = _expandedId == entry.id;
            final double paidPct = entry.amount == 0
                ? 0
                : (entry.amountPaid / entry.amount).clamp(0, 1);
            final Color statusColor = switch (entry.status) {
              'active' => c.primary,
              'overdue' => c.warning,
              _ => c.info,
            };
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () =>
                    setState(() => _expandedId = expanded ? null : entry.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: statusColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(Icons.person, color: statusColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                'PHP ${entry.remaining.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'of PHP ${entry.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (expanded) ...<Widget>[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: paidPct,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.items,
                            style: TextStyle(color: c.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: entry.status == 'settled'
                                    ? null
                                    : () => _recordPayment(entry),
                                icon: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                label: const Text('Pay'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: entry.status == 'settled'
                                  ? null
                                  : () => _sendSmsReminder(entry),
                              icon: const Icon(Icons.sms_outlined),
                              tooltip: 'Send SMS reminder',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
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
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
