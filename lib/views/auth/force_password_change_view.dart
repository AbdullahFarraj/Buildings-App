import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../services/push_notification_service.dart';

/// Shown on first login (or when management flags the account) to force the
/// user to replace the default password (which is their phone number).
class ForcePasswordChangeView extends StatefulWidget {
  final String uid;
  final String phone;
  final VoidCallback onPasswordChanged;

  const ForcePasswordChangeView({
    super.key,
    required this.uid,
    required this.phone,
    required this.onPasswordChanged,
  });

  @override
  State<ForcePasswordChangeView> createState() => _ForcePasswordChangeViewState();
}

class _ForcePasswordChangeViewState extends State<ForcePasswordChangeView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  bool _obscure = true;

  /// Passwords that must never be accepted (the defaults issued by the sync service).
  Set<String> get _forbiddenPasswords {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    final set = <String>{'Elite@123456', '123456', '12345678', 'password'};
    if (digits.isNotEmpty) {
      set.add(digits);
      if (digits.startsWith('9715') && digits.length == 12) {
        set.add('0${digits.substring(3)}'); // 05xxxxxxxx
        set.add(digits.substring(3)); // 5xxxxxxxx
        set.add('+$digits');
      }
    }
    return set;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Password must contain letters and numbers';
    }
    if (_forbiddenPasswords.contains(v)) {
      return 'You cannot use your phone number or the default password';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await user.updatePassword(_passwordController.text);
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'mustChangePassword': false,
        'passwordChangedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
      widget.onPasswordChanged();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('For security, please sign in again and then change your password.')),
        );
        await PushNotificationService.clearUserToken();
        await FirebaseAuth.instance.signOut();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to update password')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set a New Password'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () async {
              await PushNotificationService.clearUserToken();
              FirebaseAuth.instance.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset, size: 48, color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'For your security, please replace the default password before continuing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          hintText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          hintText: 'Confirm new password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'At least 8 characters, with letters and numbers.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Password'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
