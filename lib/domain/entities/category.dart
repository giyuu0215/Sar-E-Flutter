/// Domain entity – categories table.
class Category {
  const Category({
    required this.categoryId,
    required this.name,
    this.description,
    required this.createdAt,
  });

  final String categoryId;
  final String name;
  final String? description;
  final DateTime createdAt;

  Category copyWith({String? name, String? description}) => Category(
        categoryId: categoryId,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'category_id': categoryId,
        'name': name,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        categoryId: m['category_id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
