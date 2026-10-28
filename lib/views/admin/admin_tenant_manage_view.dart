import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_colors.dart';

class AdminTenantManageView extends StatefulWidget {
  final UserModel tenant;

  const AdminTenantManageView({super.key, required this.tenant});

  @override
  State<AdminTenantManageView> createState() => _AdminTenantManageViewState();
}

class _AdminTenantManageViewState extends State<AdminTenantManageView> {
  final FirestoreService _firestoreService = FirestoreService();
  late UserModel _tenant;
  bool _isLoading = false;

  final TextEditingController _alertTitleController = TextEditingController();
  final TextEditingController _alertMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tenant = widget.tenant;
  }

  String _inferContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _openUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document link')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening document link')),
        );
      }
    }
  }

  Future<void> _updateDates(bool isStart) async {
    final initialDate = isStart 
        ? (_tenant.contractStartDate ?? DateTime.now()) 
        : (_tenant.contractEndDate ?? DateTime.now());
        
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _isLoading = true);
      try {
        final updatedTenant = isStart 
            ? _tenant.copyWith(contractStartDate: picked)
            : _tenant.copyWith(contractEndDate: picked);
            
        await _firestoreService.updateUser(updatedTenant.uid, {
          if (isStart) 'contractStartDate': picked.toIso8601String(),
          if (!isStart) 'contractEndDate': picked.toIso8601String(),
        });
        setState(() {
          _tenant = updatedTenant;
          _isLoading = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date updated')));
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<String?> _uploadPlatformFile(PlatformFile platformFile, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      final metadata = SettableMetadata(contentType: _inferContentType(path));
      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await platformFile.readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      } else if (platformFile.path != null) {
        uploadTask = ref.putFile(File(platformFile.path!), metadata);
      } else {
        final bytes = await platformFile.readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      }
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  Future<void> _uploadContract() async {
    final platformFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (platformFile != null) {
      setState(() => _isLoading = true);
      final ext = platformFile.extension ?? 'pdf';
      final fileName = 'contract_${const Uuid().v4()}.$ext';
      
      final url = await _uploadPlatformFile(platformFile, 'contracts/${_tenant.uid}/$fileName');
      
      if (url != null) {
        final updatedTenant = _tenant.copyWith(contractUrl: url);
        await _firestoreService.updateUser(updatedTenant.uid, {'contractUrl': url});
        setState(() {
          _tenant = updatedTenant;
          _isLoading = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract uploaded')));
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload contract')));
      }
    }
  }

  Future<void> _uploadOtherDocument() async {
    final platformFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (platformFile != null) {
      // Ask for document name
      final nameController = TextEditingController(text: platformFile.name);
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Document Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Enter a name for this document'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Upload')),
          ],
        ),
      );

      if (confirm == true && nameController.text.isNotEmpty) {
        setState(() => _isLoading = true);
        final ext = platformFile.extension ?? 'pdf';
        final fileName = '${const Uuid().v4()}.$ext';
        
        final url = await _uploadPlatformFile(platformFile, 'documents/${_tenant.uid}/$fileName');
        
        if (url != null) {
          final newDoc = {
            'name': nameController.text.trim(),
            'url': url,
            'uploadedAt': DateTime.now().toIso8601String(),
          };
          final currentDocs = List<Map<String, String>>.from(_tenant.documents ?? []);
          currentDocs.add(newDoc);
          
          final updatedTenant = _tenant.copyWith(documents: currentDocs);
          await _firestoreService.updateUser(updatedTenant.uid, {'documents': currentDocs});
          setState(() {
            _tenant = updatedTenant;
            _isLoading = false;
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded')));
        } else {
          setState(() => _isLoading = false);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload document')));
        }
      }
    }
  }

  Future<void> _deleteDocument(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final currentDocs = List<Map<String, String>>.from(_tenant.documents ?? []);
      currentDocs.removeAt(index);
      
      final updatedTenant = _tenant.copyWith(documents: currentDocs);
      await _firestoreService.updateUser(updatedTenant.uid, {'documents': currentDocs});
      setState(() {
        _tenant = updatedTenant;
        _isLoading = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document deleted')));
    }
  }

  Future<void> _sendAlert() async {
    if (_alertTitleController.text.isEmpty || _alertMessageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter title and message')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _tenant.uid,
        'title': _alertTitleController.text,
        'message': _alertMessageController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      setState(() {
        _alertTitleController.clear();
        _alertMessageController.clear();
        _isLoading = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert sent successfully')));
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send alert: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${_tenant.name}'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rented Properties
                Row(
                  children: [
                    const Text('Rented Properties', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_tenant.allProperties.length}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._tenant.allProperties.map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.apartment, color: AppColors.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.buildingName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(
                                'Unit: ${p.unitNumber} ${p.unitType != null && p.unitType!.isNotEmpty ? "(${p.unitType})" : ""}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              if (p.contractCode != null && p.contractCode!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Contract: ${p.contractCode}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ],
                              if (p.endDate != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.event_available, size: 13, color: Colors.amber.shade900),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Expires: ${dateFormat.format(p.endDate!)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (p.rentAmount != null && p.rentAmount! > 0)
                          Text(
                            '${p.rentAmount!.toStringAsFixed(0)} AED',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 20),

                // Contract Details
                const Text('Contract Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(_tenant.contractStartDate != null ? dateFormat.format(_tenant.contractStartDate!) : 'Not set'),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _updateDates(true),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(_tenant.contractEndDate != null ? dateFormat.format(_tenant.contractEndDate!) : 'Not set'),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _updateDates(false),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Contract File'),
                    subtitle: Text(_tenant.contractUrl != null ? 'Contract Uploaded (Tap to view)' : 'No contract uploaded'),
                    onTap: _tenant.contractUrl != null ? () => _openUrl(_tenant.contractUrl) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_tenant.contractUrl != null)
                          IconButton(
                            icon: const Icon(Icons.open_in_new, color: AppColors.primary),
                            tooltip: 'View Contract',
                            onPressed: () => _openUrl(_tenant.contractUrl),
                          ),
                        ElevatedButton(
                          onPressed: _uploadContract,
                          child: const Text('Upload'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Other Documents
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Other Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    TextButton.icon(
                      onPressed: _uploadOtherDocument,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Document'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_tenant.documents == null || _tenant.documents!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No documents uploaded yet.', style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ..._tenant.documents!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.insert_drive_file, color: AppColors.primary),
                        title: Text(doc['name'] ?? 'Document'),
                        onTap: doc['url'] != null ? () => _openUrl(doc['url']) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (doc['url'] != null)
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: AppColors.primary),
                                tooltip: 'Open / Download',
                                onPressed: () => _openUrl(doc['url']),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _deleteDocument(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 32),

                // Send Alert
                const Text('Send Alert/Notification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _alertTitleController,
                          decoration: const InputDecoration(labelText: 'Alert Title', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _alertMessageController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Alert Message', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _sendAlert,
                            child: const Text('Send Alert'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
