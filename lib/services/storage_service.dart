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

  /// Picks multiple images from the gallery.
  Future<List<File>> pickMultipleImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1024,
    );
    return pickedFiles.map((f) => File(f.path)).toList();
  }

  /// Uploads multiple initial task issue photos and returns the download URLs.
  Future<List<String>> uploadTaskPhotos(List<File> imageFiles, String tenantId) async {
    List<String> urls = [];
    for (var file in imageFiles) {
      try {
        final String fileName = _uuid.v4();
        final Reference ref = _storage.ref().child('tasks/$tenantId/$fileName.jpg');
        final UploadTask uploadTask = ref.putFile(file);
        final TaskSnapshot snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        print('Error uploading task photo: $e');
      }
    }
    return urls;
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
