import 'package:flutter/material.dart';
import '../core/enums/task_status.dart';
import '../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final TaskStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case TaskStatus.pending:
        bgColor = AppColors.statusPendingBg;
        textColor = AppColors.statusPendingText;
        label = 'Pending';
        break;
      case TaskStatus.assigned:
        bgColor = AppColors.statusApprovedBg;
        textColor = AppColors.statusApprovedText;
        label = 'Assigned';
        break;
      case TaskStatus.inProgress:
        bgColor = AppColors.statusInProgressBg;
        textColor = AppColors.statusInProgressText;
        label = 'In Progress';
        break;
      case TaskStatus.onHold:
        bgColor = AppColors.statusOnHoldBg;
        textColor = AppColors.statusOnHoldText;
        label = 'On Hold (Materials)';
        break;
      case TaskStatus.waitingConfirmation:
        bgColor = AppColors.statusPendingBg;
        textColor = AppColors.statusPendingText;
        label = 'Waiting Confirmation';
        break;
      case TaskStatus.completed:
        bgColor = AppColors.statusCompletedBg;
        textColor = AppColors.statusCompletedText;
        label = 'Completed';
        break;
      case TaskStatus.rejected:
        bgColor = AppColors.statusRejectedBg;
        textColor = AppColors.statusRejectedText;
        label = 'Rejected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
