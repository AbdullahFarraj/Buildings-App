import 'package:flutter/material.dart';
import '../models/maintenance_task_model.dart';
import '../core/theme/app_colors.dart';
import 'full_screen_image_viewer.dart';

class TaskPhotosWidget extends StatelessWidget {
  final MaintenanceTaskModel task;

  const TaskPhotosWidget({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final hasIssuePhotos = task.photoUrls != null && task.photoUrls!.isNotEmpty;
    final hasProofPhoto = task.completionProofUrl != null && task.completionProofUrl!.isNotEmpty;
    final hasNotes = task.completionNotes != null && task.completionNotes!.trim().isNotEmpty;

    if (!hasIssuePhotos && !hasProofPhoto && !hasNotes) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // If both before and after photos exist: show Side-by-Side Comparison
        if (hasIssuePhotos && hasProofPhoto) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.compare, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text(
                      'Repair Comparison / مقارنة التصليح',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Before (Issue)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: AppColors.statusPendingBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Before / الخلل',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.statusPendingText,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    imageUrls: task.photoUrls!,
                                    initialIndex: 0,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Image.network(
                                    task.photoUrls!.first,
                                    height: 90,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _errorPlaceholder(),
                                  ),
                                  if (task.photoUrls!.length > 1)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '+${task.photoUrls!.length - 1}',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // After (Completion Proof)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: AppColors.statusCompletedBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 12, color: AppColors.statusCompletedText),
                                SizedBox(width: 4),
                                Text(
                                  'After / بعد الإصلاح',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.statusCompletedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    imageUrls: [task.completionProofUrl!],
                                    initialIndex: 0,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.statusCompletedText, width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6.5),
                                child: Image.network(
                                  task.completionProofUrl!,
                                  height: 87,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _errorPlaceholder(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (hasProofPhoto) ...[
          // Only proof photo exists
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.statusCompletedBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: AppColors.statusCompletedText),
                    SizedBox(width: 4),
                    Text(
                      'Repair Proof / إثبات الإصلاح',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusCompletedText,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(
                        imageUrls: [task.completionProofUrl!],
                        initialIndex: 0,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    task.completionProofUrl!,
                    height: 80,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _errorPlaceholder(),
                  ),
                ),
              ),
            ],
          ),
        ] else if (hasIssuePhotos) ...[
          // Only issue photos exist
          SizedBox(
            height: 65,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: task.photoUrls!.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                      width: 65,
                      height: 65,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _errorPlaceholder(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // Technician completion notes if present
        if (hasNotes) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.statusCompletedBg.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.statusCompletedText.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.note_alt_outlined, size: 14, color: AppColors.statusCompletedText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Technician Note: ${task.completionNotes!}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.statusCompletedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      height: 70,
      width: 70,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
    );
  }
}
