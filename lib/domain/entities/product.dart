/// Domain entity – products table.
class Product {
  const Product({
    required this.productId,
    this.categoryId,
    this.barcode,
    required this.name,
    required this.unitPrice,
    required this.costPrice,
    required this.stockQty,
    required this.threshold,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.suggestedPrice,
  });

  final String productId;
  final String? categoryId;
  final String? barcode;
  final String name;
  final double unitPrice;
  final double costPrice;
  final int stockQty;
  final int threshold;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // joined field (not in DB)
  final String? categoryName;
  // from price_suggestions (not in DB column)
  final double? suggestedPrice;

  bool get isLowStock => stockQty <= threshold;

  Product copyWith({
    String? categoryId,
    String? barcode,
    String? name,
    double? unitPrice,
    double? costPrice,
    int? stockQty,
    int? threshold,
    bool? isActive,
    String? categoryName,
    double? suggestedPrice,
  }) =>
      Product(
        productId: productId,
        categoryId: categoryId ?? this.categoryId,
        barcode: barcode ?? this.barcode,
        name: name ?? this.name,
        unitPrice: unitPrice ?? this.unitPrice,
        costPrice: costPrice ?? this.costPrice,
        stockQty: stockQty ?? this.stockQty,
        threshold: threshold ?? this.threshold,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        categoryName: categoryName ?? this.categoryName,
        suggestedPrice: suggestedPrice ?? this.suggestedPrice,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'product_id': productId,
        'category_id': categoryId,
        'barcode': barcode,
        'name': name,
        'unit_price': unitPrice,
        'cost_price': costPrice,
        'stock_qty': stockQty,
        'threshold': threshold,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        productId: m['product_id'] as String,
        categoryId: m['category_id'] as String?,
        barcode: m['barcode'] as String?,
        name: m['name'] as String,
        unitPrice: (m['unit_price'] as num).toDouble(),
        costPrice: (m['cost_price'] as num? ?? 0).toDouble(),
        stockQty: (m['stock_qty'] as int? ?? 0),
        threshold: (m['threshold'] as int? ?? 0),
        isActive: (m['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        categoryName: m['category_name'] as String?,
        suggestedPrice: m['suggested_price'] != null
            ? (m['suggested_price'] as num).toDouble()
            : null,
      );
}
