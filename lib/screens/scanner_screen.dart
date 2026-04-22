import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.barcode,
    required this.name,
    required this.price,
    required this.category,
    required this.qty,
  });

  final String id;
  final String barcode;
  final String name;
  final double price;
  final String category;
  final int qty;

  CartItem copyWith({int? qty}) {
    return CartItem(
      id: id,
      barcode: barcode,
      name: name,
      price: price,
      category: category,
      qty: qty ?? this.qty,
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  static final Map<String, ({String name, double price, String category})>
  _products = <String, ({String name, double price, String category})>{
    '4800098870004': (
      name: 'Lucky Me Pancit Canton',
      price: 11,
      category: 'Noodles',
    ),
    '4800028649208': (
      name: 'Bear Brand Milk Powder',
      price: 13.5,
      category: 'Dairy',
    ),
    '8850007212105': (
      name: 'Oishi Prawn Crackers',
      price: 15,
      category: 'Snacks',
    ),
    '4800016310043': (
      name: 'Century Tuna Regular',
      price: 28.5,
      category: 'Canned Goods',
    ),
    '4806520930011': (
      name: 'Skyflakes Crackers',
      price: 8.5,
      category: 'Biscuits',
    ),
    '8991234560012': (
      name: 'Yakult Probiotic Drink',
      price: 12.5,
      category: 'Beverages',
    ),
    '4902505193064': (
      name: 'Nescafe 3-in-1 Coffee',
      price: 8.75,
      category: 'Beverages',
    ),
    '4800016780010': (
      name: 'Purefoods Corned Beef',
      price: 32,
      category: 'Canned Goods',
    ),
  };

  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();

  final Random _random = Random();
  List<CartItem> _items = <CartItem>[];
  bool _scanning = false;
  double _scanProgress = 0;

  @override
  void dispose() {
    _barcodeController.dispose();
    _cashController.dispose();
    super.dispose();
  }

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

  double get _subtotal =>
      _items.fold<double>(0, (double s, CartItem i) => s + (i.price * i.qty));
  double get _vat => _subtotal * 0.12;
  double get _total => _subtotal + _vat;

  Future<void> _simulateScan() async {
    if (_scanning) {
      return;
    }

    setState(() {
      _scanning = true;
      _scanProgress = 0;
    });

    for (int i = 1; i <= 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) {
        return;
      }
      setState(() => _scanProgress = i * 10);
    }

    final List<String> barcodes = _products.keys.toList();
    final String barcode = barcodes[_random.nextInt(barcodes.length)];
    _addBarcode(barcode);

    if (!mounted) {
      return;
    }

    setState(() => _scanning = false);
  }

  void _addBarcode(String barcode) {
    final ({String name, double price, String category})? product =
        _products[barcode.trim()];
    if (product == null) {
      _showMessage('Barcode not found');
      return;
    }

    final int existing = _items.indexWhere(
      (CartItem i) => i.barcode == barcode,
    );
    setState(() {
      if (existing >= 0) {
        _items[existing] = _items[existing].copyWith(
          qty: _items[existing].qty + 1,
        );
      } else {
        _items = <CartItem>[
          CartItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            barcode: barcode,
            name: product.name,
            price: product.price,
            category: product.category,
            qty: 1,
          ),
          ..._items,
        ];
      }
    });
  }

  void _updateQty(CartItem item, int delta) {
    setState(() {
      _items = _items.map((CartItem i) {
        if (i.id != item.id) {
          return i;
        }
        final int nextQty = (i.qty + delta).clamp(1, 999);
        return i.copyWith(qty: nextQty);
      }).toList();
    });
  }

  void _removeItem(CartItem item) {
    setState(
      () => _items = _items.where((CartItem i) => i.id != item.id).toList(),
    );
  }

  void _openPayment() {
    if (_items.isEmpty) {
      _showMessage('No items to checkout');
      return;
    }

    _cashController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: appColors(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        final AppColors c = appColors(context);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double cash = double.tryParse(_cashController.text) ?? 0;
            final double change = cash - _total;

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
                          'Cash Payment',
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
                      children: <Widget>[
                        _line('Subtotal', _subtotal, c),
                        _line('VAT (12%)', _vat, c),
                        const Divider(height: 16),
                        _line('TOTAL', _total, c, bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cashController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Cash Tendered',
                      hintText: '0.00',
                    ),
                  ),
                  if (cash > 0) ...<Widget>[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        change >= 0
                            ? 'Change: PHP ${change.toStringAsFixed(2)}'
                            : 'Short by PHP ${(-change).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: change >= 0 ? c.primary : c.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: cash >= _total
                          ? () {
                              Navigator.pop(context);
                              _showMessage('Payment successful');
                              setState(() => _items = <CartItem>[]);
                            }
                          : null,
                      child: const Text('Confirm Payment'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _line(String label, double value, AppColors c, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          'PHP ${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: bold ? c.primary : c.text,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
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
              const Icon(Icons.qr_code_scanner_rounded, size: 28),
              const SizedBox(width: 8),
              Text(
                'Barcode Scanner',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_items.isNotEmpty)
                Chip(label: Text('${_items.length} item(s)')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Scan products to sell',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _scanning ? c.primary : c.border),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  height: 170,
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.border),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 42,
                              color: c.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to scan',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ScanCorner(
                        alignment: Alignment.topLeft,
                        color: c.border,
                      ),
                      _ScanCorner(
                        alignment: Alignment.topRight,
                        color: c.border,
                      ),
                      _ScanCorner(
                        alignment: Alignment.bottomLeft,
                        color: c.border,
                      ),
                      _ScanCorner(
                        alignment: Alignment.bottomRight,
                        color: c.border,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _scanning ? _scanProgress / 100 : 0,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          hintText: 'Enter barcode manually',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        _addBarcode(_barcodeController.text);
                        _barcodeController.clear();
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _simulateScan,
                    icon: const Icon(Icons.qr_code_2_outlined),
                    label: const Text('Simulate Scan'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Subtotal'),
                      Text('PHP ${_subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('VAT'),
                      Text('PHP ${_vat.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'PHP ${_total.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: c.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openPayment,
                      child: const Text('Checkout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ..._items.map((CartItem item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.name),
                subtitle: Text(
                  '${item.category} | PHP ${item.price.toStringAsFixed(2)} x ${item.qty}',
                ),
                trailing: Wrap(
                  spacing: 6,
                  children: <Widget>[
                    IconButton(
                      onPressed: () => _updateQty(item, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => _updateQty(item, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => _removeItem(item),
                      icon: Icon(Icons.delete_outline, color: c.error),
                    ),
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

class _ScanCorner extends StatelessWidget {
  const _ScanCorner({required this.alignment, required this.color});

  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool top = alignment.y < 0;
    final bool left = alignment.x < 0;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: top ? BorderSide(color: color, width: 2) : BorderSide.none,
                bottom: !top
                    ? BorderSide(color: color, width: 2)
                    : BorderSide.none,
                left: left
                    ? BorderSide(color: color, width: 2)
                    : BorderSide.none,
                right: !left
                    ? BorderSide(color: color, width: 2)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
