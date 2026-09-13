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

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.apartmentId,
    this.buildingId,
    this.profession,
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
    );
  }
}
