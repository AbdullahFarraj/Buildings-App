import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Picks an image from the specified source with basic compression.
  Future<XFile?> pickImage(ImageSource source) async {
    return await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
    );
  }

  /// Picks multiple images from the gallery.
  Future<List<XFile>> pickMultipleImages() async {
    return await _picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1024,
    );
  }

  /// Helper to upload a single file with automatic retry (up to 2 attempts) for network resilience.
  Future<String> _uploadWithRetry(Reference ref, XFile file) async {
    int attempts = 0;
    const int maxAttempts = 2;
    while (attempts < maxAttempts) {
      try {
        attempts++;
        UploadTask uploadTask;
        if (!kIsWeb && file.path.isNotEmpty) {
          uploadTask = ref.putFile(
            File(file.path),
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          final Uint8List bytes = await file.readAsBytes();
          uploadTask = ref.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }
        final TaskSnapshot snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        if (attempts >= maxAttempts) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    throw Exception('Failed to upload file after $maxAttempts attempts.');
  }

  /// Uploads multiple initial task issue photos with retry and atomic rollback on failure.
  Future<List<String>> uploadTaskPhotos(List<XFile> imageFiles, String tenantId) async {
    List<String> urls = [];
    List<Reference> uploadedRefs = [];

    for (var file in imageFiles) {
      final String fileName = _uuid.v4();
      final Reference ref = _storage.ref().child('tasks/$tenantId/$fileName.jpg');
      try {
        final url = await _uploadWithRetry(ref, file);
        urls.add(url);
        uploadedRefs.add(ref);
      } catch (e) {
        debugPrint('Error uploading task photo, rolling back partial uploads: $e');
        // Rollback: delete already uploaded files in this batch to prevent orphaned files
        for (var uploadedRef in uploadedRefs) {
          try {
            await uploadedRef.delete();
          } catch (_) {}
        }
        rethrow;
      }
    }
    return urls;
  }

  /// Uploads the completion proof photo with retry and returns the download URL.
  Future<String?> uploadCompletionProof(XFile imageFile, String taskId) async {
    try {
      final String fileName = 'proof_${_uuid.v4()}';
      final Reference ref = _storage.ref().child('completions/$taskId/$fileName.jpg');
      return await _uploadWithRetry(ref, imageFile);
    } catch (e) {
      debugPrint('Error uploading completion proof: $e');
      rethrow;
    }
  }

  String _inferContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Uploads a generic file (document or image) for a chat and returns the download URL.
  Future<String?> uploadChatFile(dynamic file, String chatId, String fileName) async {
    try {
      final String uniqueFileName = '${_uuid.v4()}_$fileName';
      final Reference ref = _storage.ref().child('chats/$chatId/$uniqueFileName');
      final Uint8List bytes = await file.readAsBytes();
      final UploadTask uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: _inferContentType(fileName)),
      );
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading chat file: $e');
      return null;
    }
  }

  /// Uploads a generic file using bytes (required for Web)
  Future<String?> uploadChatFileBytes(Uint8List bytes, String chatId, String fileName) async {
    try {
      final String uniqueFileName = '${_uuid.v4()}_$fileName';
      final Reference ref = _storage.ref().child('chats/$chatId/$uniqueFileName');
      final UploadTask uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: _inferContentType(fileName)),
      );
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading chat file bytes: $e');
      return null;
    }
  }
}
