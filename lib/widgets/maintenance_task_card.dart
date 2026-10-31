import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_task_model.dart';
import '../core/enums/task_status.dart';
import '../core/enums/user_role.dart';
import '../core/theme/app_colors.dart';
import 'status_badge.dart';
import 'task_photos_widget.dart';

class MaintenanceTaskCard extends StatelessWidget {
  final MaintenanceTaskModel task;
  final UserRole userRole;
  final VoidCallback? onTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onRescheduleTap;
  final VoidCallback? onHoldTap;
  final VoidCallback? onResumeTap;
  final VoidCallback? onStartWorkTap;
  final VoidCallback? onCompleteTap;
  final VoidCallback? onConfirmTap;
  final VoidCallback? onCancelTap;
  final VoidCallback? onRejectTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onTenantInfoTap;
  final VoidCallback? onCallTechnician;
  final VoidCallback? onWhatsAppTechnician;
  final VoidCallback? onCallTenant;
  final VoidCallback? onWhatsAppTenant;

  const MaintenanceTaskCard({
    super.key,
    required this.task,
    required this.userRole,
    this.onTap,
    this.onCommentsTap,
    this.onRescheduleTap,
    this.onHoldTap,
    this.onResumeTap,
    this.onStartWorkTap,
    this.onCompleteTap,
    this.onConfirmTap,
    this.onCancelTap,
    this.onRejectTap,
    this.onDeleteTap,
    this.onTenantInfoTap,
    this.onCallTechnician,
    this.onWhatsAppTechnician,
    this.onCallTenant,
    this.onWhatsAppTenant,
  });

  Color _getStatusAccentColor() {
    switch (task.status) {
      case TaskStatus.pending:
        return AppColors.statusPendingText;
      case TaskStatus.assigned:
        return AppColors.statusApprovedText;
      case TaskStatus.inProgress:
        return AppColors.statusInProgressText;
      case TaskStatus.onHold:
        return AppColors.statusOnHoldText;
      case TaskStatus.waitingConfirmation:
        return Colors.teal.shade700;
      case TaskStatus.completed:
        return AppColors.statusCompletedText;
      case TaskStatus.rejected:
        return AppColors.statusRejectedText;
    }
  }

