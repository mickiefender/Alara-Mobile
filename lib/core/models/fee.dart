class FeePayment {
  final String id;
  final double amount;
  final DateTime? paymentDate;
  final String? method;
  final String? reference;
  final String? note;

  FeePayment({
    required this.id,
    required this.amount,
    this.paymentDate,
    this.method,
    this.reference,
    this.note,
  });

  factory FeePayment.fromJson(Map<String, dynamic> json) => FeePayment(
        id: (json['id'] ?? json['payment_id'] ?? '').toString(),
        amount: _toDouble(
          json['amount'] ??
              json['paid_amount'] ??
              json['payment_amount'] ??
              json['value'],
        ),
        paymentDate: _toDate(
          json['payment_date'] ??
              json['paid_on'] ??
              json['date'] ??
              json['created_at'],
        ),
        method: (json['method'] ?? json['payment_method'])?.toString(),
        reference: (json['reference'] ?? json['transaction_id'] ?? json['receipt_no'])?.toString(),
        note: (json['note'] ?? json['description'])?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'payment_date': paymentDate?.toIso8601String(),
        'method': method,
        'reference': reference,
        'note': note,
      };
}

class Fee {
  final String id;
  final String studentId;
  final String title;
  final String feeType;
  final double amount;
  final double paidAmount;
  final double? assignedAmount;
  final DateTime dueDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FeePayment> paymentHistory;

  Fee({
    required this.id,
    required this.studentId,
    required this.title,
    required this.feeType,
    required this.amount,
    required this.paidAmount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assignedAmount,
    this.paymentHistory = const [],
  });

  double get totalAssigned => assignedAmount ?? amount;
  double get balance => (totalAssigned - paidAmount).clamp(0, double.infinity);
  bool get isPaid => paidAmount >= totalAssigned;
  bool get isOverdue => !isPaid && DateTime.now().isAfter(dueDate);

  factory Fee.fromJson(Map<String, dynamic> json) {
    final assigned = _toDouble(
      json['assigned_amount'] ??
          json['total_amount_assigned'] ??
          json['amount_assigned'] ??
          json['total_amount'] ??
          json['amount'] ??
          json['fee_amount'] ??
          json['bill_amount'],
    );
    final paid = _toDouble(
      json['paid_amount'] ??
          json['amount_paid'] ??
          json['total_paid'] ??
          json['paid'] ??
          json['payment_total'] ??
          0,
    );
    final rawHistory = json['payment_history'] ??
        json['payments'] ??
        json['transactions'] ??
        json['payment_records'];

    return Fee(
      id: (json['id'] ?? json['fee_id'] ?? json['billing_id'] ?? '').toString(),
      studentId: (json['student_id'] ?? json['student'] ?? json['student_obj'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? json['fee_name'] ?? json['description'] ?? 'Fee').toString(),
      feeType: (json['fee_type'] ?? json['type'] ?? json['category'] ?? json['fee_category'] ?? 'General').toString(),
      amount: assigned,
      paidAmount: paid,
      assignedAmount: assigned,
      dueDate: _toDate(json['due_date'] ?? json['due_on'] ?? json['deadline']) ?? DateTime.now(),
      status: (json['status'] ?? json['payment_status'] ?? json['state'] ?? '').toString(),
      createdAt: _toDate(json['created_at'] ?? json['created'] ?? json['date_created']) ?? DateTime.now(),
      updatedAt: _toDate(json['updated_at'] ?? json['updated'] ?? json['modified_at']) ?? DateTime.now(),
      paymentHistory: _parsePaymentHistory(rawHistory),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'title': title,
        'fee_type': feeType,
        'amount': amount,
        'assigned_amount': assignedAmount,
        'paid_amount': paidAmount,
        'due_date': dueDate.toIso8601String(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'payment_history': paymentHistory.map((e) => e.toJson()).toList(),
      };
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

List<FeePayment> _parsePaymentHistory(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(FeePayment.fromJson)
        .toList();
  }
  if (raw is Map<String, dynamic>) {
    final nested = raw['results'];
    if (nested is List) {
      return nested
          .whereType<Map<String, dynamic>>()
          .map(FeePayment.fromJson)
          .toList();
    }
  }
  return const [];
}
