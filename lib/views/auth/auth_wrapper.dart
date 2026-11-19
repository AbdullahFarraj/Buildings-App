import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../core/enums/user_role.dart';
import '../../services/push_notification_service.dart';
import 'login_view.dart';
import 'force_password_change_view.dart';
import '../tenant/tenant_home_view.dart';
import '../technician/technician_home_view.dart';
import '../admin/admin_dashboard_view.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _cachedUid;
  Future<DocumentSnapshot>? _userFuture;
  String? _syncedTokenUid;

  /// Forces the user document to be re-fetched (e.g. after password change or retry).
  void _reload() {
    setState(() {
      _userFuture = null;
    });
  }

  Future<DocumentSnapshot> _getUserFuture(String uid) {
    if (_cachedUid != uid || _userFuture == null) {
      _cachedUid = uid;
      _userFuture = FirebaseFirestore.instance.collection('users').doc(uid).get();
    }
    return _userFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // If logged out, clear cached state
        if (user == null) {
          _cachedUid = null;
          _userFuture = null;
          _syncedTokenUid = null;
          return const LoginView();
        }

        // If logged in, fetch user role from Firestore (cached per UID)
        return FutureBuilder<DocumentSnapshot>(
          future: _getUserFuture(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        const Text(
                          'Unable to load your profile. Please check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            await PushNotificationService.clearUserToken(user.uid);
                            await FirebaseAuth.instance.signOut();
                          },
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User document doesn't exist yet, handle gracefully
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('User profile not found.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          await PushNotificationService.clearUserToken(user.uid);
                          await FirebaseAuth.instance.signOut();
                        },
                        child: const Text('Sign Out'),
                      )
                    ],
                  ),
                ),
              );
            }

            // Map data to UserModel
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final userModel = UserModel.fromMap(userData, user.uid);

            // Force replacing the default password (phone number) before using the app
            if (userData['mustChangePassword'] == true) {
              return ForcePasswordChangeView(
                uid: user.uid,
                phone: userModel.phone,
                onPasswordChanged: _reload,
              );
            }

            // Sync FCM token once per authenticated session without blocking build
            if (_syncedTokenUid != user.uid) {
              _syncedTokenUid = user.uid;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PushNotificationService.syncUserToken(user.uid);
              });
            }

            // Route based on role
            switch (userModel.role) {
              case UserRole.tenant:
                return TenantHomeView(tenantId: userModel.uid);
              case UserRole.technician:
                return TechnicianHomeView(technicianId: userModel.uid);
              case UserRole.admin:
                return const AdminDashboardView();
            }
          },
        );
      },
    );
  }
}
