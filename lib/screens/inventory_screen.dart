import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/inventory_provider.dart';
import '../domain/entities/category.dart';
import '../domain/entities/product.dart';
import '../theme/app_theme.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<InventoryState> asyncState =
        ref.watch(inventoryProvider);

    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('Error: $e')),
      data: (InventoryState state) =>
          _InventoryContent(state: state),
    );
  }
}

class _InventoryContent extends ConsumerStatefulWidget {
  const _InventoryContent({required this.state});

  final InventoryState state;

  @override
  ConsumerState<_InventoryContent> createState() =>
      _InventoryContentState();
}

class _InventoryContentState extends ConsumerState<_InventoryContent> {
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openAddProductDialog() async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController priceCtrl = TextEditingController();
    final TextEditingController costCtrl = TextEditingController();
    final TextEditingController stockCtrl = TextEditingController();
    final TextEditingController thresholdCtrl =
        TextEditingController(text: '5');
    String? selectedCategoryId;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setS) {
            return AlertDialog(
              title: const Text('Add Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                        controller: nameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Product Name *')),
                    const SizedBox(height: 10),
                    Row(children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Sell Price *'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Cost Price'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Stock Qty *'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: thresholdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Low-stock Threshold'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      hint: const Text('Category (optional)'),
                      items: widget.state.categories
                          .map((Category cat) => DropdownMenuItem<String>(
                                value: cat.categoryId,
                                child: Text(cat.name),
                              ))
                          .toList(),
                      onChanged: (String? v) =>
                          setS(() => selectedCategoryId = v),
                      decoration:
                          const InputDecoration(labelText: 'Category'),
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
                    final double price =
                        double.tryParse(priceCtrl.text) ?? 0;
                    final double cost =
                        double.tryParse(costCtrl.text) ?? 0;
                    final int stock = int.tryParse(stockCtrl.text) ?? 0;
                    final int threshold =
                        int.tryParse(thresholdCtrl.text) ?? 5;
                    if (nameCtrl.text.trim().isEmpty || price <= 0) {
                      return;
                    }
                    Navigator.pop(ctx);
                    await ref.read(inventoryProvider.notifier).addProduct(
                          name: nameCtrl.text.trim(),
                          unitPrice: price,
                          costPrice: cost,
                          stockQty: stock,
                          threshold: threshold,
                          categoryId: selectedCategoryId,
                        );
                    _showMessage('Product added');
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

  Future<void> _openEditDialog(Product product) async {
    final TextEditingController priceCtrl =
        TextEditingController(text: product.unitPrice.toString());
    final TextEditingController costCtrl =
        TextEditingController(text: product.costPrice.toString());
    final TextEditingController stockCtrl =
        TextEditingController(text: product.stockQty.toString());
    final TextEditingController thresholdCtrl =
        TextEditingController(text: product.threshold.toString());
    String? selectedCategoryId = product.categoryId;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (_, StateSetter setS) {
            return AlertDialog(
              title: Text('Edit – ${product.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(children: <Widget>[
                      Expanded(
                        child: TextField(
                            controller: priceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Sell Price')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                            controller: costCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Cost Price')),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: <Widget>[
                      Expanded(
                        child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Stock Qty')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                            controller: thresholdCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Low-stock Threshold')),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      hint: const Text('Category'),
                      items: widget.state.categories
                          .map((Category cat) => DropdownMenuItem<String>(
                                value: cat.categoryId,
                                child: Text(cat.name),
                              ))
                          .toList(),
                      onChanged: (String? v) =>
                          setS(() => selectedCategoryId = v),
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
                    Navigator.pop(ctx);
                    await ref.read(inventoryProvider.notifier).updateProduct(
                          product.copyWith(
                            unitPrice:
                                double.tryParse(priceCtrl.text) ??
                                    product.unitPrice,
                            costPrice:
                                double.tryParse(costCtrl.text) ??
                                    product.costPrice,
                            stockQty:
                                int.tryParse(stockCtrl.text) ??
                                    product.stockQty,
                            threshold:
                                int.tryParse(thresholdCtrl.text) ??
                                    product.threshold,
                            categoryId: selectedCategoryId,
                          ),
                        );
                    _showMessage('Product updated');
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: appColors(ctx).primary,
                      foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openAddCategoryDialog() async {
    final TextEditingController nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('New Category'),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Category Name'),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await ref
                    .read(inventoryProvider.notifier)
                    .addCategory(nameCtrl.text.trim());
                _showMessage('Category added');
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
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final InventoryState state = widget.state;
    final List<Product> filtered = state.filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row
          Row(
            children: <Widget>[
              const Icon(Icons.inventory_2_outlined),
              const SizedBox(width: 8),
              Text('Inventory',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                onPressed: _openAddCategoryDialog,
                icon: const Icon(Icons.label_outline),
                tooltip: 'Add Category',
              ),
              ElevatedButton.icon(
                onPressed: _openAddProductDialog,
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

          // Stats
          Row(
            children: <Widget>[
              _StatCard(
                  label: 'Products',
                  value: '${state.products.length}',
                  color: c.primary),
              const SizedBox(width: 8),
              _StatCard(
                  label: 'Low Stock',
                  value: '${state.lowStockCount}',
                  color: c.warning),
              const SizedBox(width: 8),
              _StatCard(
                label: 'Value',
                value: state.totalValue >= 1000
                    ? 'PHP ${(state.totalValue / 1000).toStringAsFixed(1)}k'
                    : 'PHP ${state.totalValue.toStringAsFixed(0)}',
                color: c.info,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Low-stock banner
          if (state.lowStockCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: c.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded,
                      color: c.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${state.lowStockCount} product${state.lowStockCount == 1 ? '' : 's'} below restock threshold',
                      style:
                          TextStyle(color: c.warning, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (state.lowStockCount > 0) const SizedBox(height: 10),

          // Search + category filter
          TextField(
            onChanged: (String v) =>
                ref.read(inventoryProvider.notifier).setSearch(v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search product...',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                _CategoryChip(
                  label: 'All',
                  selected: state.selectedCategory == null,
                  onTap: () => ref
                      .read(inventoryProvider.notifier)
                      .setCategory(null),
                ),
                const SizedBox(width: 6),
                ...state.categories.map((Category cat) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _CategoryChip(
                        label: cat.name,
                        selected:
                            state.selectedCategory == cat.categoryId,
                        onTap: () => ref
                            .read(inventoryProvider.notifier)
                            .setCategory(cat.categoryId),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Product list
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text('No products found',
                    style: TextStyle(color: c.textSecondary)),
              ),
            )
          else
            ...filtered.map((Product p) {
              final bool low = p.isLowStock;
              final bool hasSuggestion =
                  p.suggestedPrice != null &&
                  p.suggestedPrice! > p.unitPrice;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: low
                        ? c.warning.withValues(alpha: 0.2)
                        : c.primary.withValues(alpha: 0.18),
                    child: Icon(
                      low
                          ? Icons.warning_amber_rounded
                          : Icons.inventory_2_outlined,
                      color: low ? c.warning : c.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(p.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 2),
                      Text(
                          '${p.categoryName ?? 'Uncategorized'} | Stock: ${p.stockQty}'),
                      Text(
                        'PHP ${p.unitPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: c.primary,
                            fontWeight: FontWeight.w700),
                      ),
                      if (hasSuggestion)
                        Text(
                          'Suggested: PHP ${p.suggestedPrice!.toStringAsFixed(2)}',
                          style:
                              TextStyle(color: c.warning, fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (hasSuggestion)
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(inventoryProvider.notifier)
                                .acceptSuggestedPrice(
                                    p.productId, p.suggestedPrice!);
                            _showMessage('Price updated');
                          },
                          child: const Text('Accept',
                              style: TextStyle(fontSize: 12)),
                        ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            size: 18, color: c.textSecondary),
                        onPressed: () => _openEditDialog(p),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: c.error),
                        onPressed: () async {
                          final bool? ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete product?'),
                              content: Text(
                                  'Remove "${p.name}" from inventory?'),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: c.error,
                                        foregroundColor: Colors.white),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await ref
                                .read(inventoryProvider.notifier)
                                .deleteProduct(p.productId);
                            _showMessage('Product removed');
                          }
                        },
                      ),
                    ],
                  ),
                  isThreeLine: true,
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
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: c.primary.withValues(alpha: 0.15),
      side: BorderSide(color: selected ? c.primary : c.border),
    );
  }
}
