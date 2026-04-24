import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../application/auth_provider.dart';
import '../application/inventory_provider.dart';
import '../application/listahan_provider.dart';
import '../domain/entities/credit_entry.dart';
import '../domain/entities/product.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = appColors(context);

    // Gather alerts from inventory (low stock) and listahan (overdue)
    final AsyncValue<InventoryState> invAsync = ref.watch(inventoryProvider);
    final AsyncValue<ListahanState> listAsync = ref.watch(listahanProvider);

    final List<Product> lowStock = invAsync.value?.products
            .where((Product p) => p.isLowStock)
            .toList() ??
        <Product>[];

    final List<CreditEntry> overdue = listAsync.value?.entries
            .where((CreditEntry e) => e.isOverdue)
            .toList() ??
        <CreditEntry>[];

    final int total = lowStock.length + overdue.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: total == 0
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.notifications_off_outlined,
                      size: 56, color: c.textTertiary),
                  const SizedBox(height: 12),
                  Text('No alerts',
                      style: TextStyle(color: c.textSecondary)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(14),
              children: <Widget>[
                if (lowStock.isNotEmpty) ...<Widget>[
                  _SectionHeader(
                      label: '🟡 Low Stock (${lowStock.length})',
                      color: c.warning),
                  const SizedBox(height: 6),
                  ...lowStock.map((Product p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                c.warning.withValues(alpha: 0.15),
                            child: Icon(Icons.warning_amber_rounded,
                                color: c.warning),
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                              'Stock: ${p.stockQty} (threshold: ${p.threshold})'),
                          trailing: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              // User can then manually navigate to Inventory tab
                            },
                            icon: const Icon(Icons.inventory_2, size: 16),
                            label: const Text('Restock'),
                            style: TextButton.styleFrom(
                              foregroundColor: c.warning,
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
                if (overdue.isNotEmpty) ...<Widget>[
                  _SectionHeader(
                      label: '🔴 Overdue Credits (${overdue.length})',
                      color: c.error),
                  const SizedBox(height: 6),
                  ...overdue.map((CreditEntry e) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                c.error.withValues(alpha: 0.15),
                            child: Icon(Icons.credit_card_off_outlined,
                                color: c.error),
                          ),
                          title: Text(e.customerName ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                  'PHP ${e.remaining.toStringAsFixed(2)} remaining'),
                              Text(
                                'Due: ${DateFormat('MMM d, y').format(e.dueDate)}',
                                style:
                                    TextStyle(color: c.error, fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            onPressed: () async {
                              // Re-using the SMS feature from listahan
                              final Uri smsLaunchUri = Uri(
                                scheme: 'sms',
                                path: '09123456789', // Would use e.customerPhone if we added it to customer table
                                queryParameters: <String, String>{
                                  'body':
                                      'Hi ${e.customerName}, this is a gentle reminder regarding your overdue credit of PHP ${e.remaining.toStringAsFixed(2)} at ${ref.read(authProvider).value?.user?.storeName ?? 'our store'}. Please settle it as soon as possible.',
                                },
                              );
                              
                              try {
                                // Ignore failure, just try to launch
                                // ignore: deprecated_member_use
                                launchUrl(smsLaunchUri);
                              } catch (_) {}
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Opening SMS app...')),
                              );
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.sms_outlined, color: c.error),
                            tooltip: 'Remind via SMS',
                          ),
                          isThreeLine: true,
                        ),
                      )),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
          color: color, fontWeight: FontWeight.w700, fontSize: 14),
    );
  }
}
