import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../utils/contact_helper.dart';
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
  bool _isUploadingDoc = false;

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

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _userFuture = _firestoreService.getUser(widget.tenantId);
            });
            await _userFuture;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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

              // Property Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Property Details'),
                  if (user.allProperties.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${user.allProperties.length} Properties Rented',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...user.allProperties.map((prop) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border, width: 1),
                  ),
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
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
                                'Building: ${prop.buildingName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Apartment: ${prop.unitNumber} ${prop.unitType != null && prop.unitType!.isNotEmpty ? "(${prop.unitType})" : ""}',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              if (prop.rentAmount != null && prop.rentAmount! > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Rent: ${prop.rentAmount!.toStringAsFixed(0)} AED / yr',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 28),

              // Tenant Profile & Phone Card
              _buildSectionTitle('Tenant Profile & Phone'),
              const SizedBox(height: 12),
              _buildTenantProfileCard(user),
              const SizedBox(height: 28),

              // Contact Management Card
              _buildSectionTitle('Management & Support'),
              const SizedBox(height: 12),
              _buildContactManagementCard(user),
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

              // Additional Documents
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Additional Documents'),
                  TextButton.icon(
                    onPressed: _isUploadingDoc ? null : () => _uploadTenantDocument(user),
                    icon: _isUploadingDoc 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(_isUploadingDoc ? 'Uploading...' : 'Upload File'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: AppColors.primaryLight.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDocumentsCard(user),
              const SizedBox(height: 24),
            ],
          ),
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

  void _openChat(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ChatSheet(
          chatId: user.uid,
          chatTitle: 'Elite Living Management',
          currentUserId: user.uid,
          currentUserName: user.name,
          isDirectChat: true,
          receiverIds: const [],
        ),
      ),
    );
  }

  Widget _buildContactManagementCard(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: AppColors.accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Elite Living Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Support Team is Available',
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Have questions regarding your lease, payments, or maintenance? Connect directly with our team.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Primary Action: Live In-App Chat
                ElevatedButton.icon(
                  onPressed: () => _openChat(user),
                  icon: const Icon(Icons.forum_rounded, size: 20),
                  label: const Text(
                    'Live In-App Chat',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.accent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary Actions: WhatsApp & Email & Call
                Row(
                  children: [
                    // WhatsApp Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ContactHelper.launchWhatsApp(
                            ContactHelper.supportPhone,
                            text: 'Hello Elite Living Management, I am ${user.name} (Building: ${user.buildingId ?? 'N/A'}, Apt: ${user.apartmentId ?? 'N/A'}).',
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
                        label: const Text(
                          'WhatsApp',
                          style: TextStyle(
                            color: Color(0xFF25D366),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF25D366).withOpacity(0.5)),
                          backgroundColor: const Color(0xFF25D366).withOpacity(0.06),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Email Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ContactHelper.launchEmail(
                            ContactHelper.supportEmail,
                            subject: 'Inquiry from ${user.name} - Apt ${user.apartmentId ?? ''}',
                            body: 'Dear Management,\n\nTenant: ${user.name}\nBuilding: ${user.buildingId ?? ''}\nApartment: ${user.apartmentId ?? ''}\n\nMessage:\n',
                          );
                        },
                        icon: const Icon(Icons.email_outlined, color: Color(0xFF0284C7), size: 18),
                        label: const Text(
                          'Email',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF0284C7).withOpacity(0.5)),
                          backgroundColor: const Color(0xFF0284C7).withOpacity(0.06),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Call Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ContactHelper.launchCall(ContactHelper.supportPhone);
                        },
                        icon: const Icon(Icons.phone_in_talk_rounded, color: AppColors.primary, size: 18),
                        label: const Text(
                          'Call',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          backgroundColor: AppColors.background,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard(UserModel user) {
    final docs = user.documents ?? [];
    if (docs.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        color: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              const Icon(Icons.folder_open_rounded, size: 40, color: AppColors.textHint),
              const SizedBox(height: 8),
              const Text(
                'No additional documents yet',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'You can upload your Emirates ID, Passport, or payment slips for management review.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isUploadingDoc ? null : () => _uploadTenantDocument(user),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Upload Your First Document'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: docs.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final doc = docs[index];
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
            subtitle: doc['uploadedAt'] != null 
                ? Text(
                    'Uploaded ${DateFormat('dd MMM yyyy').format(DateTime.tryParse(doc['uploadedAt']!) ?? DateTime.now())}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  )
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.download_rounded, color: AppColors.primary),
              onPressed: () => _launchUrl(doc['url']!),
            ),
          );
        },
      ),
    );
  }

  Future<void> _uploadTenantDocument(UserModel user) async {
    final platformFile = await FilePicker.pickFile(type: FileType.any);
    if (!mounted || platformFile == null) return;
    final nameController = TextEditingController(text: platformFile.name);

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Document Name', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Choose a quick name or type a custom one:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Emirates ID',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('Emirates ID', style: TextStyle(fontSize: 12)),
                          onPressed: () => setDialogState(() => nameController.text = 'Emirates ID'),
                        ),
                        ActionChip(
                          label: const Text('Passport', style: TextStyle(fontSize: 12)),
                          onPressed: () => setDialogState(() => nameController.text = 'Passport Copy'),
                        ),
                        ActionChip(
                          label: const Text('Ejari', style: TextStyle(fontSize: 12)),
                          onPressed: () => setDialogState(() => nameController.text = 'Ejari Certificate'),
                        ),
                        ActionChip(
                          label: const Text('Payment Receipt', style: TextStyle(fontSize: 12)),
                          onPressed: () => setDialogState(() => nameController.text = 'Payment Receipt'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        ),
      );

      if (confirm == true && nameController.text.trim().isNotEmpty) {
        setState(() => _isUploadingDoc = true);
        try {
          final ext = platformFile.extension ?? 'pdf';
          final fileName = '${const Uuid().v4()}.$ext';
          final storagePath = 'documents/${user.uid}/$fileName';
          final ref = FirebaseStorage.instance.ref().child(storagePath);

          UploadTask uploadTask;
          if (kIsWeb) {
            final bytes = await platformFile.readAsBytes();
            uploadTask = ref.putData(bytes);
          } else if (platformFile.path != null) {
            uploadTask = ref.putFile(File(platformFile.path!));
          } else {
            final bytes = await platformFile.readAsBytes();
            uploadTask = ref.putData(bytes);
          }

          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();

          final currentDocs = List<Map<String, String>>.from(user.documents ?? []);
          currentDocs.add({
            'name': nameController.text.trim(),
            'url': downloadUrl,
            'uploadedAt': DateTime.now().toIso8601String(),
          });

          await _firestoreService.updateUser(user.uid, {'documents': currentDocs});

          // Notify Admins
          await NotificationService().notifyAdmins(
            title: 'New Tenant Document 📄',
            message: '${user.name} (Apt ${user.apartmentId ?? 'N/A'}) uploaded: ${nameController.text.trim()}',
            relatedTaskId: user.uid,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document uploaded successfully!')),
            );
            setState(() {
              _userFuture = _firestoreService.getUser(widget.tenantId);
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload document: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isUploadingDoc = false);
          }
        }
      }
    }

  Widget _buildTenantProfileCard(UserModel user) {
    final phoneTrimmed = user.phone.trim();
    final bool hasValidPhone = phoneTrimmed.isNotEmpty &&
        (phoneTrimmed.startsWith('05') ||
            phoneTrimmed.startsWith('9715') ||
            phoneTrimmed.startsWith('+9715'));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasValidPhone ? AppColors.border : Colors.amber.shade400,
          width: hasValidPhone ? 1 : 1.5,
        ),
      ),
      color: hasValidPhone ? Colors.white : Colors.amber.shade50.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasValidPhone
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasValidPhone ? Icons.phone_android : Icons.phone_missed,
                    color: hasValidPhone ? AppColors.primary : Colors.amber.shade800,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registered Phone Number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phoneTrimmed.isNotEmpty ? phoneTrimmed : 'No phone number registered',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: hasValidPhone ? AppColors.textPrimary : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showEditPhoneDialog(user),
                  icon: Icon(
                    phoneTrimmed.isEmpty ? Icons.add_circle_outline : Icons.edit_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    phoneTrimmed.isEmpty ? 'Add Phone' : 'Update',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: AppColors.primaryLight.withOpacity(0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            if (!hasValidPhone) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add your mobile number so you can log in directly using your phone instead of email.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (user.email != null && user.email!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account Email: ${user.email}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditPhoneDialog(UserModel user) {
    final phoneController = TextEditingController(text: user.phone);
    String? errorMessage;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    child: const Icon(Icons.phone_android, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.phone.trim().isEmpty ? 'Add Phone Number' : 'Update Phone Number',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your UAE mobile number (e.g., 05xxxxxxxx or 9715xxxxxxxx). This phone will be linked to your account for fast mobile login.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'UAE Mobile Number',
                      hintText: '05xxxxxxxx or 9715xxxxxxxx',
                      prefixIcon: const Icon(Icons.dialpad),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: errorMessage,
                    ),
                  ),
                  if (isSaving) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final raw = phoneController.text.trim();
                          final digits = raw.replaceAll(RegExp(r'\D'), '');

                          String sanitized = '';
                          if (digits.startsWith('05') && digits.length == 10) {
                            sanitized = '971${digits.substring(1)}';
                          } else if (digits.startsWith('5') && digits.length == 9) {
                            sanitized = '971$digits';
                          } else if (digits.startsWith('9715') && digits.length == 12) {
                            sanitized = digits;
                          } else if (digits.startsWith('009715') && digits.length == 14) {
                            sanitized = digits.substring(2);
                          } else {
                            setDialogState(() {
                              errorMessage =
                                  'Invalid UAE number. Must start with 05 (10 digits) or 9715 (12 digits).';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          try {
                            // 1. Update user document in Firestore
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({'phone': sanitized});

                            // 2. Update phone_index mappings so login works immediately!
                            if (user.email != null && user.email!.isNotEmpty) {
                              final email = user.email!.trim().toLowerCase();
                              await FirebaseFirestore.instance
                                  .collection('phone_index')
                                  .doc(sanitized)
                                  .set({'email': email}, SetOptions(merge: true));

                              final localPhone = '05${sanitized.substring(4)}';
                              await FirebaseFirestore.instance
                                  .collection('phone_index')
                                  .doc(localPhone)
                                  .set({'email': email}, SetOptions(merge: true));
                            }

                            // 3. Update contract documents if any exist for this tenant
                            final contractSnap = await FirebaseFirestore.instance
                                .collection('contracts')
                                .where('tenantUid', isEqualTo: user.uid)
                                .get();
                            for (var doc in contractSnap.docs) {
                              await doc.reference.update({'mobileNumber': sanitized});
                            }

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green.shade700,
                                  content: Text('Phone number updated successfully to $sanitized!'),
                                ),
                              );
                              setState(() {
                                _userFuture = _firestoreService.getUser(widget.tenantId);
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = 'Error saving phone number: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
