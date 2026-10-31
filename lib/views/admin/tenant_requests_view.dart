import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/maintenance_task_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../core/enums/user_role.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/maintenance_task_card.dart';

class TenantRequestsView extends StatelessWidget {
  final String tenantId;
  final String tenantName;

  const TenantRequestsView({
    super.key,
    required this.tenantId,
    required this.tenantName,
  });

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: Text('$tenantName\'s Requests'),
      ),
      body: StreamBuilder<List<MaintenanceTaskModel>>(
        stream: firestoreService.getTasksByTenant(tenantId),
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
                'No requests found for this tenant.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          // Sort by newest first
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final task = tasks[index];

              return MaintenanceTaskCard(
                task: task,
                userRole: UserRole.admin,
              );
            },
          );
        },
      ),
    );
  }
}
