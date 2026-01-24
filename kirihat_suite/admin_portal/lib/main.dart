import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'firebase_options.dart';

// Screens
import 'auth/phone_auth_screen.dart';
import 'auth/login_screen.dart';
import 'vendor/vendor_dashboard.dart';
import 'admin/admin_web_layout.dart';
import 'seller/seller_dashboard.dart';
import 'landing/portal_landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kirihat Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple), // Admin/Portal Theme
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) {
          return const PortalLandingScreen();
        }

        User user = snapshot.data!;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              var data = userSnapshot.data!.data() as Map<String, dynamic>;
              String role = (data['role'] ?? 'customer').toString().toLowerCase().trim();
              
              // Allowed roles for the Portal
              if (role == 'admin') return const AdminWebLayout();
              if (role == 'vendor') return const VendorDashboard();
              if (role == 'seller') return const SellerDashboard();

              // Unauthorized roles
              return Scaffold(
                 body: Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Text("Unauthorized: Role '$role' cannot access the Portal."),
                       const SizedBox(height: 16),
                       ElevatedButton(
                         onPressed: () => FirebaseAuth.instance.signOut(), 
                         child: const Text("Logout")
                       )
                     ],
                   ),
                 ),
               );
            }
            return const LoginScreen(); // Fallback if user exists but doc doesn't (should require profile setup usually)
          },
        );
      },
    );
  }
}
