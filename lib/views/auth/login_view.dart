import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      String emailInput = _emailController.text.trim();
      final passwordInput = _passwordController.text.trim();

      // If user typed a phone number instead of an email, look up their email
      if (!emailInput.contains('@')) {
        String cleanPhone = emailInput.replaceAll(RegExp(r'\D'), '');
        String fullPhone = cleanPhone;
        if (cleanPhone.startsWith('05') && cleanPhone.length == 10) {
          fullPhone = '971${cleanPhone.substring(1)}';
        } else if (cleanPhone.startsWith('5') && cleanPhone.length == 9) {
          fullPhone = '971$cleanPhone';
        }

        try {
          // 1. Try phone_index lookup first (safe, public, unauthenticated)
          final phoneDoc = await FirebaseFirestore.instance
              .collection('phone_index')
              .doc(fullPhone)
              .get();
          
          if (phoneDoc.exists && phoneDoc.data()?['email'] != null) {
            emailInput = phoneDoc.data()!['email'].toString().trim();
          } else {
            // Check by original typed phone (e.g. 05...)
            final localDoc = await FirebaseFirestore.instance
                .collection('phone_index')
                .doc(cleanPhone)
                .get();
            if (localDoc.exists && localDoc.data()?['email'] != null) {
              emailInput = localDoc.data()!['email'].toString().trim();
            } else {
              // 2. Fallback to standard generated email format
              emailInput = '$fullPhone@elitelivingre.ae';
            }
          }
        } catch (_) {
          emailInput = '$fullPhone@elitelivingre.ae';
        }
      }

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailInput,
          password: passwordInput,
        );
        // AuthWrapper will detect the change and route the user automatically.
      } on FirebaseAuthException catch (e) {
        // If password failed and looks like a phone number, try alternative phone prefix
        bool retrySuccess = false;
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          final cleanDigits = passwordInput.replaceAll(RegExp(r'\D'), '');
          if (cleanDigits.startsWith('05') && cleanDigits.length == 10) {
            try {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: emailInput,
                password: '971${cleanDigits.substring(1)}',
              );
              retrySuccess = true;
            } catch (_) {}
          } else if (cleanDigits.startsWith('9715') && cleanDigits.length == 12) {
            try {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: emailInput,
                password: '0${cleanDigits.substring(3)}',
              );
              retrySuccess = true;
            } catch (_) {}
          }
        }

        if (!retrySuccess) {
          if (!mounted) return;
          String errorMessage = 'An error occurred while logging in.';
          if (e.code == 'user-not-found') {
            errorMessage = 'No account found with this email or phone.';
          } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
            errorMessage = 'Incorrect credentials. Please check your email/phone and password.';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'The email address format is invalid.';
          } else {
            errorMessage = e.message ?? errorMessage;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showDemoSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Choose Demo Role',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select a pre-configured role to explore app features and screenshots.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildDemoOption(
                  icon: Icons.home_work_outlined,
                  title: 'Tenant (Unit 1404, Marina Crown)',
                  subtitle: 'Alexander Wright - Tenant',
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyDemoAccount('demo.tenant@elitelivingre.ae', 'Demo@123456');
                  },
                ),
                const Divider(),
                _buildDemoOption(
                  icon: Icons.build_outlined,
                  title: 'Technician (Maintenance Tasks)',
                  subtitle: 'Rashid Al-Mansoor - Maintenance Technician',
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyDemoAccount('demo.technician@elitelivingre.ae', 'Demo@123456');
                  },
                ),
                const Divider(),
                _buildDemoOption(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Property Manager (Admin Dashboard)',
                  subtitle: 'Property Manager - Admin Access',
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyDemoAccount('demo.admin@elitelivingre.ae', 'Demo@123456');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDemoOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  void _applyDemoAccount(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
    _login();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/login_logo.png',
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Enter your credentials to access your account.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'Email or Mobile Number',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email or phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign In'),
                        ),
                      ),
                      // Self sign-up is disabled: tenant accounts are created by the
                      // management / sync service only (see firestore.rules).
                      const SizedBox(height: 16),
                      const Text(
                        'Don\'t have an account? Please contact the management office.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.explore_outlined, color: AppColors.primary),
                        label: const Text(
                          'Explore Demo Mode',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        onPressed: _isLoading ? null : _showDemoSelector,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
      ),
    );
  }
}
