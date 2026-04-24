import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/cart_provider.dart';
import '../domain/entities/product.dart';
import '../domain/entities/transaction.dart';
import '../theme/app_theme.dart';
import 'barcode_scanner_view.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ─── Checkout Dialog ─────────────────────────────────────────────────────

  Future<void> _showCheckoutDialog() async {
    final CartState cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      _showMessage('Cart is empty');
      return;
    }

    final TextEditingController cashCtrl = TextEditingController();
    final TextEditingController mobileCtrl = TextEditingController();
    String method = cart.paymentMethod;
    String? cashError;
    String? paymentQrPath;

    // Load uploaded QR path upfront
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    paymentQrPath = prefs.getString('paymentQrPath');

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final AppColors c = appColors(ctx);
        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setS) {
            final double total = ref.read(cartProvider).total;
            final double tendered = double.tryParse(cashCtrl.text) ?? 0;
            final double change =
                method == 'cash' ? (tendered - total).clamp(0, double.infinity) : 0;

            return AlertDialog(
              title: const Text('Checkout'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Total
                    Text(
                      'Total: ₱${total.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: c.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 22),
                    ),
                    const SizedBox(height: 16),

                    // Payment method toggle
                    Row(children: <Widget>[
                      Expanded(
                        child: _PaymentChip(
                          label: 'Cash',
                          icon: Icons.payments_outlined,
                          selected: method == 'cash',
                          onTap: () => setS(() {
                            method = 'cash';
                            cashError = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PaymentChip(
                          label: 'E-Wallet / QR',
                          icon: Icons.qr_code_outlined,
                          selected: method == 'ewallet',
                          onTap: () => setS(() => method = 'ewallet'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Cash fields
                    if (method == 'cash') ...<Widget>[
                      TextField(
                        controller: cashCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        decoration: InputDecoration(
                          labelText: 'Cash tendered (PHP)',
                          prefixText: '₱ ',
                          errorText: cashError,
                        ),
                        onChanged: (_) => setS(() => cashError = null),
                      ),
                      if (tendered >= total && tendered > 0) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Change: ₱${change.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: c.info, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],

                    // E-Wallet QR display
                    if (method == 'ewallet') ...<Widget>[
                      const SizedBox(height: 8),
                      if (paymentQrPath != null &&
                          File(paymentQrPath).existsSync()) ...<Widget>[
                        Center(
                          child: Column(children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(paymentQrPath),
                                height: 220,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Customer scans & enters ₱${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 13),
                            ),
                          ]),
                        ),
                      ] else ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: c.border,
                                style: BorderStyle.solid),
                          ),
                          child: Column(children: <Widget>[
                            Icon(Icons.qr_code_2,
                                size: 48, color: c.textTertiary),
                            const SizedBox(height: 8),
                            Text(
                              'No payment QR set up.',
                              style: TextStyle(color: c.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Go to Profile → Payment QR Code to upload your GCash / Maya QR.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: c.textTertiary, fontSize: 12),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 12),

                    // Customer mobile (optional)
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
                    // ── Validate BEFORE closing dialog ──
                    if (method == 'cash') {
                      final double t =
                          double.tryParse(cashCtrl.text) ?? 0;
                      if (t < total) {
                        setS(() => cashError =
                            'Enter at least ₱${total.toStringAsFixed(2)}');
                        return; // keep dialog open
                      }
                      ref.read(cartProvider.notifier).setTenderedCash(t);
                    }

                    ref.read(cartProvider.notifier).setPaymentMethod(method);
                    if (mobileCtrl.text.isNotEmpty) {
                      ref
                          .read(cartProvider.notifier)
                          .setCustomerMobile(mobileCtrl.text);
                    }

                    // Close dialog, then checkout
                    Navigator.pop(ctx);
                    final bool ok =
                        await ref.read(cartProvider.notifier).checkout();

                    if (ok && mounted) {
                      // Use postFrameCallback so receipt shows after
                      // the widget rebuilds from state change
                      final Receipt? receipt =
                          ref.read(cartProvider).lastReceipt;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _showReceiptDialog(receipt);
                      });
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

  // ─── Receipt Dialog ───────────────────────────────────────────────────────

  Future<void> _showReceiptDialog(Receipt? receipt) async {
    if (receipt == null || !mounted) return;

    Map<String, dynamic> data = <String, dynamic>{};
    try {
      data = jsonDecode(receipt.qrPayload) as Map<String, dynamic>;
    } catch (_) {}

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final AppColors c = appColors(ctx);
        return AlertDialog(
          title: Row(children: <Widget>[
            Icon(Icons.check_circle_rounded, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Text('Transaction Complete'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // QR of receipt data
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: receipt.qrPayload,
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '₱${(data['total'] as num?)?.toStringAsFixed(2) ?? receipt.qrPayload}',
                  style: TextStyle(
                      color: c.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 26),
                ),
                Text(
                  receipt.storeName,
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Receipt #${receipt.receiptId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(color: c.textTertiary, fontSize: 11),
                ),
                if (data['payment_method'] == 'cash' &&
                    data['total'] != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.payments_outlined,
                            color: c.info, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Cash · Change: ₱${ref.read(cartProvider).changeDue.toStringAsFixed(2)}',
                          style:
                              TextStyle(color: c.info, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.check),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final CartState cart = ref.watch(cartProvider);

    return Column(
      children: <Widget>[
        // ── Scrollable content ──────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header row
                Row(children: <Widget>[
                  const Icon(Icons.point_of_sale_outlined),
                  const SizedBox(width: 8),
                  Text('POS',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () =>
                        setState(() => _showSearch = !_showSearch),
                    icon: Icon(
                        _showSearch ? Icons.close : Icons.search,
                        size: 18),
                    tooltip: 'Search products',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () async {
                      final String? barcode =
                          await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                            builder: (_) => const BarcodeScannerView()),
                      );
                      if (barcode != null &&
                          barcode.isNotEmpty &&
                          mounted) {
                        setState(() {
                          _showSearch = true;
                          _searchCtrl.text = barcode;
                        });
                        ref.read(cartProvider.notifier).search(barcode);
                      }
                    },
                    icon:
                        const Icon(Icons.qr_code_scanner, size: 18),
                    tooltip: 'Scan Barcode',
                  ),
                ]),
                const SizedBox(height: 10),

                // Search bar + results
                if (_showSearch) ...<Widget>[
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search product by name or barcode...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (String v) =>
                        ref.read(cartProvider.notifier).search(v),
                  ),
                  const SizedBox(height: 8),
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
                                    '₱${p.unitPrice.toStringAsFixed(2)}',
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

                // Cart items
                if (cart.isEmpty)
                  Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 40),
                      child: Column(children: <Widget>[
                        Icon(Icons.shopping_cart_outlined,
                            size: 56, color: c.textTertiary),
                        const SizedBox(height: 12),
                        Text('Cart is empty',
                            style:
                                TextStyle(color: c.textSecondary)),
                        const SizedBox(height: 6),
                        Text('Tap 🔍 to search or scan a barcode',
                            style: TextStyle(
                                color: c.textTertiary, fontSize: 12)),
                      ]),
                    ),
                  )
                else
                  ...cart.items.map((CartItem item) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(item.product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  '₱${item.product.unitPrice.toStringAsFixed(2)} each',
                                  style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Row(children: <Widget>[
                            IconButton(
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .changeQty(
                                      item.product.productId, -1),
                              icon: const Icon(
                                  Icons.remove_circle_outline),
                              iconSize: 20,
                            ),
                            Text('${item.qty}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            IconButton(
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .changeQty(
                                      item.product.productId, 1),
                              icon: const Icon(
                                  Icons.add_circle_outline),
                              iconSize: 20,
                            ),
                          ]),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '₱${item.subtotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        // ── Sticky checkout bar ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(children: <Widget>[
            // Total info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Total',
                    style: TextStyle(
                        color: c.textSecondary, fontSize: 11)),
                Text(
                  '₱${cart.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                Text(
                  '${cart.items.length} item${cart.items.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
            const Spacer(),
            // Clear
            if (!cart.isEmpty)
              TextButton.icon(
                onPressed:
                    ref.read(cartProvider.notifier).clearCart,
                icon: Icon(Icons.delete_outline, color: c.error),
                label: Text('Clear',
                    style: TextStyle(color: c.error)),
              ),
            const SizedBox(width: 8),
            // Checkout
            ElevatedButton.icon(
              onPressed:
                  cart.isProcessing ? null : _showCheckoutDialog,
              icon: cart.isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.shopping_cart_checkout,
                      size: 18),
              label: const Text('Checkout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ─── Payment Chip ─────────────────────────────────────────────────────────────

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
              width: selected ? 2 : 1),
        ),
        child: Column(children: <Widget>[
          Icon(icon,
              color: selected ? c.primary : c.textSecondary),
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
        ]),
      ),
    );
  }
}
