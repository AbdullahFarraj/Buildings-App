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

  /// Uploads multiple initial task issue photos and returns the download URLs.
  Future<List<String>> uploadTaskPhotos(List<XFile> imageFiles, String tenantId) async {
    List<String> urls = [];
    for (var file in imageFiles) {
      try {
        final String fileName = _uuid.v4();
        final Reference ref = _storage.ref().child('tasks/$tenantId/$fileName.jpg');
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
        final url = await snapshot.ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        debugPrint('Error uploading task photo: $e');
        rethrow;
      }
    }
    return urls;
  }

  /// Uploads the completion proof photo and returns the download URL.
  Future<String?> uploadCompletionProof(XFile imageFile, String taskId) async {
    try {
      final String fileName = 'proof_${_uuid.v4()}';
      final Reference ref = _storage.ref().child('completions/$taskId/$fileName.jpg');
      UploadTask uploadTask;
      if (!kIsWeb && imageFile.path.isNotEmpty) {
        uploadTask = ref.putFile(
          File(imageFile.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final Uint8List bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
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
