import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

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

  /// Shows a blocking dialog when quantity exceeds available stock.
  void _showStockWarning(String productName, int available) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: appColors(ctx).warning, size: 36),
        title: const Text('Not enough stock'),
        content: Text(
          '"$productName" only has $available available in stock.\n\n'
          'Please adjust the quantity or restock the product first.',
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Asks the user to confirm before removing an item from the cart.
  Future<void> _confirmRemoveItem(String productName, String productId) async {
    if (!mounted) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: Icon(Icons.remove_shopping_cart_outlined,
            color: appColors(ctx).warning, size: 36),
        title: const Text('Remove Item?'),
        content: Text(
          'Are you sure you want to remove "$productName" from the cart?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: appColors(ctx).error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).removeItem(productId);
    }
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
    // Load all configured QR entries (decoded data strings)
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Static defaults
    final List<String> staticKeys = <String>[
      'qr_gcash',
      'qr_maya',
      'qr_maribank'
    ];
    final Map<String, String> staticLabels = <String, String>{
      'qr_gcash': 'GCash',
      'qr_maya': 'Maya',
      'qr_maribank': 'MariBank',
    };
    // Dynamic extras
    final int extraCount = prefs.getInt('qr_extra_count') ?? 0;

    final List<Map<String, String?>> qrEntries = <Map<String, String?>>[
      for (final String k in staticKeys)
        <String, String?>{
          'key': k,
          'label': prefs.getString('${k}_label') ?? staticLabels[k],
          'data': prefs.getString('${k}_qrdata'),
        },
      for (int i = 0; i < extraCount; i++)
        <String, String?>{
          'key': 'qr_extra_$i',
          'label': prefs.getString('qr_extra_${i}_label') ?? 'Other ${i + 1}',
          'data': prefs.getString('qr_extra_${i}_qrdata'),
        },
    ].where((Map<String, String?> e) {
      final String? d = e['data'];
      return d != null && d.isNotEmpty;
    }).toList();

    String? selectedQrKey =
        qrEntries.isNotEmpty ? qrEntries.first['key'] : null;

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
                      if (qrEntries.isEmpty) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          child: Column(children: <Widget>[
                            Icon(Icons.qr_code_2,
                                size: 48, color: c.textTertiary),
                            const SizedBox(height: 8),
                            Text('No payment QR set up.',
                                style: TextStyle(color: c.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              'Go to Profile → Payment QR Codes to upload.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: c.textTertiary, fontSize: 12),
                            ),
                          ]),
                        ),
                      ] else ...<Widget>[
                        // QR selector chips
                        if (qrEntries.length > 1)
                          Wrap(
                            spacing: 8,
                            children: qrEntries.map((Map<String, String?> e) {
                              final bool sel = selectedQrKey == e['key'];
                              return ChoiceChip(
                                label: Text(e['label'] ?? ''),
                                selected: sel,
                                onSelected: (_) =>
                                    setS(() => selectedQrKey = e['key']),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        // Display selected regenerated QR
                        Builder(builder: (BuildContext _) {
                          final Map<String, String?>? entry = qrEntries
                              .cast<Map<String, String?>?>()
                              .firstWhere(
                                (Map<String, String?>? e) =>
                                    e!['key'] == selectedQrKey,
                                orElse: () => qrEntries.first,
                              );
                          final String? rawData = entry?['data'];
                          if (rawData == null) return const SizedBox.shrink();

                          // If it's a fallback image path
                          if (rawData.startsWith('IMAGE:')) {
                            final String imgPath = rawData.substring(6);
                            return Center(
                              child: Column(children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(imgPath),
                                      height: 200, fit: BoxFit.contain),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Customer scans & enters ₱${total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: c.textSecondary, fontSize: 13),
                                ),
                              ]),
                            );
                          }

                          // Regenerated brand-colored QR
                          return Center(
                            child: Column(children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: c.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: c.primary.withValues(alpha: 0.25)),
                                ),
                                child: SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: QrImageView(
                                    data: rawData,
                                    version: QrVersions.auto,
                                    size: 200,
                                    backgroundColor: Colors.transparent,
                                    eyeStyle: QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: c.primaryDark,
                                    ),
                                    dataModuleStyle: QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: c.primaryDark,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Customer scans & enters ₱${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: c.textSecondary, fontSize: 13),
                              ),
                            ]),
                          );
                        }),
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
                      final double t = double.tryParse(cashCtrl.text) ?? 0;
                      if (t < total) {
                        setS(() => cashError =
                            'Enter at least ₱${total.toStringAsFixed(2)}');
                        return; // keep dialog open
                      }
                      ref.read(cartProvider.notifier).setTenderedCash(t);
                    }

                    ref.read(cartProvider.notifier).setPaymentMethod(method);
                    // When ewallet is selected, store the specific provider label
                    if (method == 'ewallet' && selectedQrKey != null) {
                      final Map<String, String?>? entry = qrEntries
                          .cast<Map<String, String?>?>()
                          .firstWhere(
                            (Map<String, String?>? e) =>
                                e!['key'] == selectedQrKey,
                            orElse: () => null,
                          );
                      if (entry != null && entry['label'] != null) {
                        ref.read(cartProvider.notifier).setPaymentMethod(
                            'ewallet:${entry['label']}');
                      }
                    }
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

  Future<void> _showReceiptDialog(Receipt? receipt) async {
    if (receipt == null || !mounted) return;

    Map<String, dynamic> data = <String, dynamic>{};
    List<dynamic> items = <dynamic>[];
    try {
      // New format: human-readable text then ##JSON##<jsonstring>
      // Old format: raw JSON (backwards compat)
      final String payload = receipt.qrPayload;
      final int sepIdx = payload.indexOf('##JSON##');
      final String jsonStr =
          sepIdx >= 0 ? payload.substring(sepIdx + 8) : payload;
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
      items = (data['items'] as List<dynamic>?) ?? <dynamic>[];
    } catch (_) {}

    final String payMethod =
        (data['payment_method'] as String? ?? 'cash').toUpperCase();
    final double total = (data['total'] as num?)?.toDouble() ?? 0;
    final double changeDue = ref.read(cartProvider).changeDue;
    final String dateStr = '${receipt.timestamp.year}-'
        '${receipt.timestamp.month.toString().padLeft(2, '0')}-'
        '${receipt.timestamp.day.toString().padLeft(2, '0')} '
        '${receipt.timestamp.hour.toString().padLeft(2, '0')}:'
        '${receipt.timestamp.minute.toString().padLeft(2, '0')}';

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final AppColors c = appColors(ctx);
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ── Header ──
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: <Widget>[
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 36),
                      const SizedBox(height: 6),
                      Text(
                        receipt.storeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Receipt #${receipt.receiptId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        ),
                    ],
                  ),
                ),

                // ── Items list ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ...items.map((dynamic it) {
                          final Map<String, dynamic> item =
                              it as Map<String, dynamic>;
                          final String name = item['name'] as String? ?? '-';
                          final int qty = (item['qty'] as num?)?.toInt() ?? 1;
                          final double price =
                              (item['price'] as num?)?.toDouble() ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '$qty× $name',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '₱${(qty * price).toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: c.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }),
                        Divider(color: c.border, height: 20),

                        // ── Totals ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Payment',
                                style: TextStyle(fontSize: 12)),
                            Text(payMethod,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('TOTAL',
                                style: TextStyle(
                                    color: c.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Text(
                              '₱${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20),
                            ),
                          ],
                        ),
                        if (payMethod == 'CASH' && changeDue > 0) ...<Widget>[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text('Change',
                                  style:
                                      TextStyle(color: c.info, fontSize: 13)),
                              Text(
                                '₱${changeDue.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: c.info,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),

                        // ── Receipt QR (colored) ──
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: c.primary.withValues(alpha: 0.25)),
                            ),
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: QrImageView(
                                data: receipt.qrPayload,
                                version: QrVersions.auto,
                                size: 140,
                                backgroundColor: Colors.transparent,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: c.primaryDark,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: c.primaryDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Scan to verify receipt',
                            style:
                                TextStyle(color: c.textTertiary, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Actions ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _shareReceiptPdf(receipt, items, dateStr),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share PDF'),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20))),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Done'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareReceiptPdf(
      Receipt receipt, List<dynamic> items, String dateStr) async {
    final pw.Document doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Center(
                child: pw.Text('SAR-E RECEIPT',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text(receipt.storeName,
                    style: const pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                  'Receipt #: ${receipt.receiptId.substring(0, 8).toUpperCase()}'),
              pw.Text('Date: $dateStr'),
              pw.Divider(),
              ...items.map((dynamic it) {
                final Map<String, dynamic> item = it as Map<String, dynamic>;
                final String name = item['name'] as String? ?? '-';
                final int qty = (item['qty'] as num?)?.toInt() ?? 1;
                final double price = (item['price'] as num?)?.toDouble() ?? 0;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: <pw.Widget>[
                      pw.Expanded(child: pw.Text('$qty x $name')),
                      pw.Text('PHP ${(qty * price).toStringAsFixed(2)}'),
                    ],
                  ),
                );
              }),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Text('TOTAL',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    'PHP ${items.fold<double>(0, (double sum, dynamic it) => sum + ((it['qty'] as num).toDouble() * (it['price'] as num).toDouble())).toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Thank you!',
                    style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF to file and open
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String fileName = 'receipt_${receipt.receiptId.substring(0, 8)}.pdf';
      final String filePath = '${dir.path}/$fileName';
      final File file = File(filePath);
      await file.writeAsBytes(await doc.save());
      await OpenFile.open(filePath);
    } catch (e) {
      _showMessage('Could not save receipt PDF: $e');
    }
  }

  // Scan barcode → find product by barcode → add to cart directly
  Future<void> _scanAndAdd() async {
    final String? barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerView()),
    );
    if (barcode == null || barcode.isEmpty || !mounted) return;
    final CartNotifier notifier = ref.read(cartProvider.notifier);
    await notifier.search(barcode);
    final List<Product> results = ref.read(cartProvider).searchResults;
    if (results.isEmpty) {
      _showMessage('No product found for barcode: $barcode');
    } else {
      final Product p = results.first;
      if (p.stockQty <= 0) {
        _showStockWarning(p.name, 0);
      } else {
        final String? warn = notifier.addProduct(p);
        if (warn != null) {
          _showStockWarning(p.name, p.stockQty);
        } else {
          _showMessage('Added: ${p.name}');
        }
      }
    }
    notifier.search(''); // clear search results
    setState(() {
      _showSearch = false;
      _searchCtrl.clear();
    });
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
                  Text('POS', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  // Enlarged always-visible scan button
                  ElevatedButton.icon(
                    onPressed: _scanAndAdd,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('SCAN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _showSearch = !_showSearch),
                    icon: Icon(_showSearch ? Icons.close : Icons.search,
                        size: 18),
                    tooltip: 'Search products',
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
                                    final String? warn = ref
                                        .read(cartProvider.notifier)
                                        .addProduct(p);
                                    if (warn != null) _showMessage(warn);
                                    setState(() {
                                      _showSearch = false;
                                      _searchCtrl.clear();
                                    });
                                    ref.read(cartProvider.notifier).search('');
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // Cart items — empty state shows big SCAN button
                if (cart.isEmpty && !_showSearch)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(children: <Widget>[
                      // Primary CTA: big scan button
                      InkWell(
                        onTap: _scanAndAdd,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                c.primary,
                                c.primary.withValues(alpha: 0.75),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: c.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(children: <Widget>[
                            const Icon(Icons.qr_code_scanner,
                                size: 64, color: Colors.white),
                            const SizedBox(height: 12),
                            const Text(
                              'Tap to Scan Barcode',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Point camera at product barcode',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'or use 🔍 Search above',
                        style: TextStyle(color: c.textTertiary, fontSize: 12),
                      ),
                    ]),
                  )
                else if (cart.isEmpty) // search open, nothing in cart
                  const SizedBox(height: 8)
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(item.product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  '₱${item.product.unitPrice.toStringAsFixed(2)} each',
                                  style: TextStyle(
                                      color: c.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Row(children: <Widget>[
                            IconButton(
                              onPressed: () {
                                // If qty is already 1, confirm before removing
                                if (item.qty <= 1) {
                                  _confirmRemoveItem(
                                      item.product.name, item.product.productId);
                                  return;
                                }
                                final String? warn = ref
                                    .read(cartProvider.notifier)
                                    .changeQty(item.product.productId, -1);
                                if (warn != null) _showMessage(warn);
                              },
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 20,
                            ),
                            // Tap qty number to edit manually
                            GestureDetector(
                              onTap: () async {
                                final TextEditingController qtyCtrl =
                                    TextEditingController(text: '${item.qty}');
                                final String? result = await showDialog<String>(
                                  context: context,
                                  builder: (BuildContext dCtx) => AlertDialog(
                                    title: Text(item.product.name),
                                    content: TextField(
                                      controller: qtyCtrl,
                                      autofocus: true,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: <TextInputFormatter>[
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                          labelText: 'Quantity'),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                          onPressed: () => Navigator.pop(dCtx),
                                          child: const Text('Cancel')),
                                      ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, qtyCtrl.text),
                                          child: const Text('Set')),
                                    ],
                                  ),
                                );
                                if (result != null) {
                                  final int? newQty = int.tryParse(result);
                                  if (newQty != null && newQty > 0) {
                                    if (newQty > item.product.stockQty) {
                                      _showStockWarning(
                                        item.product.name,
                                        item.product.stockQty,
                                      );
                                    } else {
                                      final int delta = newQty - item.qty;
                                      final String? warn = ref
                                          .read(cartProvider.notifier)
                                          .changeQty(
                                              item.product.productId, delta);
                                      if (warn != null) {
                                        _showStockWarning(
                                          item.product.name,
                                          item.product.stockQty,
                                        );
                                      }
                                    }
                                  } else if (newQty == 0) {
                                    _confirmRemoveItem(
                                        item.product.name,
                                        item.product.productId);
                                  } else if (newQty != null && newQty < 0) {
                                    showDialog<void>(
                                      context: context,
                                      builder: (BuildContext dCtx) => AlertDialog(
                                        icon: Icon(Icons.error_outline,
                                            color: appColors(dCtx).error, size: 36),
                                        title: const Text('Invalid Quantity'),
                                        content: const Text(
                                            'Quantity cannot be negative.'),
                                        actions: <Widget>[
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(dCtx),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: c.surfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: c.border),
                                ),
                                child: Text(
                                  '${item.qty}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                final String? warn = ref
                                    .read(cartProvider.notifier)
                                    .changeQty(item.product.productId, 1);
                                if (warn != null) {
                                  _showStockWarning(
                                    item.product.name,
                                    item.product.stockQty,
                                  );
                                }
                              },
                              icon: const Icon(Icons.add_circle_outline),
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
                    style: TextStyle(color: c.textSecondary, fontSize: 11)),
                Text(
                  '₱${cart.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cart.items.length} item${cart.items.length == 1 ? '' : 's'}',
                  style: TextStyle(color: c.textSecondary, fontSize: 10),
                ),
              ],
            ),
            const Spacer(),
            // Clear
            if (!cart.isEmpty)
              TextButton(
                onPressed: ref.read(cartProvider.notifier).clearCart,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text('Clear',
                    style: TextStyle(color: c.error, fontSize: 13)),
              ),
            const SizedBox(width: 4),
            // Checkout
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: cart.isProcessing ? null : _showCheckoutDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: cart.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.shopping_cart_checkout, size: 18),
                          SizedBox(width: 8),
                          Text('Checkout',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
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
          color: selected ? c.primary.withValues(alpha: 0.15) : c.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? c.primary : c.border, width: selected ? 2 : 1),
        ),
        child: Column(children: <Widget>[
          Icon(icon, color: selected ? c.primary : c.textSecondary),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected ? c.primary : c.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ]),
      ),
    );
  }
}
