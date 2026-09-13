import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Picks an image from the specified source with basic compression.
  Future<File?> pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70, // Basic compression
      maxWidth: 1024,
    );
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  /// Uploads the initial task issue photo and returns the download URL.
  Future<String?> uploadTaskPhoto(File imageFile, String tenantId) async {
    try {
      final String fileName = _uuid.v4();
      final Reference ref = _storage.ref().child('tasks/$tenantId/$fileName.jpg');
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading task photo: $e');
      return null;
    }
  }

  /// Uploads the completion proof photo and returns the download URL.
  Future<String?> uploadCompletionProof(File imageFile, String taskId) async {
    try {
      final String fileName = 'proof_${_uuid.v4()}';
      final Reference ref = _storage.ref().child('completions/$taskId/$fileName.jpg');
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading completion proof: $e');
      return null;
    }
  }
}
