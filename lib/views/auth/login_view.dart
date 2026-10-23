import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import 'signup_view.dart';

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
              emailInput = 'tenant_$fullPhone@elitelivingre.ae';
            }
          }
        } catch (_) {
          emailInput = 'tenant_$fullPhone@elitelivingre.ae';
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
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Welcome to EliteLivingre',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to manage maintenance & properties.',
                        style: TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
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
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
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
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupView()),
                          );
                        },
                        child: const Text('Don\'t have an account? Sign Up'),
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
