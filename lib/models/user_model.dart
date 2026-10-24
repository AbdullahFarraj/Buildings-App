import '../core/enums/user_role.dart';

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String? email;
  final UserRole role;
  final String? apartmentId;
  final String? buildingId;
  final String? profession;
  final double? averageRating;
  final int? totalRatings;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
  final String? contractUrl;
  final List<Map<String, String>>? documents;
  final String? fcmToken;
  final List<TenantProperty>? properties;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.apartmentId,
    this.buildingId,
    this.profession,
    this.averageRating,
    this.totalRatings,
    this.contractStartDate,
    this.contractEndDate,
    this.contractUrl,
    this.documents,
    this.fcmToken,
    this.properties,
  });

  /// Returns all properties rented by this tenant, falling back to legacy single building/apt fields
  List<TenantProperty> get allProperties {
    if (properties != null && properties!.isNotEmpty) {
      return properties!;
    }
    if ((buildingId != null && buildingId!.isNotEmpty) ||
        (apartmentId != null && apartmentId!.isNotEmpty)) {
      return [
        TenantProperty(
          buildingName: buildingId ?? 'Building Not Set',
          unitNumber: apartmentId ?? 'Not Set',
          startDate: contractStartDate,
          endDate: contractEndDate,
        ),
      ];
    }
    return [];
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    List<TenantProperty>? parsedProperties;
    if (map['properties'] is List) {
      parsedProperties = (map['properties'] as List)
          .whereType<Map>()
          .map((e) => TenantProperty.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      role: UserRole.fromString(map['role'] ?? 'tenant'),
      apartmentId: map['apartmentId'],
      buildingId: map['buildingId'],
      profession: map['profession'],
      averageRating: map['averageRating']?.toDouble(),
      totalRatings: map['totalRatings']?.toInt(),
      contractStartDate: map['contractStartDate'] != null ? DateTime.parse(map['contractStartDate']).toLocal() : null,
      contractEndDate: map['contractEndDate'] != null ? DateTime.parse(map['contractEndDate']).toLocal() : null,
      contractUrl: map['contractUrl'],
      documents: (map['documents'] as List<dynamic>?)
          ?.map((e) => Map<String, String>.from(e))
          .toList(),
      fcmToken: map['fcmToken'],
      properties: parsedProperties,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'role': role.value,
      'apartmentId': apartmentId,
      'buildingId': buildingId,
      if (profession != null) 'profession': profession,
      if (averageRating != null) 'averageRating': averageRating,
      if (totalRatings != null) 'totalRatings': totalRatings,
      if (contractStartDate != null) 'contractStartDate': contractStartDate!.toIso8601String(),
      if (contractEndDate != null) 'contractEndDate': contractEndDate!.toIso8601String(),
      if (contractUrl != null) 'contractUrl': contractUrl,
      if (documents != null) 'documents': documents,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (properties != null)
        'properties': properties!.map((p) => p.toMap()).toList(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? phone,
    String? email,
    UserRole? role,
    String? apartmentId,
    String? buildingId,
    String? profession,
    double? averageRating,
    int? totalRatings,
    DateTime? contractStartDate,
    DateTime? contractEndDate,
    String? contractUrl,
    List<Map<String, String>>? documents,
    String? fcmToken,
    List<TenantProperty>? properties,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      apartmentId: apartmentId ?? this.apartmentId,
      buildingId: buildingId ?? this.buildingId,
      profession: profession ?? this.profession,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      contractStartDate: contractStartDate ?? this.contractStartDate,
      contractEndDate: contractEndDate ?? this.contractEndDate,
      contractUrl: contractUrl ?? this.contractUrl,
      documents: documents ?? this.documents,
      fcmToken: fcmToken ?? this.fcmToken,
      properties: properties ?? this.properties,
    );
  }
}

class TenantProperty {
  final String buildingName;
  final String unitNumber;
  final String? unitType;
  final String? contractCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? rentAmount;
  final double? yearValue;

  TenantProperty({
    required this.buildingName,
    required this.unitNumber,
    this.unitType,
    this.contractCode,
    this.startDate,
    this.endDate,
    this.rentAmount,
    this.yearValue,
  });

  factory TenantProperty.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val)?.toLocal();
      return null;
    }

    return TenantProperty(
      buildingName: (map['buildingName'] ?? '').toString().trim(),
      unitNumber: (map['unitNumber'] ?? '').toString().trim(),
      unitType: map['unitType']?.toString().trim(),
      contractCode: map['contractCode']?.toString().trim(),
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      rentAmount: (map['rentAmount'] as num?)?.toDouble(),
      yearValue: (map['yearValue'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'buildingName': buildingName,
      'unitNumber': unitNumber,
      if (unitType != null) 'unitType': unitType,
      if (contractCode != null) 'contractCode': contractCode,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      if (rentAmount != null) 'rentAmount': rentAmount,
      if (yearValue != null) 'yearValue': yearValue,
    };
  }

  String get displayName => '$buildingName - Apt: $unitNumber';
}

