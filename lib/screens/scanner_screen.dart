import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../application/cart_provider.dart';
import '../domain/entities/product.dart';
import '../domain/entities/transaction.dart';
import '../theme/app_theme.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _cashCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showCheckoutDialog() async {
    final CartState cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      _showMessage('Cart is empty');
      return;
    }

    final TextEditingController cashCtrl = TextEditingController();
    final TextEditingController mobileCtrl = TextEditingController();
    String method = cart.paymentMethod;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final AppColors c = appColors(ctx);
        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setS) {
            final double total = cart.total;
            final double tendered = double.tryParse(cashCtrl.text) ?? 0;
            final double change = method == 'cash'
                ? (tendered - total).clamp(0, double.infinity)
                : 0;

            return AlertDialog(
              title: const Text('Checkout'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Total: PHP ${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Payment method toggle
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _PaymentChip(
                            label: 'Cash',
                            icon: Icons.payments_outlined,
                            selected: method == 'cash',
                            onTap: () => setS(() => method = 'cash'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PaymentChip(
                            label: 'E-Wallet',
                            icon: Icons.qr_code_outlined,
                            selected: method == 'ewallet',
                            onTap: () => setS(() => method = 'ewallet'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (method == 'cash') ...<Widget>[
                      TextField(
                        controller: cashCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Cash tendered (PHP)',
                          prefixText: '₱ ',
                        ),
                        onChanged: (_) => setS(() {}),
                      ),
                      if (tendered >= total) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Change: PHP ${change.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: c.info, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: mobileCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Customer mobile (optional)',
                        hintText: '09xxxxxxxxx',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final CartNotifier notifier =
                        ref.read(cartProvider.notifier);
                    notifier.setPaymentMethod(method);
                    if (method == 'cash') {
                      final double t = double.tryParse(cashCtrl.text) ?? 0;
                      notifier.setTenderedCash(t);
                    }
                    if (mobileCtrl.text.isNotEmpty) {
                      notifier.setCustomerMobile(mobileCtrl.text);
                    }
                    Navigator.pop(ctx);
                    final bool ok = await notifier.checkout();
                    if (ok && mounted) {
                      _showReceiptDialog(ref.read(cartProvider).lastReceipt);
                    } else if (mounted) {
                      _showMessage(
                          ref.read(cartProvider).error ?? 'Checkout failed');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors(ctx).primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReceiptDialog(Receipt? receipt) {
    if (receipt == null) return;
    final Map<String, dynamic> data =
        jsonDecode(receipt.qrPayload) as Map<String, dynamic>;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final AppColors c = appColors(ctx);
        return AlertDialog(
          title: Row(
            children: <Widget>[
              Icon(Icons.check_circle, color: c.info),
              const SizedBox(width: 8),
              const Text('Receipt'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // QR Code
              QrImageView(
                data: receipt.qrPayload,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'PHP ${(data['total'] as num).toStringAsFixed(2)}',
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              Text(
                'Receipt #${receipt.receiptId.substring(0, 8)}',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final CartState cart = ref.watch(cartProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              const Icon(Icons.point_of_sale_outlined),
              const SizedBox(width: 8),
              Text('POS', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () =>
                    setState(() => _showSearch = !_showSearch),
                icon: Icon(
                    _showSearch ? Icons.close : Icons.search,
                    size: 18),
                tooltip: 'Search products',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search
          if (_showSearch) ...<Widget>[
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search product by name...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (String v) =>
                  ref.read(cartProvider.notifier).search(v),
            ),
            const SizedBox(height: 8),
            // Search results
            if (cart.searchResults.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: cart.searchResults
                      .map((Product p) => ListTile(
                            title: Text(p.name),
                            subtitle: Text(
                                '${p.categoryName ?? 'Uncategorized'} | Stock: ${p.stockQty}'),
                            trailing: Text(
                              'PHP ${p.unitPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w700),
                            ),
                            onTap: () {
                              ref
                                  .read(cartProvider.notifier)
                                  .addProduct(p);
                              setState(() {
                                _showSearch = false;
                                _searchCtrl.clear();
                              });
                              ref
                                  .read(cartProvider.notifier)
                                  .search('');
                            },
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 12),
          ],

          // Cart summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Total',
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 12)),
                    Text(
                      'PHP ${cart.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                        '${cart.items.length} item${cart.items.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                if (!cart.isEmpty)
                  TextButton.icon(
                    onPressed: ref.read(cartProvider.notifier).clearCart,
                    icon: Icon(Icons.delete_outline, color: c.error),
                    label:
                        Text('Clear', style: TextStyle(color: c.error)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed:
                      cart.isProcessing ? null : _showCheckoutDialog,
                  icon: cart.isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Cart items
          if (cart.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: <Widget>[
                    Icon(Icons.shopping_cart_outlined,
                        size: 56, color: c.textTertiary),
                    const SizedBox(height: 12),
                    Text('Cart is empty',
                        style: TextStyle(color: c.textSecondary)),
                    const SizedBox(height: 6),
                    Text('Tap 🔍 to search and add products',
                        style: TextStyle(
                            color: c.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ...cart.items.map((CartItem item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(item.product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                              'PHP ${item.product.unitPrice.toStringAsFixed(2)} each',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Qty controls
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .changeQty(item.product.productId, -1),
                            icon: const Icon(Icons.remove_circle_outline),
                            iconSize: 20,
                          ),
                          Text('${item.qty}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          IconButton(
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .changeQty(item.product.productId, 1),
                            icon: const Icon(Icons.add_circle_outline),
                            iconSize: 20,
                          ),
                        ],
                      ),
                      // Subtotal
                      SizedBox(
                        width: 80,
                        child: Text(
                          'PHP ${item.subtotal.toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: c.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? c.primary.withValues(alpha: 0.15)
              : c.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: selected ? c.primary : c.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? c.primary : c.textSecondary,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
