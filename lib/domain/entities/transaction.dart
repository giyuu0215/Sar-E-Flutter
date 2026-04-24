/// Domain entities – transactions, transaction_line_items, payment_records, receipts.
class TransactionLineItem {
  const TransactionLineItem({
    required this.lineItemId,
    required this.transactionId,
    required this.productId,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
    this.productName,
  });

  final String lineItemId;
  final String transactionId;
  final String productId;
  final int qty;
  final double unitPrice;
  final double subtotal;
  final String? productName; // joined

  Map<String, dynamic> toMap() => <String, dynamic>{
        'line_item_id': lineItemId,
        'transaction_id': transactionId,
        'product_id': productId,
        'qty': qty,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      };

  factory TransactionLineItem.fromMap(Map<String, dynamic> m) =>
      TransactionLineItem(
        lineItemId: m['line_item_id'] as String,
        transactionId: m['transaction_id'] as String,
        productId: m['product_id'] as String,
        qty: m['qty'] as int,
        unitPrice: (m['unit_price'] as num).toDouble(),
        subtotal: (m['subtotal'] as num).toDouble(),
        productName: m['product_name'] as String?,
      );
}

class PaymentRecord {
  const PaymentRecord({
    required this.paymentId,
    required this.transactionId,
    required this.method,
    required this.amount,
    this.gatewayRef,
    this.confirmedAt,
    required this.status,
  });

  final String paymentId;
  final String transactionId;
  final String method; // 'cash' | 'ewallet'
  final double amount;
  final String? gatewayRef;
  final DateTime? confirmedAt;
  final String status; // 'pending' | 'confirmed' | 'failed'

  Map<String, dynamic> toMap() => <String, dynamic>{
        'payment_id': paymentId,
        'transaction_id': transactionId,
        'method': method,
        'amount': amount,
        'gateway_ref': gatewayRef,
        'confirmed_at': confirmedAt?.toIso8601String(),
        'status': status,
      };

  factory PaymentRecord.fromMap(Map<String, dynamic> m) => PaymentRecord(
        paymentId: m['payment_id'] as String,
        transactionId: m['transaction_id'] as String,
        method: m['method'] as String,
        amount: (m['amount'] as num).toDouble(),
        gatewayRef: m['gateway_ref'] as String?,
        confirmedAt: m['confirmed_at'] != null
            ? DateTime.parse(m['confirmed_at'] as String)
            : null,
        status: m['status'] as String,
      );
}

class Receipt {
  const Receipt({
    required this.receiptId,
    required this.transactionId,
    required this.storeName,
    required this.timestamp,
    required this.qrPayload,
    this.customerMobile,
    required this.deliveryStatus,
    this.smsDeliveredAt,
  });

  final String receiptId;
  final String transactionId;
  final String storeName;
  final DateTime timestamp;
  final String qrPayload;
  final String? customerMobile;
  final String deliveryStatus; // 'pending' | 'sent' | 'failed'
  final DateTime? smsDeliveredAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'receipt_id': receiptId,
        'transaction_id': transactionId,
        'store_name': storeName,
        'timestamp': timestamp.toIso8601String(),
        'qr_payload': qrPayload,
        'customer_mobile': customerMobile,
        'delivery_status': deliveryStatus,
        'sms_delivered_at': smsDeliveredAt?.toIso8601String(),
      };

  factory Receipt.fromMap(Map<String, dynamic> m) => Receipt(
        receiptId: m['receipt_id'] as String,
        transactionId: m['transaction_id'] as String,
        storeName: m['store_name'] as String,
        timestamp: DateTime.parse(m['timestamp'] as String),
        qrPayload: m['qr_payload'] as String,
        customerMobile: m['customer_mobile'] as String?,
        deliveryStatus: m['delivery_status'] as String,
        smsDeliveredAt: m['sms_delivered_at'] != null
            ? DateTime.parse(m['sms_delivered_at'] as String)
            : null,
      );
}

class Transaction {
  const Transaction({
    required this.transactionId,
    this.receiptId,
    required this.timestamp,
    required this.paymentMethod,
    required this.totalAmount,
    required this.changeDue,
    required this.status,
    required this.createdAt,
    this.syncedAt,
    this.lineItems = const <TransactionLineItem>[],
    this.payment,
    this.receipt,
  });

  final String transactionId;
  final String? receiptId;
  final DateTime timestamp;
  final String paymentMethod; // 'cash' | 'ewallet'
  final double totalAmount;
  final double changeDue;
  final String status; // 'pending' | 'completed' | 'cancelled' | 'held'
  final DateTime createdAt;
  final DateTime? syncedAt;

  // joined
  final List<TransactionLineItem> lineItems;
  final PaymentRecord? payment;
  final Receipt? receipt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'transaction_id': transactionId,
        'receipt_id': receiptId,
        'timestamp': timestamp.toIso8601String(),
        'payment_method': paymentMethod,
        'total_amount': totalAmount,
        'change_due': changeDue,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'synced_at': syncedAt?.toIso8601String(),
      };

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        transactionId: m['transaction_id'] as String,
        receiptId: m['receipt_id'] as String?,
        timestamp: DateTime.parse(m['timestamp'] as String),
        paymentMethod: m['payment_method'] as String,
        totalAmount: (m['total_amount'] as num).toDouble(),
        changeDue: (m['change_due'] as num? ?? 0).toDouble(),
        status: m['status'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        syncedAt: m['synced_at'] != null
            ? DateTime.parse(m['synced_at'] as String)
            : null,
      );
}
