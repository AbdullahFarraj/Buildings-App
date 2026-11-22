import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/theme/app_colors.dart';

const String _demoAccountPassword = String.fromEnvironment('DEMO_ACCOUNT_PASSWORD');

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
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final rawInput = _emailController.text.trim();
    final passwordInput = _passwordController.text.trim();

    try {
      if (!rawInput.contains('@')) {
        // Server-side phone+password login prevents unauthenticated phone_index enumeration
        final callable = FirebaseFunctions.instance.httpsCallable('signInWithPhonePassword');
        final response = await callable.call({
          'phone': rawInput,
          'password': passwordInput,
        });
        final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};

        if (data['customToken'] is String && (data['customToken'] as String).isNotEmpty) {
          await FirebaseAuth.instance.signInWithCustomToken(data['customToken'] as String);
        } else if (data['verifiedEmail'] is String && data['verifiedPassword'] is String) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: data['verifiedEmail'] as String,
            password: data['verifiedPassword'] as String,
          );
        } else {
          throw Exception('Invalid authentication response');
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: rawInput,
          password: passwordInput,
        );
      }
      // AuthWrapper will detect the auth change and route automatically.
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String errorMessage;
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'Incorrect credentials. Please check your phone number and password.';
          break;
        case 'resource-exhausted':
          errorMessage = 'Too many failed login attempts. Please try again later.';
          break;
        case 'invalid-argument':
          errorMessage = 'Please enter a valid phone number and password.';
          break;
        default:
          errorMessage = 'Unable to sign in right now. Please check your connection and try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Unable to sign in. Please check your credentials and try again.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No account found with this email or phone.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Incorrect credentials. Please check your email/phone and password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address format is invalid.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many failed login attempts. Please try again later.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign in right now. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetController = TextEditingController(text: _emailController.text.trim());
    bool isSending = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Reset Password'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your registered email address or UAE mobile number to receive a password reset link.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: resetController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email or Mobile Number',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            final identifier = resetController.text.trim();
                            if (identifier.isEmpty) return;

                            setDialogState(() => isSending = true);
                            try {
                              await FirebaseFunctions.instance
                                  .httpsCallable('requestPasswordReset')
                                  .call({'identifier': identifier});
                            } catch (_) {
                              // Keep response uniform so accounts cannot be enumerated
                            }

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  duration: Duration(seconds: 6),
                                  content: Text(
                                    'If a registered email is associated with this account, a password reset link has been sent. If you don\'t receive it, please contact management.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Send Reset Link'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      resetController.dispose();
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
                    _applyDemoAccount('demo.tenant@elitelivingre.ae');
                  },
                ),
                const Divider(),
                _buildDemoOption(
                  icon: Icons.build_outlined,
                  title: 'Technician (Maintenance Tasks)',
                  subtitle: 'Rashid Al-Mansoor - Maintenance Technician',
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyDemoAccount('demo.technician@elitelivingre.ae');
                  },
                ),
                const Divider(),
                _buildDemoOption(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Property Manager (Admin Dashboard)',
                  subtitle: 'Property Manager - Admin Access',
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyDemoAccount('demo.admin@elitelivingre.ae');
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

  void _applyDemoAccount(String email) {
    if (_demoAccountPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode is not configured for this build.'),
        ),
      );
      return;
    }
    _emailController.text = email;
    _passwordController.text = _demoAccountPassword;
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
                            decoration: const InputDecoration(
                              hintText: 'Email or Mobile Number',
                              prefixIcon: Icon(Icons.person_outline),
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
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            obscureText: _obscurePassword,
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _showForgotPasswordDialog,
                              child: const Text('Forgot Password?', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                          const SizedBox(height: 12),
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
