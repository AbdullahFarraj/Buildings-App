import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../services/push_notification_service.dart';
import '../../utils/phone_helper.dart';

class TenantProfileView extends StatefulWidget {
  final String tenantId;

  const TenantProfileView({super.key, required this.tenantId});

  @override
  State<TenantProfileView> createState() => _TenantProfileViewState();
}

class _TenantProfileViewState extends State<TenantProfileView> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Future<UserModel?> _userFuture;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _firestoreService.getUser(widget.tenantId);
  }

  void _handleLogout() async {
    await PushNotificationService.clearUserToken(widget.tenantId);
    await _auth.signOut();
  }

  void _handleDeleteAccount() async {
    if (_firestoreService.isCurrentSessionDemo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo Mode: Account deletion is disabled for shared demo accounts.'),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await PushNotificationService.clearUserToken(widget.tenantId);
      await FirebaseFunctions.instance.httpsCallable('deleteMyAccount').call();
      await _auth.signOut();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final requiresRecentLogin = e.code == 'failed-precondition' ||
          (e.message ?? '').contains('requires-recent-login');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requiresRecentLogin
                ? 'For security, please sign out and sign in again before deleting your account.'
                : 'Could not delete account right now. Please try again or contact management.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete account right now. Please try again or contact management.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _showEditProfileDialog(UserModel user) async {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    bool isSubmitting = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              return AlertDialog(
                title: const Text('Edit Profile'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'UAE Phone Number',
                        hintText: '05xxxxxxxx or 9715xxxxxxxx',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final trimmedName = nameController.text.trim();
                            final rawPhone = phoneController.text.trim();
                            if (trimmedName.isEmpty || rawPhone.isEmpty) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                const SnackBar(content: Text('Fields cannot be empty')),
                              );
                              return;
                            }

                            final sanitized = PhoneHelper.normalizeUaeMobile(rawPhone);
                            if (sanitized == null) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid UAE mobile number (05xxxxxxxx or 9715xxxxxxxx).'),
                                ),
                              );
                              return;
                            }

                            setStateDialog(() => isSubmitting = true);
                            try {
                              final authEmail = (_auth.currentUser?.email ?? user.email ?? '').trim().toLowerCase();

                              if (!_firestoreService.isCurrentSessionDemo) {
                                // Check if phone number is already claimed by another user
                                final existingIndex = await FirebaseFirestore.instance
                                    .collection('phone_index')
                                    .doc(sanitized)
                                    .get();
                                if (existingIndex.exists) {
                                  final data = existingIndex.data() ?? {};
                                  final ownerUid = data['uid']?.toString();
                                  final ownerEmail = data['email']?.toString().toLowerCase();
                                  if ((ownerUid != null && ownerUid.isNotEmpty && ownerUid != user.uid) ||
                                      (ownerUid == null && ownerEmail != null && ownerEmail != authEmail)) {
                                    if (dialogCtx.mounted) {
                                      ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                        const SnackBar(content: Text('This phone number is already linked to another account.')),
                                      );
                                    }
                                    setStateDialog(() => isSubmitting = false);
                                    return;
                                  }
                                }

                                if (authEmail.isNotEmpty) {
                                  final newVariants = PhoneHelper.getUaeVariants(sanitized);
                                  final oldVariants = PhoneHelper.getUaeVariants(user.phone);
                                  for (final ov in oldVariants) {
                                    if (!newVariants.contains(ov)) {
                                      await FirebaseFirestore.instance.collection('phone_index').doc(ov).delete().catchError((_) {});
                                    }
                                  }

                                  await FirebaseFirestore.instance
                                      .collection('phone_index')
                                      .doc(sanitized)
                                      .set({'email': authEmail, 'uid': user.uid}, SetOptions(merge: true));

                                  final localPhone = PhoneHelper.toLocalUaeFormat(sanitized);
                                  if (localPhone != null) {
                                    await FirebaseFirestore.instance
                                        .collection('phone_index')
                                        .doc(localPhone)
                                        .set({'email': authEmail, 'uid': user.uid}, SetOptions(merge: true));
                                  }
                                }
                              }

                              await _firestoreService.updateUser(user.uid, {
                                'name': trimmedName,
                                'phone': sanitized,
                                'profileEditedAt': FieldValue.serverTimestamp(),
                              });

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                setState(() {
                                  _userFuture = _firestoreService.getUser(widget.tenantId);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile updated successfully')),
                                );
                              }
                            } catch (e) {
                              if (dialogCtx.mounted) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  const SnackBar(content: Text('Failed to update profile. Please try again.')),
                                );
                              }
                              if (dialogCtx.mounted) {
                                setStateDialog(() => isSubmitting = false);
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
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

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final user = snapshot.data;
        if (user == null) {
          return const Center(child: Text('Profile not found.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'T',
                    style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildProfileRow(Icons.person_outline, 'Full Name', user.name),
                      const Divider(height: 32),
                      _buildProfileRow(Icons.business, 'Building', user.buildingId ?? 'Not Set'),
                      const Divider(height: 32),
                      _buildProfileRow(Icons.meeting_room_outlined, 'Apartment Number', user.apartmentId ?? 'Not Set'),
                      const Divider(height: 32),
                      _buildProfileRow(Icons.phone_outlined, 'Phone Number', user.phone),
                      const Divider(height: 32),
                      _buildProfileRow(Icons.email_outlined, 'Account Email', user.email ?? _auth.currentUser?.email ?? ''),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isDeleting ? null : () => _showEditProfileDialog(user),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isDeleting ? null : _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _isDeleting ? null : _handleDeleteAccount,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                      )
                    : const Icon(Icons.delete_forever),
                label: Text(_isDeleting ? 'Deleting Account...' : 'Delete Account'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
