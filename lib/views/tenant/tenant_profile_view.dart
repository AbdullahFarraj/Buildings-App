import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../services/push_notification_service.dart';

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

    if (confirm == true) {
      try {
        await PushNotificationService.clearUserToken(widget.tenantId);
        // 1. Delete Auth user first (requires recent login) so we never delete Firestore data if Auth deletion fails
        if (_auth.currentUser != null) {
          await _auth.currentUser!.delete();
        }
        // 2. Delete Firestore document (the Cloud Function deleteAuthUser also cleans up if needed)
        await _firestoreService.deleteUser(widget.tenantId);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please sign out and sign in again before deleting your account.')),
            );
          }
          return;
        }
        await PushNotificationService.clearUserToken(widget.tenantId);
        await _auth.signOut();
      } catch (e) {
        await PushNotificationService.clearUserToken(widget.tenantId);
        await _auth.signOut();
      }
    }
  }

  void _showEditProfileDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                    decoration: const InputDecoration(labelText: 'Phone Number'),
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
                          if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fields cannot be empty')));
                            return;
                          }
                          setStateDialog(() => isSubmitting = true);
                          try {
                            final rawPhone = phoneController.text.trim();
                            final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
                            String sanitized = digits;
                            if (digits.startsWith('05') && digits.length == 10) {
                              sanitized = '971${digits.substring(1)}';
                            } else if (digits.startsWith('5') && digits.length == 9) {
                              sanitized = '971$digits';
                            } else if (digits.startsWith('009715') && digits.length == 14) {
                              sanitized = digits.substring(2);
                            }

                            final authEmail = (_auth.currentUser?.email ?? user.email ?? '').trim().toLowerCase();

                            // Check if phone number is already claimed by another user
                            if (sanitized.isNotEmpty) {
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
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('This phone number is already linked to another account.')),
                                    );
                                  }
                                  setStateDialog(() => isSubmitting = false);
                                  return;
                                }
                              }
                            }

                            if (authEmail.isNotEmpty && sanitized.isNotEmpty) {
                              await FirebaseFirestore.instance
                                  .collection('phone_index')
                                  .doc(sanitized)
                                  .set({'email': authEmail, 'uid': user.uid}, SetOptions(merge: true));

                              if (sanitized.startsWith('9715') && sanitized.length == 12) {
                                final localPhone = '05${sanitized.substring(4)}';
                                await FirebaseFirestore.instance
                                    .collection('phone_index')
                                    .doc(localPhone)
                                    .set({'email': authEmail, 'uid': user.uid}, SetOptions(merge: true));
                              }
                            }

                            await _firestoreService.updateUser(user.uid, {
                              'name': nameController.text.trim(),
                              'phone': sanitized.isNotEmpty ? sanitized : rawPhone,
                            });

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (context.mounted) {
                              setState(() {
                                _userFuture = _firestoreService.getUser(widget.tenantId);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                            setStateDialog(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
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
                onPressed: () => _showEditProfileDialog(user),
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
                onPressed: _handleLogout,
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
                onPressed: _handleDeleteAccount,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Account'),
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
