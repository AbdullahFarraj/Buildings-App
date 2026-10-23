import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import '../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../views/shared/chat_sheet.dart';
import '../views/tenant/tenant_alerts_view.dart';

class NotificationsBell extends StatelessWidget {
  const NotificationsBell({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final notificationService = NotificationService();

    return StreamBuilder<List<NotificationModel>>(
      stream: notificationService.getUserNotifications(user.uid),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.isRead).length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notifications',
              onPressed: () {
                _showNotificationsSheet(context, notifications, notificationService, user.uid);
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsSheet(
    BuildContext context, 
    List<NotificationModel> notifications,
    NotificationService service,
    String userId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          service.markAllAsRead(userId);
                        },
                        child: const Text('Mark all read'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: notifications.isEmpty
                      ? const Center(
                          child: Text(
                            'No notifications yet.',
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: notifications.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _buildNotificationItem(context, notification, service);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(BuildContext context, NotificationModel notification, NotificationService service) {
    return InkWell(
      onTap: () async {
        if (!notification.isRead) {
          service.markAsRead(notification.id);
        }
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userName = user.displayName ?? 'User';
          final targetChatId = (notification.relatedTaskId != null && notification.relatedTaskId!.isNotEmpty)
              ? notification.relatedTaskId!
              : user.uid;

          final isChat = notification.title.contains('💬') || 
                         notification.title.toLowerCase().contains('chat') ||
                         notification.title.toLowerCase().contains('message');

          // Close notifications bottom sheet first
          Navigator.of(context).pop();

          if (isChat) {
            String chatTitle = 'Building Management';
            if (notification.title.contains('-')) {
              chatTitle = notification.title.split('-').last.replaceAll('💬', '').trim();
            } else if (notification.title.contains('from')) {
              chatTitle = notification.title.split('from').last.replaceAll('💬', '').trim();
            }

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: ChatSheet(
                  chatId: targetChatId,
                  chatTitle: chatTitle,
                  currentUserId: user.uid,
                  currentUserName: userName,
                  isDirectChat: true,
                  receiverIds: const [],
                ),
              ),
            );
          } else {
            // General announcement, task update, or document notification
            TenantAlertsView.openNotificationDetails(context, notification, service);
          }
        }
      },
      child: Container(
        color: notification.isRead ? Colors.transparent : AppColors.primaryLight.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildNotificationIcon(notification.title, notification.isRead),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(notification.createdAt),
                        style: TextStyle(
                          color: notification.isRead ? AppColors.textHint : AppColors.primary,
                          fontSize: 12,
                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: notification.isRead ? AppColors.textSecondary : AppColors.textPrimary.withOpacity(0.85),
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!notification.isRead) ...[
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String title, bool isRead) {
    IconData iconData = Icons.notifications;
    Color bgColor = isRead ? Colors.grey.shade200 : AppColors.primaryLight.withOpacity(0.2);
    Color iconColor = isRead ? Colors.grey.shade600 : AppColors.primary;

    if (title.contains('Chat') || title.contains('Message')) {
      iconData = Icons.chat_bubble_rounded;
      if (!isRead) {
        bgColor = Colors.green.shade100;
        iconColor = Colors.green.shade700;
      }
    } else if (title.contains('Expiring') || title.contains('⚠️')) {
      iconData = Icons.warning_rounded;
      if (!isRead) {
        bgColor = Colors.orange.shade100;
        iconColor = Colors.orange.shade700;
      }
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return DateFormat('h:mm a').format(date);
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
