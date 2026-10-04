import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

class TenantAlertsView extends StatelessWidget {
  final String tenantId;

  const TenantAlertsView({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: tenantId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No alerts or notifications.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final timeStr = timestamp != null
                ? DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())
                : '';
            final isRead = data['isRead'] ?? false;

            return Card(
              elevation: isRead ? 1 : 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isRead ? AppColors.border : AppColors.primary,
                  width: isRead ? 1 : 2,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(
                  isRead ? Icons.notifications_none : Icons.notifications_active,
                  color: isRead ? AppColors.textHint : AppColors.primary,
                  size: 32,
                ),
                title: Text(
                  data['title'] ?? 'Alert',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      data['message'] ?? '',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
                onTap: () {
                  if (!isRead) {
                    FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(docs[index].id)
                        .update({'isRead': true});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
