import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'views/auth/auth_wrapper.dart';
import 'views/admin/admin_dashboard_view.dart';
import 'views/tenant/tenant_home_view.dart';
import 'views/technician/technician_home_view.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error (may need configuration): $e');
  }

  runApp(const BuildingApp());
}

class BuildingApp extends StatelessWidget {
  const BuildingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Building Maintenance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      routes: {
        // These are here to support the mock navigation in LoginView until 
        // real Firebase Auth is wired up into it.
        '/tenant': (context) {
          // This is a fallback route for the mock login
          // We need a tenantId, so we provide a placeholder one
          return const TenantHomeView(tenantId: 'mock_tenant_id');
        },
        '/technician': (context) => const TechnicianHomeView(technicianId: 'mock_technician_id'),
        '/admin': (context) => const AdminDashboardView(),
      },
    );
  }
}
