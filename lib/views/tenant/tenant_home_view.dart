import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/maintenance_task_model.dart';
import '../../models/user_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/status_badge.dart';
import '../../core/enums/task_status.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/full_screen_image_viewer.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
import '../../widgets/notifications_bell.dart';
import 'tenant_profile_view.dart';
import 'tenant_alerts_view.dart';
import 'tenant_dashboard_view.dart';
import '../../utils/contact_helper.dart';
import '../shared/chat_sheet.dart';

class TenantHomeView extends StatefulWidget {
  final String tenantId;

  const TenantHomeView({super.key, required this.tenantId});

  @override
  State<TenantHomeView> createState() => _TenantHomeViewState();
}

class _TenantHomeViewState extends State<TenantHomeView> {
  final FirestoreService _firestoreService = FirestoreService();
  
  int _selectedIndex = 0;

  void _showCreateRequestSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: CreateRequestFormSheet(
            tenantId: widget.tenantId,
            firestoreService: _firestoreService,
          ),
        );
      },
    );
  }

  void _showRatingDialog(MaintenanceTaskModel task) {
    int rating = 5;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Completion'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Please rate the technician\'s work:'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feedbackController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Feedback (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // close dialog
                    try {
                      if (task.technicianId != null) {
                        await _firestoreService.submitTenantRating(
                          task.id,
                          task.technicianId!,
                          rating,
                          feedbackController.text.trim().isEmpty ? null : feedbackController.text.trim(),
                        );
                      } else {
                        await _firestoreService.updateTaskStatus(task.id, TaskStatus.completed);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thank you for your feedback!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsView() {
    return StreamBuilder<List<MaintenanceTaskModel>>(
      stream: _firestoreService.getTasksByTenant(widget.tenantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonLoader(itemCount: 4);
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final tasks = snapshot.data ?? [];

        if (tasks.isEmpty) {
          return const Center(
            child: Text(
              'No requests found.\nTap + to create one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
            final formattedDate = dateFormat.format(task.createdAt);

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${task.buildingId ?? 'Building'} - Apt ${task.apartmentNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusBadge(status: task.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.category, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          task.category,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                    if (task.preferredVisitDate != null && task.preferredVisitSlot != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Visit: ${DateFormat('MMM d, yyyy').format(task.preferredVisitDate!)} (${task.preferredVisitSlot!.split(':').first})',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (task.technicianName != null && task.technicianName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Assigned to: ${task.technicianName}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (task.technicianId != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.phone, color: AppColors.primary, size: 20),
                                  onPressed: () async {
                                    final tech = await _firestoreService.getUser(task.technicianId!);
                                    if (tech != null) ContactHelper.launchCall(tech.phone);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                                  onPressed: () async {
                                    final tech = await _firestoreService.getUser(task.technicianId!);
                                    if (tech != null) ContactHelper.launchWhatsApp(tech.phone);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                    if (task.photoUrls != null && task.photoUrls!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 60,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: task.photoUrls!.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImageViewer(
                                      imageUrls: task.photoUrls!,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  task.photoUrls![index],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.error),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (task.status != TaskStatus.completed && task.status != TaskStatus.rejected) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final user = await _firestoreService.getUser(widget.tenantId);
                              if (context.mounted && user != null) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => Padding(
                                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                    child: ChatSheet(
                                      chatId: task.id,
                                      chatTitle: task.title,
                                      currentUserId: user.uid,
                                      currentUserName: user.name,
                                      isDirectChat: false,
                                      receiverIds: [
                                        if (task.technicianId != null && task.technicianId != user.uid) task.technicianId!,
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Comments'),
                          ),
                          const Spacer(),
                          if (task.status == TaskStatus.pending)
                            TextButton.icon(
                              onPressed: () async {
                                // Show confirmation dialog before deleting
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Cancel Request'),
                                    content: const Text('Are you sure you want to cancel this maintenance request?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _firestoreService.deleteTask(task.id);
                                }
                              },
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Cancel'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.statusRejectedText),
                            ),
                          if (task.status == TaskStatus.waitingConfirmation) const SizedBox(width: 8),
                          if (task.status == TaskStatus.waitingConfirmation)
                            TextButton.icon(
                              onPressed: () {
                                _showRatingDialog(task);
                              },
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Confirm Completion'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.statusCompletedText),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? 'Dashboard' : 
          _selectedIndex == 1 ? 'My Requests' : 
          _selectedIndex == 2 ? 'Alerts' : 'My Profile'
        ),
        actions: const [
          NotificationsBell(),
        ],
      ),
      body: _selectedIndex == 0 
          ? TenantDashboardView(tenantId: widget.tenantId)
          : _selectedIndex == 1
              ? _buildRequestsView()
              : _selectedIndex == 2
                  ? TenantAlertsView(tenantId: widget.tenantId)
                  : TenantProfileView(tenantId: widget.tenantId),
      floatingActionButton: _selectedIndex == 1 
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showCreateRequestSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('New Request'),
            ) 
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class CreateRequestFormSheet extends StatefulWidget {
  final String tenantId;
  final FirestoreService firestoreService;

  const CreateRequestFormSheet({
    super.key,
    required this.tenantId,
    required this.firestoreService,
  });

  @override
  State<CreateRequestFormSheet> createState() => _CreateRequestFormSheetState();
}

class _CreateRequestFormSheetState extends State<CreateRequestFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  
  String _selectedCategory = 'Plumbing';
  final List<String> _categories = [
    'Plumbing',
    'Electrical',
    'AC / HVAC',
    'Carpentry',
    'General'
  ];
  
  bool _isSubmitting = false;
  bool _isLoadingUser = true;
  UserModel? _currentUser;
  
  List<File> _imageFiles = [];
  final StorageService _storageService = StorageService();

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

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = await widget.firestoreService.getUser(widget.tenantId);
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data: $e')),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) return;
    
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
        id: '', 
        tenantId: widget.tenantId,
        apartmentNumber: _currentUser!.apartmentId ?? 'Unknown',
        buildingId: _currentUser!.buildingId,
        title: '$_selectedCategory Issue',
        description: _descController.text,
        category: _selectedCategory,
        photoUrls: photoUrls,
        preferredVisitDate: _selectedDate,
        preferredVisitSlot: _selectedSlot,
        status: TaskStatus.pending,
        createdAt: DateTime.now(),
      );

      await widget.firestoreService.createTask(task);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully')),
        );
      }
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
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(child: Text('Failed to load your tenant data.')),
      );
    }

    final String aptDisplay = _currentUser!.apartmentId ?? 'Unknown Apt';
    final String bldDisplay = _currentUser!.buildingId ?? 'Unknown Building';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New Maintenance Request',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For: $bldDisplay, Apt $aptDisplay',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Issue Description',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 56.0),
                  child: Icon(Icons.description),
                ),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            const Text('Preferred Visit Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
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
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('Submit Request'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
