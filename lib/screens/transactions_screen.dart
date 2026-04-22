import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/liquid_background.dart';

class TxItem {
  const TxItem({required this.name, required this.qty, required this.price});

  final String name;
  final int qty;
  final double price;
}

class Txn {
  const Txn({
    required this.id,
    required this.date,
    required this.time,
    required this.items,
    required this.subtotal,
    required this.vat,
    required this.total,
    required this.paymentMethod,
    this.cashTendered,
    this.change,
  });

  final String id;
  final String date;
  final String time;
  final List<TxItem> items;
  final double subtotal;
  final double vat;
  final double total;
  final String paymentMethod;
  final double? cashTendered;
  final double? change;
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final List<Txn> _all = <Txn>[
    const Txn(
      id: 'TXN-004741',
      date: '2026-04-20',
      time: '14:35',
      items: <TxItem>[
        TxItem(name: 'Lucky Me Pancit Canton', qty: 2, price: 11),
        TxItem(name: 'Oishi Prawn Crackers', qty: 3, price: 15),
      ],
      subtotal: 67,
      vat: 8.04,
      total: 75.04,
      paymentMethod: 'GCash',
    ),
    const Txn(
      id: 'TXN-004740',
      date: '2026-04-20',
      time: '13:18',
      items: <TxItem>[
        TxItem(name: 'Century Tuna', qty: 2, price: 28.5),
        TxItem(name: 'Skyflakes', qty: 3, price: 8.5),
      ],
      subtotal: 82.5,
      vat: 9.9,
      total: 92.4,
      paymentMethod: 'Cash',
      cashTendered: 100,
      change: 7.6,
    ),
    const Txn(
      id: 'TXN-004739',
      date: '2026-04-20',
      time: '11:42',
      items: <TxItem>[
        TxItem(name: 'Nescafe 3-in-1 Coffee', qty: 5, price: 8.75),
        TxItem(name: 'Bear Brand Milk Powder', qty: 4, price: 13.5),
      ],
      subtotal: 97.75,
      vat: 11.73,
      total: 109.48,
      paymentMethod: 'Maya',
    ),
    const Txn(
      id: 'TXN-004738',
      date: '2026-04-19',
      time: '18:20',
      items: <TxItem>[
        TxItem(name: 'Purefoods Corned Beef', qty: 1, price: 32),
        TxItem(name: 'Lucky Me Pancit Canton', qty: 5, price: 11),
      ],
      subtotal: 87,
      vat: 10.44,
      total: 97.44,
      paymentMethod: 'Cash',
      cashTendered: 100,
      change: 2.56,
    ),
    const Txn(
      id: 'TXN-004737',
      date: '2026-04-19',
      time: '16:05',
      items: <TxItem>[
        TxItem(name: 'Yakult Probiotic Drink', qty: 6, price: 12.5),
        TxItem(name: 'Oishi Prawn Crackers', qty: 2, price: 15),
      ],
      subtotal: 105,
      vat: 12.6,
      total: 117.6,
      paymentMethod: 'QR Ph',
    ),
    const Txn(
      id: 'TXN-004736',
      date: '2026-04-19',
      time: '14:55',
      items: <TxItem>[
        TxItem(name: 'Century Tuna Regular', qty: 3, price: 28.5),
      ],
      subtotal: 85.5,
      vat: 10.26,
      total: 95.76,
      paymentMethod: 'Cash',
      cashTendered: 100,
      change: 4.24,
    ),
    const Txn(
      id: 'TXN-004735',
      date: '2026-04-18',
      time: '17:30',
      items: <TxItem>[
        TxItem(name: 'Skyflakes Crackers', qty: 10, price: 8.5),
        TxItem(name: 'Nescafe 3-in-1 Coffee', qty: 8, price: 8.75),
      ],
      subtotal: 155,
      vat: 18.6,
      total: 173.6,
      paymentMethod: 'GCash',
    ),
    const Txn(
      id: 'TXN-004734',
      date: '2026-04-18',
      time: '10:15',
      items: <TxItem>[
        TxItem(name: 'Bear Brand Milk Powder', qty: 5, price: 13.5),
        TxItem(name: 'Yakult Probiotic Drink', qty: 4, price: 12.5),
      ],
      subtotal: 117.5,
      vat: 14.1,
      total: 131.6,
      paymentMethod: 'Maya',
    ),
  ];

  String _search = '';
  String _filter = 'all';
  String? _expanded;

  List<Txn> get _filtered {
    final DateTime today = DateTime(2026, 4, 20);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime weekAgo = today.subtract(const Duration(days: 7));

    return _all.where((Txn tx) {
      final bool searchOk =
          tx.id.toLowerCase().contains(_search.toLowerCase()) ||
          tx.items.any(
            (TxItem i) => i.name.toLowerCase().contains(_search.toLowerCase()),
          );

      bool filterOk = true;
      final DateTime txDate = DateTime.parse(tx.date);
      if (_filter == 'today') {
        filterOk =
            txDate.year == today.year &&
            txDate.month == today.month &&
            txDate.day == today.day;
      } else if (_filter == 'yesterday') {
        filterOk =
            txDate.year == yesterday.year &&
            txDate.month == yesterday.month &&
            txDate.day == yesterday.day;
      } else if (_filter == 'week') {
        filterOk = txDate.isAfter(weekAgo.subtract(const Duration(seconds: 1)));
      }

      return searchOk && filterOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final double revenue = _filtered.fold<double>(
      0,
      (double s, Txn t) => s + t.total,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: LiquidBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
          children: <Widget>[
            Text(
              '${_filtered.length} transactions | PHP ${revenue.toStringAsFixed(2)}',
              style: TextStyle(color: c.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (String v) => setState(() => _search = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by ID or product...',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children:
                  <Map<String, String>>[
                    <String, String>{'key': 'all', 'label': 'All'},
                    <String, String>{'key': 'today', 'label': 'Today'},
                    <String, String>{'key': 'yesterday', 'label': 'Yesterday'},
                    <String, String>{'key': 'week', 'label': 'This Week'},
                  ].map((Map<String, String> it) {
                    return ChoiceChip(
                      label: Text(it['label']!),
                      selected: _filter == it['key'],
                      onSelected: (_) => setState(() => _filter = it['key']!),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 10),
            ..._filtered.map((Txn tx) {
              final bool expanded = _expanded == tx.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _expanded = expanded ? null : tx.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            CircleAvatar(
                              backgroundColor: c.primary.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.check_circle_outline,
                                color: c.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    tx.id,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${tx.date} | ${tx.time} | ${tx.paymentMethod}',
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'PHP ${tx.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: c.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (expanded) ...<Widget>[
                          const SizedBox(height: 10),
                          ...tx.items.map(
                            (TxItem i) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  '${i.name} x${i.qty}',
                                  style: TextStyle(color: c.textSecondary),
                                ),
                                Text(
                                  'PHP ${(i.price * i.qty).toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text('Subtotal'),
                              Text('PHP ${tx.subtotal.toStringAsFixed(2)}'),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text('VAT'),
                              Text('PHP ${tx.vat.toStringAsFixed(2)}'),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text(
                                'Total',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'PHP ${tx.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          if (tx.paymentMethod == 'Cash' &&
                              tx.cashTendered != null) ...<Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                const Text('Cash Tendered'),
                                Text(
                                  'PHP ${tx.cashTendered!.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                const Text('Change'),
                                Text('PHP ${tx.change!.toStringAsFixed(2)}'),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Text(
                    'No transactions found',
                    style: TextStyle(color: c.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
