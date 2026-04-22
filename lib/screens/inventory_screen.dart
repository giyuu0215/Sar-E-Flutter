import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.suggestedPrice,
    required this.stock,
    required this.minStock,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final double suggestedPrice;
  final int stock;
  final int minStock;

  Product copyWith({
    String? name,
    String? category,
    double? price,
    double? suggestedPrice,
    int? stock,
    int? minStock,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      suggestedPrice: suggestedPrice ?? this.suggestedPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final List<Product> _products = <Product>[
    const Product(
      id: '1',
      name: 'Lucky Me Pancit Canton',
      category: 'Noodles',
      price: 11,
      suggestedPrice: 12,
      stock: 180,
      minStock: 40,
    ),
    const Product(
      id: '2',
      name: 'Bear Brand Milk Powder',
      category: 'Dairy',
      price: 13.5,
      suggestedPrice: 14,
      stock: 14,
      minStock: 20,
    ),
    const Product(
      id: '3',
      name: 'Oishi Prawn Crackers',
      category: 'Snacks',
      price: 15,
      suggestedPrice: 15,
      stock: 310,
      minStock: 60,
    ),
    const Product(
      id: '4',
      name: 'Century Tuna Regular',
      category: 'Canned Goods',
      price: 28.5,
      suggestedPrice: 30,
      stock: 95,
      minStock: 25,
    ),
  ];

  final List<String> _categories = <String>[
    'All',
    'Noodles',
    'Dairy',
    'Snacks',
    'Canned Goods',
  ];
  String _activeCategory = 'All';
  String _search = '';

  List<Product> get _filtered {
    return _products.where((Product p) {
      final bool matchSearch = p.name.toLowerCase().contains(
        _search.toLowerCase(),
      );
      final bool matchCat =
          _activeCategory == 'All' || p.category == _activeCategory;
      return matchSearch && matchCat;
    }).toList();
  }

  int get _lowStock =>
      _products.where((Product p) => p.stock <= p.minStock).length;
  double get _value => _products.fold<double>(
    0,
    (double s, Product p) => s + (p.price * p.stock),
  );

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

  void _acceptAllSuggestedPrices() {
    setState(() {
      for (int i = 0; i < _products.length; i++) {
        _products[i] = _products[i].copyWith(
          price: _products[i].suggestedPrice,
        );
      }
    });
    _showMessage('All suggested prices accepted');
  }

  void _openAddDialog() {
    final TextEditingController name = TextEditingController();
    final TextEditingController price = TextEditingController();
    final TextEditingController stock = TextEditingController();
    String category = _categories.length > 1 ? _categories[1] : 'Snacks';

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock'),
                ),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (_, StateSetter setS) {
                    return DropdownButtonFormField<String>(
                      initialValue: category,
                      items: _categories
                          .where((String c) => c != 'All')
                          .map(
                            (String c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) =>
                          setS(() => category = value ?? category),
                      decoration: const InputDecoration(labelText: 'Category'),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final double parsedPrice = double.tryParse(price.text) ?? 0;
                final int parsedStock = int.tryParse(stock.text) ?? 0;
                if (name.text.trim().isEmpty ||
                    parsedPrice <= 0 ||
                    parsedStock < 0) {
                  _showMessage('Please fill required fields');
                  return;
                }
                setState(() {
                  _products.insert(
                    0,
                    Product(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: name.text.trim(),
                      category: category,
                      price: parsedPrice,
                      suggestedPrice: parsedPrice,
                      stock: parsedStock,
                      minStock: 10,
                    ),
                  );
                });
                Navigator.pop(context);
                _showMessage('Product added');
              },
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.inventory_2_outlined),
              const SizedBox(width: 8),
              Text('Inventory', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _openAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
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
              _StatCard(
                label: 'Products',
                value: '${_products.length}',
                color: c.primary,
              ),
              const SizedBox(width: 8),
              _StatCard(
                label: 'Low Stock',
                value: '$_lowStock',
                color: c.warning,
              ),
              const SizedBox(width: 8),
              _StatCard(
                label: 'Value',
                value: 'PHP ${(_value / 1000).toStringAsFixed(1)}k',
                color: c.info,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.sell_outlined, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Suggested pricing available based on trend.'),
                ),
                TextButton(
                  onPressed: _acceptAllSuggestedPrices,
                  child: const Text('Accept All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (String value) => setState(() => _search = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search product...',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (BuildContext context, int i) {
                final String cat = _categories[i];
                final bool selected = _activeCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _activeCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ..._filtered.map((Product p) {
            final bool low = p.stock <= p.minStock;
            final bool belowSuggested = p.price < p.suggestedPrice;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: low
                      ? c.warning.withValues(alpha: 0.2)
                      : c.primary.withValues(alpha: 0.18),
                  child: Icon(
                    low ? Icons.warning_amber_rounded : Icons.inventory,
                    color: low ? c.warning : c.primary,
                  ),
                ),
                title: Text(p.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 2),
                    Text('${p.category} | Stock: ${p.stock}'),
                    Text(
                      'Price: PHP ${p.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (belowSuggested)
                      Text(
                        'Suggested: PHP ${p.suggestedPrice.toStringAsFixed(2)}',
                        style: TextStyle(color: c.warning, fontSize: 12),
                      ),
                  ],
                ),
                trailing: belowSuggested
                    ? TextButton(
                        onPressed: () {
                          setState(() {
                            final int idx = _products.indexWhere(
                              (Product x) => x.id == p.id,
                            );
                            _products[idx] = _products[idx].copyWith(
                              price: _products[idx].suggestedPrice,
                            );
                          });
                          _showMessage('Suggested price accepted');
                        },
                        child: const Text('Accept'),
                      )
                    : null,
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
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
