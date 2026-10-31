import 'package:cloud_firestore/cloud_firestore.dart';

class ChequeModel {
  final String id;
  final String tenantUid;
  final String tenantName;
  final String chequeNumber;
  final String bankName;
  final double amount;
  final DateTime dueDate;
  final String status; // 'pending', 'paid', 'bounced', 'cancelled'
  final String? contractCode;
  final String? buildingName;
  final String? unitNumber;
  final String? notes;
  final String? chequeImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChequeModel({
    required this.id,
    required this.tenantUid,
    required this.tenantName,
    required this.chequeNumber,
    required this.bankName,
    required this.amount,
    required this.dueDate,
    this.status = 'pending',
    this.contractCode,
    this.buildingName,
    this.unitNumber,
    this.notes,
    this.chequeImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isBounced => status.toLowerCase() == 'bounced';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isPending => status.toLowerCase() == 'pending';

  bool get isOverdue {
    if (isPaid || isCancelled) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.isBefore(today);
  }

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  bool get isDueSoon {
    if (isPaid || isCancelled || isOverdue) return false;
    return daysUntilDue >= 0 && daysUntilDue <= 15;
  }

  String get displayStatusArabic {
    if (isPaid) return 'تم الصرف';
    if (isBounced) return 'مرتجع';
    if (isCancelled) return 'ملغي';
    if (isOverdue) return 'متأخر';
    if (isDueSoon) return 'مستحق قريباً';
    return 'قيد الانتظار';
  }

  String get displayStatusEnglish {
    if (isPaid) return 'Paid';
    if (isBounced) return 'Bounced';
    if (isCancelled) return 'Cancelled';
    if (isOverdue) return 'Overdue';
    if (isDueSoon) return 'Due Soon';
    return 'Pending';
  }

  factory ChequeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ChequeModel(
      id: doc.id,
      tenantUid: data['tenantUid']?.toString() ?? '',
      tenantName: data['tenantName']?.toString() ?? '',
      chequeNumber: data['chequeNumber']?.toString() ?? '',
      bankName: data['bankName']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: parseDate(data['dueDate']),
      status: (data['status']?.toString() ?? 'pending').toLowerCase(),
      contractCode: data['contractCode']?.toString(),
      buildingName: data['buildingName']?.toString(),
      unitNumber: data['unitNumber']?.toString(),
      notes: data['notes']?.toString(),
      chequeImageUrl: data['chequeImageUrl']?.toString(),
      createdAt: parseNullableDate(data['createdAt']),
      updatedAt: parseNullableDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantUid': tenantUid,
      'tenantName': tenantName,
      'chequeNumber': chequeNumber,
      'bankName': bankName,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      if (contractCode != null && contractCode!.isNotEmpty) 'contractCode': contractCode,
      if (buildingName != null && buildingName!.isNotEmpty) 'buildingName': buildingName,
      if (unitNumber != null && unitNumber!.isNotEmpty) 'unitNumber': unitNumber,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (chequeImageUrl != null && chequeImageUrl!.isNotEmpty) 'chequeImageUrl': chequeImageUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ChequeModel copyWith({
    String? id,
    String? tenantUid,
    String? tenantName,
    String? chequeNumber,
    String? bankName,
    double? amount,
    DateTime? dueDate,
    String? status,
    String? contractCode,
    String? buildingName,
    String? unitNumber,
    String? notes,
    String? chequeImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChequeModel(
      id: id ?? this.id,
      tenantUid: tenantUid ?? this.tenantUid,
      tenantName: tenantName ?? this.tenantName,
      chequeNumber: chequeNumber ?? this.chequeNumber,
      bankName: bankName ?? this.bankName,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      contractCode: contractCode ?? this.contractCode,
      buildingName: buildingName ?? this.buildingName,
      unitNumber: unitNumber ?? this.unitNumber,
      notes: notes ?? this.notes,
      chequeImageUrl: chequeImageUrl ?? this.chequeImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

