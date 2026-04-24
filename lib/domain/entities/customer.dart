/// Domain entity – customers table.
class Customer {
  const Customer({
    required this.customerId,
    required this.name,
    this.mobileNumber,
    required this.creditBalance,
    required this.isActive,
    required this.createdAt,
  });

  final String customerId;
  final String name;
  final String? mobileNumber;
  final double creditBalance;
  final bool isActive;
  final DateTime createdAt;

  Customer copyWith({
    String? name,
    String? mobileNumber,
    double? creditBalance,
    bool? isActive,
  }) =>
      Customer(
        customerId: customerId,
        name: name ?? this.name,
        mobileNumber: mobileNumber ?? this.mobileNumber,
        creditBalance: creditBalance ?? this.creditBalance,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'customer_id': customerId,
        'name': name,
        'mobile_number': mobileNumber,
        'credit_balance': creditBalance,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        customerId: m['customer_id'] as String,
        name: m['name'] as String,
        mobileNumber: m['mobile_number'] as String?,
        creditBalance: (m['credit_balance'] as num? ?? 0).toDouble(),
        isActive: (m['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
