import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../shared/chat_sheet.dart';

class TenantDashboardView extends StatefulWidget {
  final String tenantId;

  const TenantDashboardView({super.key, required this.tenantId});

  @override
  State<TenantDashboardView> createState() => _TenantDashboardViewState();
}

class _TenantDashboardViewState extends State<TenantDashboardView> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<UserModel?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _firestoreService.getUser(widget.tenantId);
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error opening link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Error loading dashboard'));
        }

        final user = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header
              Text(
                'Welcome, ${user.name.split(' ').first}!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Here is your rent and lease overview',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              // Property Details Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Property Details'),
                  TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Padding(
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                          child: ChatSheet(
                            chatId: user.uid, // Direct chat between tenant and administration
                            chatTitle: 'Building Management',
                            currentUserId: user.uid,
                            currentUserName: user.name,
                            isDirectChat: true,
                            receiverIds: const [], // Admins listen to all chats or we could add admin IDs
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Contact Management'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: AppColors.primaryLight.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border, width: 1),
                ),
                color: AppColors.primaryLight.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.apartment, color: AppColors.accent, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Building: ${user.buildingId ?? 'Not Set'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Apartment: ${user.apartmentId ?? 'Not Set'}',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Lease & Contract Card
              _buildSectionTitle('Lease & Contract'),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDateColumn('Start Date', user.contractStartDate),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textHint),
                          _buildDateColumn('End Date', user.contractEndDate),
                        ],
                      ),
                      if (user.contractStartDate != null && user.contractEndDate != null) ...[
                        const SizedBox(height: 24),
                        _buildTimelineProgress(user.contractStartDate!, user.contractEndDate!),
                      ],
                      if (user.contractUrl != null) ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _launchUrl(user.contractUrl!),
                          icon: const Icon(Icons.download),
                          label: const Text('Download Original Contract'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Other Documents
              if (user.documents != null && user.documents!.isNotEmpty) ...[
                _buildSectionTitle('Additional Documents'),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border, width: 1),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: user.documents!.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = user.documents![index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.description, color: AppColors.primary),
                        ),
                        title: Text(
                          doc['name'] ?? 'Document',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.download_rounded, color: AppColors.primary),
                          onPressed: () => _launchUrl(doc['url']!),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildDateColumn(String label, DateTime? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          date != null ? DateFormat('dd MMM yyyy').format(date.toLocal()) : 'Not Set',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildTimelineProgress(DateTime start, DateTime end) {
    final now = DateTime.now();
    final totalDuration = end.difference(start).inDays;
    final passedDuration = now.difference(start).inDays;
    
    double progress = 0.0;
    if (totalDuration > 0) {
      progress = (passedDuration / totalDuration).clamp(0.0, 1.0);
    }
    
    final daysRemaining = end.difference(now).inDays;
    final remainingText = daysRemaining > 0 
        ? '$daysRemaining days remaining' 
        : 'Contract expired';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Lease Progress', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(remainingText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: daysRemaining > 0 ? AppColors.primary : Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? Colors.red : AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}
