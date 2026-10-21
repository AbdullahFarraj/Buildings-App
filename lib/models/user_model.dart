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
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
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
    );
  }
}
