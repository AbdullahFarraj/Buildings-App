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
  /// Forces the user document to be re-fetched (e.g. after the password was changed).
  void _reload() => setState(() {});

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
        
        // If logged out
        if (user == null) {
          return const LoginView();
        }

        // If logged in, fetch user role from Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error: ${userSnapshot.error}')),
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
                          await PushNotificationService.clearUserToken();
                          FirebaseAuth.instance.signOut();
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

            // Fetch and update FCM token in background
            PushNotificationService.syncUserToken(user.uid);

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
