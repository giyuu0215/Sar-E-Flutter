/// Domain entity – credit_entries + repayment_records tables.
class CreditEntry {
  const CreditEntry({
    required this.entryId,
    required this.customerId,
    required this.items,
    required this.amount,
    required this.amountPaid,
    required this.dueDate,
    required this.status,
    required this.reminderCount,
    this.lastReminderAt,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
  });

  final String entryId;
  final String customerId;
  final String items; // JSON string list
  final double amount;
  final double amountPaid;
  final DateTime dueDate;
  final String status; // 'active' | 'overdue' | 'settled' | 'archived'
  final int reminderCount;
  final DateTime? lastReminderAt;
  final DateTime createdAt;

  // joined
  final String? customerName;
  final String? customerPhone;

  double get remaining => amount - amountPaid;
  bool get isOverdue =>
      dueDate.isBefore(DateTime.now()) && status != 'settled';
  bool get isSettled => status == 'settled';

  CreditEntry copyWith({
    double? amountPaid,
    String? status,
    int? reminderCount,
    DateTime? lastReminderAt,
  }) =>
      CreditEntry(
        entryId: entryId,
        customerId: customerId,
        items: items,
        amount: amount,
        amountPaid: amountPaid ?? this.amountPaid,
        dueDate: dueDate,
        status: status ?? this.status,
        reminderCount: reminderCount ?? this.reminderCount,
        lastReminderAt: lastReminderAt ?? this.lastReminderAt,
        createdAt: createdAt,
        customerName: customerName,
        customerPhone: customerPhone,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'entry_id': entryId,
        'customer_id': customerId,
        'items': items,
        'amount': amount,
        'amount_paid': amountPaid,
        'due_date': dueDate.toIso8601String(),
        'status': status,
        'reminder_count': reminderCount,
        'last_reminder_at': lastReminderAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory CreditEntry.fromMap(Map<String, dynamic> m) => CreditEntry(
        entryId: m['entry_id'] as String,
        customerId: m['customer_id'] as String,
        items: m['items'] as String,
        amount: (m['amount'] as num).toDouble(),
        amountPaid: (m['amount_paid'] as num? ?? 0).toDouble(),
        dueDate: DateTime.parse(m['due_date'] as String),
        status: m['status'] as String,
        reminderCount: (m['reminder_count'] as int? ?? 0),
        lastReminderAt: m['last_reminder_at'] != null
            ? DateTime.parse(m['last_reminder_at'] as String)
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
        customerName: m['customer_name'] as String?,
        customerPhone: m['customer_phone'] as String?,
      );
}

class RepaymentRecord {
  const RepaymentRecord({
    required this.repaymentId,
    required this.entryId,
    required this.amountPaid,
    required this.timestamp,
    this.notes,
  });

  final String repaymentId;
  final String entryId;
  final double amountPaid;
  final DateTime timestamp;
  final String? notes;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'repayment_id': repaymentId,
        'entry_id': entryId,
        'amount_paid': amountPaid,
        'timestamp': timestamp.toIso8601String(),
        'notes': notes,
      };

  factory RepaymentRecord.fromMap(Map<String, dynamic> m) => RepaymentRecord(
        repaymentId: m['repayment_id'] as String,
        entryId: m['entry_id'] as String,
        amountPaid: (m['amount_paid'] as num).toDouble(),
        timestamp: DateTime.parse(m['timestamp'] as String),
        notes: m['notes'] as String?,
      );
}
