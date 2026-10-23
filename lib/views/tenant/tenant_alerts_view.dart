import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../services/firestore_service.dart';
import '../shared/chat_sheet.dart';

class TenantAlertsView extends StatelessWidget {
  final String tenantId;

  const TenantAlertsView({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();

    return StreamBuilder<List<NotificationModel>>(
      stream: notificationService.getUserNotifications(tenantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Error loading alerts: ${snapshot.error}', textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_none, size: 54, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No alerts or notifications yet',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Important announcements and lease updates will appear here.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final unreadCount = notifications.where((n) => !n.isRead).length;

        return Column(
          children: [
            // Top action bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'All Notifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount new',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (unreadCount > 0)
                    TextButton.icon(
                      onPressed: () => notificationService.markAllAsRead(tenantId),
                      icon: const Icon(Icons.done_all, size: 16, color: AppColors.primary),
                      label: const Text('Mark all read', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Notification List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildAlertCard(context, notification, notificationService);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlertCard(BuildContext context, NotificationModel notification, NotificationService service) {
    final isRead = notification.isRead;
    final timeStr = DateFormat('MMM dd, yyyy - hh:mm a').format(notification.createdAt);

    IconData iconData = Icons.notifications_active;
    Color iconColor = AppColors.primary;
    Color iconBg = AppColors.primary.withOpacity(0.1);

    if (notification.title.contains('💬') || notification.title.toLowerCase().contains('chat') || notification.title.toLowerCase().contains('message')) {
      iconData = Icons.chat_bubble_outline;
      iconColor = Colors.teal;
      iconBg = Colors.teal.shade50;
    } else if (notification.title.contains('🛠️') || notification.title.toLowerCase().contains('maintenance') || notification.title.toLowerCase().contains('task')) {
      iconData = Icons.build_outlined;
      iconColor = Colors.orange.shade800;
      iconBg = Colors.orange.shade50;
    } else if (notification.title.contains('📄') || notification.title.toLowerCase().contains('document') || notification.title.toLowerCase().contains('contract')) {
      iconData = Icons.description_outlined;
      iconColor = Colors.indigo;
      iconBg = Colors.indigo.shade50;
    } else if (notification.title.contains('⚠️') || notification.title.toLowerCase().contains('expir')) {
      iconData = Icons.warning_amber_rounded;
      iconColor = Colors.red.shade700;
      iconBg = Colors.red.shade50;
    }

    return Card(
      elevation: isRead ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isRead ? AppColors.border : AppColors.primary.withOpacity(0.5),
          width: isRead ? 1 : 1.5,
        ),
      ),
      color: isRead ? Colors.white : AppColors.primaryLight.withOpacity(0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openAlertDetails(context, notification, service),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isRead ? Colors.grey.shade100 : iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  iconData,
                  color: isRead ? Colors.grey.shade600 : iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 15,
                              color: isRead ? AppColors.textPrimary : AppColors.primary,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                        ),
                        Row(
                          children: [
                            Text(
                              'Tap to read',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isRead ? AppColors.textHint : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: isRead ? AppColors.textHint : AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void openNotificationDetails(BuildContext context, NotificationModel notification, NotificationService service) {
    if (!notification.isRead) {
      service.markAsRead(notification.id);
    }

    final timeStr = DateFormat('EEEE, MMM dd, yyyy - hh:mm a').format(notification.createdAt);
    final user = FirebaseAuth.instance.currentUser;

    final isChatNotification = notification.title.contains('💬') || 
                               notification.title.toLowerCase().contains('chat') ||
                               notification.title.toLowerCase().contains('message');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  notification.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    notification.message,
                    style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (isChatNotification && user != null)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final targetChatId = (notification.relatedTaskId != null && notification.relatedTaskId!.isNotEmpty)
                      ? notification.relatedTaskId!
                      : user.uid;

                  String chatTitle = 'Building Management';
                  if (notification.title.contains('-')) {
                    chatTitle = notification.title.split('-').last.replaceAll('💬', '').trim();
                  }

                  bool isDirect = true;
                  final List<String> receivers = [];
                  if (notification.relatedTaskId != null && 
                      notification.relatedTaskId!.isNotEmpty && 
                      notification.relatedTaskId != user.uid) {
                    final task = await FirestoreService().getTask(notification.relatedTaskId!);
                    if (task != null) {
                      isDirect = false;
                      chatTitle = 'Task: ${task.title}';
                      if (task.technicianId != null && task.technicianId != user.uid) {
                        receivers.add(task.technicianId!);
                      }
                    }
                  }

                  if (!context.mounted) return;

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetCtx) => Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
                      child: ChatSheet(
                        chatId: targetChatId,
                        chatTitle: chatTitle,
                        currentUserId: user.uid,
                        currentUserName: user.displayName ?? 'Tenant',
                        isDirectChat: isDirect,
                        receiverIds: receivers,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat, size: 16),
                label: const Text('Open Conversation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openAlertDetails(BuildContext context, NotificationModel notification, NotificationService service) {
    openNotificationDetails(context, notification, service);
  }
}