  IconData _getCategoryIcon() {
    final cat = task.category.toLowerCase();
    if (cat.contains('plumb')) return Icons.plumbing_rounded;
    if (cat.contains('elect')) return Icons.bolt_rounded;
    if (cat.contains('ac') || cat.contains('air') || cat.contains('hvac') || cat.contains('cool')) {
      return Icons.ac_unit_rounded;
    }
    if (cat.contains('carpent') || cat.contains('wood') || cat.contains('door')) {
      return Icons.carpenter_rounded;
    }
    if (cat.contains('paint')) return Icons.format_paint_rounded;
    if (cat.contains('clean')) return Icons.cleaning_services_rounded;
    return Icons.build_circle_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getStatusAccentColor();
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: task.status == TaskStatus.onHold
              ? AppColors.statusOnHoldText.withValues(alpha: 0.4)
              : AppColors.border,
          width: task.status == TaskStatus.onHold ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: accentColor, width: 4.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Category Icon, Unit Badge & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getCategoryIcon(), color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  task.category,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: accentColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  'Apt ${task.apartmentNumber}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.buildingId ?? 'Building Property',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: task.status),
                    if (userRole == UserRole.admin && onTenantInfoTap != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                        onPressed: onTenantInfoTap,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Tenant Info',
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // 2. Task Title & Description
                Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                if (task.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],

                // 3. Special Status Alert Banners: On Hold (Materials) or Rejected
                if (task.status == TaskStatus.onHold) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.statusOnHoldBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.statusOnHoldText.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          color: AppColors.statusOnHoldText,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'On Hold: Purchasing Materials / معلق لشراء المواد',
                                style: TextStyle(
                                  color: AppColors.statusOnHoldText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              if (task.holdReason != null && task.holdReason!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  task.holdReason!,
                                  style: const TextStyle(
                                    color: AppColors.statusOnHoldText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (task.status == TaskStatus.rejected) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.statusRejectedBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.statusRejectedText.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.cancel_outlined,
                          color: AppColors.statusRejectedText,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Request Rejected by Management / تم رفض الطلب',
                                style: TextStyle(
                                  color: AppColors.statusRejectedText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              if (task.rejectionReason != null && task.rejectionReason!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Reason: ${task.rejectionReason!}',
                                  style: const TextStyle(
                                    color: AppColors.statusRejectedText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 4. Visit Schedule Box
                if (task.preferredVisitDate != null && task.preferredVisitSlot != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visit: ${DateFormat('EEEE, MMM d, yyyy').format(task.preferredVisitDate!)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                task.preferredVisitSlot!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (task.rescheduledBy != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.statusApprovedBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.update_rounded, size: 12, color: AppColors.statusApprovedText),
                                const SizedBox(width: 3),
                                Text(
                                  task.rescheduledBy == 'technician' ? 'Tech Rescheduled' : 'Tenant Rescheduled',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.statusApprovedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // 5. Assigned Technician details & direct contact
                if (task.technicianName != null && task.technicianName!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.engineering_rounded, size: 14, color: AppColors.primary),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Technician: ${task.technicianName}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (userRole != UserRole.technician) ...[
                        if (onCallTechnician != null)
                          IconButton(
                            icon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 18),
                            onPressed: onCallTechnician,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            tooltip: 'Call Technician',
                          ),
                        if (onWhatsAppTechnician != null)
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.green, size: 18),
                            onPressed: onWhatsAppTechnician,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            tooltip: 'WhatsApp Technician',
                          ),
                      ],
                    ],
                  ),
                ],

                // Contact Tenant if Technician view
                if (userRole == UserRole.technician &&
                    (task.status == TaskStatus.inProgress || task.status == TaskStatus.onHold || task.status == TaskStatus.assigned)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      const Text(
                        'Contact Tenant:',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      if (onCallTenant != null)
                        OutlinedButton.icon(
                          onPressed: onCallTenant,
                          icon: const Icon(Icons.phone, size: 14),
                          label: const Text('Call', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (onWhatsAppTenant != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: onWhatsAppTenant,
                          icon: const Icon(Icons.chat, size: 14, color: Colors.green),
                          label: const Text('WhatsApp', style: TextStyle(fontSize: 11, color: Colors.green)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            side: const BorderSide(color: Colors.green),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // 6. Photos Widget
                TaskPhotosWidget(task: task),

                // 7. Rating feedback if available
                if (task.rating != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.statusPendingBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        ...List.generate(5, (star) => Icon(
                          star < task.rating! ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 16,
                          color: Colors.amber.shade700,
                        )),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.tenantFeedback != null && task.tenantFeedback!.isNotEmpty
                                ? task.tenantFeedback!
                                : 'Tenant confirmed completion',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // 8. Bottom Action Row
                Row(
                  children: [
                    // Creation Date
                    Icon(Icons.access_time_rounded, size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(task.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                    const Spacer(),

                    // Comments button
                    if (onCommentsTap != null)
                      TextButton.icon(
                        onPressed: onCommentsTap,
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('Chat', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),

                // 9. Primary Action Buttons based on Role & Status
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    // TECHNICIAN ACTIONS
    if (userRole == UserRole.technician) {
      if (task.status == TaskStatus.assigned) {
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              if (onRescheduleTap != null)
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: onRescheduleTap,
                    icon: const Icon(Icons.schedule_rounded, size: 16),
                    label: const Text('Reschedule / تأجيل'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              if (onRescheduleTap != null && onStartWorkTap != null) const SizedBox(width: 8),
              if (onStartWorkTap != null)
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: onStartWorkTap,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Start Work / بدء'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      if (task.status == TaskStatus.inProgress) {
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Row(
                children: [
                  if (onHoldTap != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onHoldTap,
                        icon: const Icon(Icons.pause_circle_outline, color: AppColors.statusOnHoldText, size: 16),
                        label: const Text(
                          'Hold (Materials)',
                          style: TextStyle(color: AppColors.statusOnHoldText, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.statusOnHoldText),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  if (onHoldTap != null && onRescheduleTap != null) const SizedBox(width: 8),
                  if (onRescheduleTap != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRescheduleTap,
                        icon: const Icon(Icons.calendar_month_rounded, size: 16),
                        label: const Text('Reschedule', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                ],
              ),
              if (onCompleteTap != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onCompleteTap,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Mark Completed / إنهاء المهمة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusCompletedText,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      if (task.status == TaskStatus.onHold) {
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              if (onRescheduleTap != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRescheduleTap,
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Reschedule'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              if (onRescheduleTap != null && onResumeTap != null) const SizedBox(width: 8),
              if (onResumeTap != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onResumeTap,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Resume Work / استئناف'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    }

    // TENANT ACTIONS
    if (userRole == UserRole.tenant) {
      final canReschedule = task.status != TaskStatus.completed &&
          task.status != TaskStatus.rejected &&
          task.status != TaskStatus.waitingConfirmation;

      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            if (canReschedule && onRescheduleTap != null)
              OutlinedButton.icon(
                onPressed: onRescheduleTap,
                icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                label: const Text('Reschedule / تعديل الموعد', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            const Spacer(),
            if (task.status == TaskStatus.pending && onCancelTap != null)
              TextButton.icon(
                onPressed: onCancelTap,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel Request', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.statusRejectedText,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            if (task.status == TaskStatus.waitingConfirmation && onConfirmTap != null)
              ElevatedButton.icon(
                onPressed: onConfirmTap,
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Confirm & Rate / تأكيد وتقييم', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusCompletedText,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
          ],
        ),
      );
    }

    // ADMIN ACTIONS
    if (userRole == UserRole.admin) {
      final canReject = task.status == TaskStatus.pending ||
          task.status == TaskStatus.assigned ||
          task.status == TaskStatus.onHold;

      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            if (task.status == TaskStatus.pending || task.status == TaskStatus.assigned)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                  label: Text(
                    task.status == TaskStatus.pending ? 'Assign Tech' : 'Reassign Tech',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            if (canReject && onRejectTap != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onRejectTap,
                icon: const Icon(Icons.block_rounded, size: 15, color: AppColors.statusRejectedText),
                label: const Text(
                  'Reject / رفض',
                  style: TextStyle(color: AppColors.statusRejectedText, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.statusRejectedText),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
            if (onDeleteTap != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDeleteTap,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                tooltip: 'Delete Request',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // --- Reusable Dialog Helpers ---

  /// Show Reschedule Bottom Sheet for Worker or Tenant
  static Future<void> showRescheduleSheet({
    required BuildContext context,
    required MaintenanceTaskModel task,
    required String roleLabel, // 'technician' or 'tenant'
    required Future<void> Function(DateTime newDate, String newSlot) onConfirm,
  }) async {
    DateTime selectedDate = task.preferredVisitDate != null &&
            task.preferredVisitDate!.isAfter(DateTime.now())
        ? task.preferredVisitDate!
        : DateTime.now().add(const Duration(days: 1));

    String selectedSlot = task.preferredVisitSlot ?? 'Morning (09:00 AM - 12:00 PM)';
    final slots = [
      'Morning (09:00 AM - 12:00 PM)',
      'Afternoon (12:00 PM - 04:00 PM)',
      'Evening (04:00 PM - 08:00 PM)',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reschedule Visit / إعادة جدولة الموعد',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Task: ${task.title}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date Picker Card
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Date / التاريخ',
                                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                                ),
                                Text(
                                  DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Time Slot / الفترة الزمنية:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),

                  ...slots.map((slot) {
                    final isSelected = selectedSlot == slot;
                    return InkWell(
                      onTap: () => setSheetState(() => selectedSlot = slot),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 18,
                              color: isSelected ? AppColors.primary : AppColors.textHint,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              slot,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await onConfirm(selectedDate, selectedSlot);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Confirm Reschedule / تأكيد الموعد الجديد',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Show Hold for Materials Dialog for Technician
  static Future<void> showHoldMaterialsDialog({
    required BuildContext context,
    required MaintenanceTaskModel task,
    required Future<void> Function(String reason) onConfirm,
  }) async {
    final textController = TextEditingController(text: 'شراء قطع غيار ومواد صيانة');

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.statusOnHoldBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pause_circle_filled_rounded, color: AppColors.statusOnHoldText, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Hold for Materials\nتعليق لشراء المواد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please specify the materials or parts you need to purchase:\nحدد المواد أو القطع المطلوبة:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Need to buy 1/2 inch valve and pipe...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel / إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = textController.text.trim();
                Navigator.pop(dialogCtx);
                await onConfirm(reason.isEmpty ? 'Waiting for materials / بانتظار شراء المواد' : reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOnHoldText,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm / تعليق الطلب'),
            ),
          ],
        );
      },
    );
  }

  /// Show Reject Dialog for Admin / Management
  static Future<void> showRejectDialog({
    required BuildContext context,
    required MaintenanceTaskModel task,
    required Future<void> Function(String reason) onConfirm,
  }) async {
    final textController = TextEditingController();
    final quickReasons = [
      'Tenant Responsibility / مسؤولية المستأجر',
      'Out of Warranty or Scope / خارج نطاق الصيانة',
      'Duplicate Request / طلب مكرر',
      'Incorrect Details / بيانات غير صحيحة',
    ];

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.statusRejectedBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.block_rounded, color: AppColors.statusRejectedText, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Reject Request\nرفض طلب الصيانة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to reject request "${task.title}"?',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Quick Reason / اختر السبب:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    ...quickReasons.map((r) => InkWell(
                      onTap: () {
                        setDialogState(() {
                          textController.text = r;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right, size: 18, color: AppColors.accent),
                            Expanded(
                              child: Text(r, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                            ),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 10),
                    TextField(
                      controller: textController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter rejection reason / سبب الرفض...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel / إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final reason = textController.text.trim();
                    Navigator.pop(dialogCtx);
                    await onConfirm(reason.isEmpty ? 'Request rejected by management' : reason);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reject / رفض'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

