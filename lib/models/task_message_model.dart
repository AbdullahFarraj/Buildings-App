import 'package:cloud_firestore/cloud_firestore.dart';

class TaskMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? fileUrl;
  final String? fileName;
  final DateTime createdAt;

  TaskMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.fileUrl,
    this.fileName,
    required this.createdAt,
  });

  factory TaskMessageModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskMessageModel(
      id: documentId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      text: map['text'] ?? '',
      fileUrl: map['fileUrl'],
      fileName: map['fileName'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
