import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/maintenance_task_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../core/enums/task_status.dart';
import '../../core/enums/user_role.dart';
import '../../core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../models/notification_model.dart';
import '../../widgets/app_notification_toast.dart';
import '../../widgets/maintenance_task_card.dart';
import 'dart:io';
import '../../widgets/notifications_bell.dart';
import '../../utils/contact_helper.dart';
import '../shared/chat_sheet.dart';
import '../../services/push_notification_service.dart';

class TechnicianHomeView extends StatefulWidget {
  final String technicianId;

  const TechnicianHomeView({super.key, required this.technicianId});

  @override
  State<TechnicianHomeView> createState() => _TechnicianHomeViewState();
}

class _TechnicianHomeViewState extends State<TechnicianHomeView> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  StreamSubscription<List<NotificationModel>>? _notificationSub;
  final Set<String> _seenNotificationIds = {};
  bool _isInitialNotificationLoad = true;

  @override
  void initState() {
    super.initState();
    _startForegroundNotificationListener();
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  void _startForegroundNotificationListener() {
    _notificationSub = NotificationService().getUserNotifications(widget.technicianId).listen((notifications) {
      if (_isInitialNotificationLoad) {
        for (var n in notifications) {
          _seenNotificationIds.add(n.id);
        }
        _isInitialNotificationLoad = false;
        return;
      }

      for (var n in notifications) {
        if (!_seenNotificationIds.contains(n.id)) {
          _seenNotificationIds.add(n.id);
          if (!n.isRead && mounted) {
            AppNotificationToast.show(
              context,
              title: n.title,
              message: n.message,
              onTap: () {
                NotificationService().markAsRead(n.id);
              },
            );
            break;
          }
        }
      }
    });
  }

  Future<void> _startWork(MaintenanceTaskModel task) async {
    await _firestoreService.updateTaskStatus(task.id, TaskStatus.inProgress);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Started work on task / تم بدء العمل')),
      );
    }
  }

  void _handleReschedule(MaintenanceTaskModel task) {
    MaintenanceTaskCard.showRescheduleSheet(
      context: context,
      task: task,
      roleLabel: 'technician',
      onConfirm: (newDate, newSlot) async {
        await _firestoreService.rescheduleTask(
          taskId: task.id,
          newDate: newDate,
          newSlot: newSlot,
          rescheduledByRole: 'technician',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Visit rescheduled successfully / تم تحديث الموعد بنجاح')),
          );
        }
      },
    );
  }

  void _handleHoldForMaterials(MaintenanceTaskModel task) {
    MaintenanceTaskCard.showHoldMaterialsDialog(
      context: context,
      task: task,
      onConfirm: (reason) async {
        final user = await _firestoreService.getUser(widget.technicianId);
        await _firestoreService.holdTaskForMaterials(
          taskId: task.id,
          reason: reason,
          technicianName: user?.name,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task put on hold for materials / تم تعليق الطلب لشراء المواد')),
          );
        }
      },
    );
  }

  void _handleResumeWork(MaintenanceTaskModel task) async {
    final user = await _firestoreService.getUser(widget.technicianId);
    await _firestoreService.resumeTask(
      taskId: task.id,
      technicianName: user?.name,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work resumed / تم استئناف العمل')),
      );
    }
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

  void _openChat(MaintenanceTaskModel task) async {
    final user = await _firestoreService.getUser(widget.technicianId);
    if (context.mounted && user != null) {
      ChatSheet.show(
        context: context,
        chatId: task.id,
        chatTitle: task.title,
        currentUserId: user.uid,
        currentUserName: user.name,
        isDirectChat: false,
        receiverIds: [
          task.tenantId,
        ],
      );
    }
  }

  void _showCompletionDialog(MaintenanceTaskModel task) {
    final TextEditingController notesController = TextEditingController();
    XFile? selectedImage;

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
                    'Complete Task / إنهاء المهمة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(selectedImage!.path, height: 120, width: double.infinity, fit: BoxFit.cover)
                              : Image.file(File(selectedImage!.path), height: 120, width: double.infinity, fit: BoxFit.cover),
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
                                setSheetState(() => selectedImage = null);
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
                          setSheetState(() => selectedImage = file);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Add Proof Photo (Optional) / صورة إثبات'),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add completion notes (optional) / ملاحظات الإنجاز',
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
                        if (selectedImage != null) {
                          photoUrl = await _storageService.uploadCompletionProof(selectedImage!, task.id);
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
                      backgroundColor: AppColors.statusCompletedText,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Confirm Completion / تأكيد الإنجاز'),
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
            onPressed: () async {
              await PushNotificationService.clearUserToken(widget.technicianId);
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
                'No pending assignments / لا توجد مهام حالية',
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
              return MaintenanceTaskCard(
                task: task,
                userRole: UserRole.technician,
                onStartWorkTap: () => _startWork(task),
                onCompleteTap: () => _showCompletionDialog(task),
                onHoldTap: () => _handleHoldForMaterials(task),
                onResumeTap: () => _handleResumeWork(task),
                onRescheduleTap: () => _handleReschedule(task),
                onCallTenant: () => _callTenant(task.tenantId),
                onWhatsAppTenant: () => _whatsappTenant(task.tenantId),
                onCommentsTap: () => _openChat(task),
              );
            },
          );
        },
      ),
    );
  }
}
