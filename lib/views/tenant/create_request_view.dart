import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/maintenance_task_model.dart';
import '../../core/enums/task_status.dart';
import '../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

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
  
  List<File> _imageFiles = [];
  bool _isSubmitting = false;

  DateTime? _selectedDate;
  String? _selectedSlot;
  final List<String> _slots = [
    'Morning: 08:00 AM - 11:00 AM',
    'Midday: 11:00 AM - 02:00 PM',
    'Afternoon: 02:00 PM - 05:00 PM',
  ];

  Future<void> _pickImages(ImageSource source) async {
    if (_imageFiles.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed.')),
      );
      return;
    }

    if (source == ImageSource.gallery) {
      final files = await _storageService.pickMultipleImages();
      setState(() {
        for (var file in files) {
          if (_imageFiles.length < 3) {
            _imageFiles.add(file);
          }
        }
      });
    } else {
      final file = await _storageService.pickImage(ImageSource.camera);
      if (file != null) {
        setState(() {
          if (_imageFiles.length < 3) {
            _imageFiles.add(file);
          }
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (_selectedDate == null || _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred visit date and time slot.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String>? photoUrls;
      if (_imageFiles.isNotEmpty) {
        photoUrls = await _storageService.uploadTaskPhotos(_imageFiles, widget.tenantId);
      }

      final task = MaintenanceTaskModel(
        id: '', // Firestore service handles generation if empty
        tenantId: widget.tenantId,
        apartmentNumber: _aptController.text,
        title: _titleController.text,
        description: _descController.text,
        category: _selectedCategory,
        photoUrls: photoUrls,
        preferredVisitDate: _selectedDate,
        preferredVisitSlot: _selectedSlot,
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
              const Text('Preferred Visit Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 14)),
                    selectableDayPredicate: (date) {
                      // Block Fridays
                      return date.weekday != DateTime.friday;
                    },
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate == null 
                          ? 'Select Date' 
                          : DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!),
                        style: TextStyle(
                          color: _selectedDate == null ? AppColors.textHint : AppColors.textPrimary,
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _slots.map((slot) {
                  final isSelected = _selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(slot, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedSlot = selected ? slot : null);
                    },
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Image Picker Section
              if (_imageFiles.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageFiles.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8, top: 8),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderDark),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_imageFiles[index], fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              if (_imageFiles.length < 3)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImages(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.background,
                          foregroundColor: AppColors.textPrimary,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _pickImages(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.background,
                          foregroundColor: AppColors.textPrimary,
                        ),
                      ),
                    ],
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
