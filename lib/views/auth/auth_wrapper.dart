import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../models/user_model.dart';
import '../../core/enums/user_role.dart';
import 'login_view.dart';
import '../tenant/tenant_home_view.dart';
import '../technician/technician_home_view.dart';
import '../admin/admin_dashboard_view.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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
                        onPressed: () => FirebaseAuth.instance.signOut(),
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

            // Fetch and update FCM token in background
            _updateFCMToken(user.uid);

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

  Future<void> _updateFCMToken(String userId) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // Request permission (Required for iOS)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get the token
        String? token;
        if (kIsWeb) {
          // NOTE: Web Push Notifications require a VAPID key from Firebase Console
          // Go to Project Settings -> Cloud Messaging -> Web configuration -> Generate Key Pair
          token = await messaging.getToken(
            vapidKey: 'BGnIO1ERLemsFNKnTY1llGzc4PC31FmTMM8WfeRn_WprktMZflSSNo1ZXKtLE_COANWPW7tJhOUZ9WBCYp1pZ9s', // Replace this!
          );
        } else {
          token = await messaging.getToken();
        }
        
        if (token != null) {
          // Save the token to Firestore
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'fcmToken': token,
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }
}
