import 'package:cloud_firestore/cloud_firestore.dart';

class ContractModel {
  final String id;
  final String contractCode;
  final int? contractNumber;
  final String buildingName;
  final String unitNumber;
  final String unitType;
  final String tenantName;
  final String mobileNumber;
  final DateTime? startDate;
  final DateTime? endDate;
  final double rentAmount;
  final double yearValue;
  final String contractState;
  final String? tenantUid;

  ContractModel({
    required this.id,
    required this.contractCode,
    this.contractNumber,
    required this.buildingName,
    required this.unitNumber,
    required this.unitType,
    required this.tenantName,
    required this.mobileNumber,
    this.startDate,
    this.endDate,
    required this.rentAmount,
    required this.yearValue,
    required this.contractState,
    this.tenantUid,
  });

  factory ContractModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ContractModel(
      id: doc.id,
      contractCode: map['contractCode'] ?? '',
      contractNumber: map['contractNumber'] is int
          ? map['contractNumber']
          : int.tryParse(map['contractNumber']?.toString() ?? ''),
      buildingName: map['buildingName'] ?? '',
      unitNumber: map['unitNumber'] ?? '',
      unitType: map['unitType'] ?? '',
      tenantName: map['tenantName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      rentAmount: (map['rentAmount'] as num?)?.toDouble() ?? 0.0,
      yearValue: (map['yearValue'] as num?)?.toDouble() ?? 0.0,
      contractState: map['contractState'] ?? 'valid',
      tenantUid: map['tenantUid'],
    );
  }
}
