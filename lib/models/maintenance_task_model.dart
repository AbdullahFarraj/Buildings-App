import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/enums/task_status.dart';

class MaintenanceTaskModel {
  final String id;
  final String tenantId;
  final String apartmentNumber;
  final String? buildingId;
  final String title;
  final String description;
  final String category;
  final String? photoUrl;
  final TaskStatus status;
  final String? technicianId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? completionProofUrl;
  final String? completionNotes;

  MaintenanceTaskModel({
    required this.id,
    required this.tenantId,
    required this.apartmentNumber,
    this.buildingId,
    required this.title,
    required this.description,
    required this.category,
    this.photoUrl,
    required this.status,
    this.technicianId,
    required this.createdAt,
    this.completedAt,
    this.completionProofUrl,
    this.completionNotes,
  });

  factory MaintenanceTaskModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MaintenanceTaskModel(
      id: documentId,
      tenantId: map['tenantId'] ?? '',
      apartmentNumber: map['apartmentNumber'] ?? '',
      buildingId: map['buildingId'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      photoUrl: map['photoUrl'],
      status: TaskStatus.fromString(map['status'] ?? 'pending'),
      technicianId: map['technicianId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      completionProofUrl: map['completionProofUrl'],
      completionNotes: map['completionNotes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'apartmentNumber': apartmentNumber,
      'buildingId': buildingId,
      'title': title,
      'description': description,
      'category': category,
      'photoUrl': photoUrl,
      'status': status.value,
      'technicianId': technicianId,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completionProofUrl': completionProofUrl,
      'completionNotes': completionNotes,
    };
  }

  MaintenanceTaskModel copyWith({
    String? id,
    String? tenantId,
    String? apartmentNumber,
    String? buildingId,
    String? title,
    String? description,
    String? category,
    String? photoUrl,
    TaskStatus? status,
    String? technicianId,
    DateTime? createdAt,
    DateTime? completedAt,
    String? completionProofUrl,
    String? completionNotes,
  }) {
    return MaintenanceTaskModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      buildingId: buildingId ?? this.buildingId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      technicianId: technicianId ?? this.technicianId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      completionProofUrl: completionProofUrl ?? this.completionProofUrl,
      completionNotes: completionNotes ?? this.completionNotes,
    );
  }
}
