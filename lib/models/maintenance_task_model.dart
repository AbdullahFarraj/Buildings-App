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
  final List<String>? photoUrls;
  final TaskStatus status;
  final String? technicianId;
  final String? technicianName;
  final DateTime? preferredVisitDate;
  final String? preferredVisitSlot;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? completionProofUrl;
  final String? completionNotes;
  final int? rating;
  final String? tenantFeedback;
  final String? holdReason;
  final String? rejectionReason;
  final String? rescheduledBy; // 'technician' or 'tenant'
  final DateTime? rescheduledAt;

  MaintenanceTaskModel({
    required this.id,
    required this.tenantId,
    required this.apartmentNumber,
    this.buildingId,
    required this.title,
    required this.description,
    required this.category,
    this.photoUrls,
    required this.status,
    this.technicianId,
    this.technicianName,
    this.preferredVisitDate,
    this.preferredVisitSlot,
    required this.createdAt,
    this.completedAt,
    this.completionProofUrl,
    this.completionNotes,
    this.rating,
    this.tenantFeedback,
    this.holdReason,
    this.rejectionReason,
    this.rescheduledBy,
    this.rescheduledAt,
  });

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  factory MaintenanceTaskModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MaintenanceTaskModel(
      id: documentId,
      tenantId: map['tenantId'] ?? '',
      apartmentNumber: map['apartmentNumber'] ?? '',
      buildingId: map['buildingId'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      photoUrls: map['photoUrls'] != null ? List<String>.from(map['photoUrls']) : null,
      status: TaskStatus.fromString(map['status'] ?? 'pending'),
      technicianId: map['technicianId'],
      technicianName: map['technicianName'],
      preferredVisitDate: _parseDate(map['preferredVisitDate']),
      preferredVisitSlot: map['preferredVisitSlot'],
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      completedAt: _parseDate(map['completedAt']),
      completionProofUrl: map['completionProofUrl'],
      completionNotes: map['completionNotes'],
      rating: (map['rating'] as num?)?.toInt(),
      tenantFeedback: map['tenantFeedback'],
      holdReason: map['holdReason'],
      rejectionReason: map['rejectionReason'],
      rescheduledBy: map['rescheduledBy'],
      rescheduledAt: _parseDate(map['rescheduledAt']),
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
      'photoUrls': photoUrls,
      'status': status.value,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'preferredVisitDate': preferredVisitDate != null ? Timestamp.fromDate(preferredVisitDate!) : null,
      'preferredVisitSlot': preferredVisitSlot,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completionProofUrl': completionProofUrl,
      'completionNotes': completionNotes,
      'rating': rating,
      'tenantFeedback': tenantFeedback,
      'holdReason': holdReason,
      'rejectionReason': rejectionReason,
      'rescheduledBy': rescheduledBy,
      'rescheduledAt': rescheduledAt != null ? Timestamp.fromDate(rescheduledAt!) : null,
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
    List<String>? photoUrls,
    TaskStatus? status,
    String? technicianId,
    String? technicianName,
    DateTime? preferredVisitDate,
    String? preferredVisitSlot,
    DateTime? createdAt,
    DateTime? completedAt,
    String? completionProofUrl,
    String? completionNotes,
    int? rating,
    String? tenantFeedback,
    String? holdReason,
    String? rejectionReason,
    String? rescheduledBy,
    DateTime? rescheduledAt,
  }) {
    return MaintenanceTaskModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      buildingId: buildingId ?? this.buildingId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      photoUrls: photoUrls ?? this.photoUrls,
      status: status ?? this.status,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      preferredVisitDate: preferredVisitDate ?? this.preferredVisitDate,
      preferredVisitSlot: preferredVisitSlot ?? this.preferredVisitSlot,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      completionProofUrl: completionProofUrl ?? this.completionProofUrl,
      completionNotes: completionNotes ?? this.completionNotes,
      rating: rating ?? this.rating,
      tenantFeedback: tenantFeedback ?? this.tenantFeedback,
      holdReason: holdReason ?? this.holdReason,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rescheduledBy: rescheduledBy ?? this.rescheduledBy,
      rescheduledAt: rescheduledAt ?? this.rescheduledAt,
    );
  }
}
