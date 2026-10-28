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

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  factory TaskMessageModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskMessageModel(
      id: documentId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      text: map['text'] ?? '',
      fileUrl: map['fileUrl'],
      fileName: map['fileName'],
      createdAt: _parseDate(map['createdAt']),
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
