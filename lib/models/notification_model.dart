import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId; // The recipient of the notification
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedTaskId; // For deep linking to a specific task

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.relatedTaskId,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String documentId) {
    return NotificationModel(
      id: documentId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      relatedTaskId: map['relatedTaskId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
      if (relatedTaskId != null) 'relatedTaskId': relatedTaskId,
    };
  }
}
