import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/maintenance_task_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/status_badge.dart';
import '../../core/enums/task_status.dart';
import '../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
import 'dart:io';
import 'dart:io';
import '../../widgets/full_screen_image_viewer.dart';
import '../../widgets/notifications_bell.dart';
import '../../utils/contact_helper.dart';
import '../shared/chat_sheet.dart';

class TechnicianHomeView extends StatefulWidget {
  final String technicianId;

  const TechnicianHomeView({super.key, required this.technicianId});

  @override
  State<TechnicianHomeView> createState() => _TechnicianHomeViewState();
}

class _TechnicianHomeViewState extends State<TechnicianHomeView> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  Future<void> _startWork(MaintenanceTaskModel task) async {
    await _firestoreService.updateTaskStatus(task.id, TaskStatus.inProgress);
  }

  void _callTenant(String tenantId) async {
    final tenant = await _firestoreService.getUser(tenantId);
    if (tenant != null && tenant.phone.isNotEmpty) {
      ContactHelper.launchCall(tenant.phone);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenant phone not available')));
      }
    }
  }

  void _whatsappTenant(String tenantId) async {
    final tenant = await _firestoreService.getUser(tenantId);
    if (tenant != null && tenant.phone.isNotEmpty) {
      ContactHelper.launchWhatsApp(tenant.phone);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenant phone not available')));
      }
    }
  }

  void _showCompletionDialog(MaintenanceTaskModel task) {
    final TextEditingController notesController = TextEditingController();
    File? _selectedImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Complete Task',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_selectedImage!, height: 120, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 14,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                              onPressed: () {
                                setSheetState(() => _selectedImage = null);
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () async {
                        final file = await _storageService.pickImage(ImageSource.camera);
                        if (file != null) {
                          setSheetState(() => _selectedImage = file);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Add Proof Photo (Optional)'),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add completion notes (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final notes = notesController.text.trim();
                      
                      // Show loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );

                      try {
                        String? photoUrl;
                        if (_selectedImage != null) {
                          photoUrl = await _storageService.uploadCompletionProof(_selectedImage!, task.id);
                        }

                        await _firestoreService.updateTaskStatus(
                          task.id,
                          TaskStatus.waitingConfirmation,
                          completionNotes: notes.isEmpty ? null : notes,
                          completionProofUrl: photoUrl,
                        );
                        if (context.mounted) {
                          Navigator.pop(context); // Close loading
                          Navigator.pop(context); // Close bottom sheet
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task marked as completed! Waiting for tenant confirmation.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusCompletedText, // Greenish color
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Confirm Completion'),
                  ),
                  const SizedBox(height: 24),
                ],
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
        title: const Text('Technician Tasks'),
        actions: [
          const NotificationsBell(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<MaintenanceTaskModel>>(
        stream: _firestoreService.getAssignedTasksForTechnician(widget.technicianId),
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
                'No pending assignments.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isAssigned = task.status == TaskStatus.assigned || task.status == TaskStatus.pending; 
              // Wait, tasks are usually "assigned" when assigned in our system, but let's check for both just in case.
              final isInProgress = task.status == TaskStatus.inProgress;
              final isCompleted = task.status == TaskStatus.completed;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.buildingId ?? 'Unknown Building',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Apt ${task.apartmentNumber}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: task.status),
                        ],
                      ),
                      const Divider(height: 24),
                      
                      // Issue Category and Title
                      Row(
                        children: [
                          Icon(Icons.build_circle_outlined, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            task.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      
                      const SizedBox(height: 16),
                      // Date
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.textHint),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy - hh:mm a').format(task.createdAt),
                            style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                          ),
                        ],
                      ),
                      if (task.preferredVisitDate != null && task.preferredVisitSlot != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, size: 20, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Visit Schedule: ${DateFormat('EEEE, MMM d').format(task.preferredVisitDate!)}\n${task.preferredVisitSlot}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Actions
                      if (!isCompleted) ...[
                        const SizedBox(height: 16),
                        if (isAssigned)
                          ElevatedButton.icon(
                            onPressed: () => _startWork(task),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Working'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        if (isInProgress) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _callTenant(task.tenantId),
                                  icon: const Icon(Icons.call),
                                  label: const Text('Call'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _whatsappTenant(task.tenantId),
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  label: const Text('WhatsApp', style: TextStyle(color: Colors.green)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: const BorderSide(color: Colors.green),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showCompletionDialog(task),
                            icon: const Icon(Icons.check),
                            label: const Text('Mark Completed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.statusCompletedText,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final user = await _firestoreService.getUser(widget.technicianId);
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
                                        task.tenantId,
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Comments'),
                          ),
                        ],
                      ),
                      if (isCompleted || task.status == TaskStatus.waitingConfirmation) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                task.status == TaskStatus.waitingConfirmation 
                                  ? 'Waiting Tenant Confirmation'
                                  : 'Task Completed',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
