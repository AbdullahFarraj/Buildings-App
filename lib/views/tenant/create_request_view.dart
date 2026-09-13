import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/maintenance_task_model.dart';
import '../../core/enums/task_status.dart';
import '../../core/theme/app_colors.dart';

class CreateRequestView extends StatefulWidget {
  final String tenantId;

  const CreateRequestView({super.key, required this.tenantId});

  @override
  State<CreateRequestView> createState() => _CreateRequestViewState();
}

class _CreateRequestViewState extends State<CreateRequestView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _aptController = TextEditingController();
  
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  
  String _selectedCategory = 'Plumbing';
  final List<String> _categories = ['Plumbing', 'Electrical', 'HVAC', 'Other'];
  
  File? _imageFile;
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    final file = await _storageService.pickImage(ImageSource.gallery);
    if (file != null) {
      setState(() => _imageFile = file);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isSubmitting = true);

    try {
      String? photoUrl;
      if (_imageFile != null) {
        photoUrl = await _storageService.uploadTaskPhoto(_imageFile!, widget.tenantId);
      }

      final task = MaintenanceTaskModel(
        id: '', // Firestore service handles generation if empty
        tenantId: widget.tenantId,
        apartmentNumber: _aptController.text,
        title: _titleController.text,
        description: _descController.text,
        category: _selectedCategory,
        photoUrl: photoUrl,
        status: TaskStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createTask(task);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aptController,
                decoration: const InputDecoration(labelText: 'Apartment Number'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Issue Title'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              // Image Picker Section
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.borderDark, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: AppColors.textHint, size: 32),
                            SizedBox(height: 8),
                            Text('Attach Photo', style: TextStyle(color: AppColors.textHint)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text('Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
