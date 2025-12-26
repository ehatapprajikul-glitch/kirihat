import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

// --- IMPORTS FOR ALL SCREENS ---
import 'auth/login_screen.dart';
import 'vendor/vendor_dashboard.dart';
import 'rider/rider_dashboard.dart';
import 'customer/customer_dashboard.dart'; // <--- The new 4-tab Customer Dashboard

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const KiriHatApp());
}

class KiriHatApp extends StatelessWidget {
  const KiriHatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kiri Hat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

// ---------------------------------------------------------------------------
// AUTH WRAPPER (The Traffic Controller)
// ---------------------------------------------------------------------------
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Waiting for Auth Status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Not Logged In -> Show Login Screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 3. Logged In -> Check Role in Firestore
        User user = snapshot.data!;

        return FutureBuilder<DocumentSnapshot>(
          // CRITICAL FIX: Use 'user.uid', NOT 'user.email'
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            String role = 'customer'; // Default fallback

            if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
              Map<String, dynamic>? data =
                  roleSnapshot.data!.data() as Map<String, dynamic>?;
              role = data?['role'] ?? 'customer';
            }

            // 4. Route to Correct Dashboard
            if (role == 'admin') return const AdminDashboard();
            if (role == 'vendor') return const VendorDashboard();
            if (role == 'rider') return const RiderDashboard();

            // Default to the new Customer Dashboard (Home, Categories, Orders, Me)
            return const CustomerDashboard();
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ADMIN DASHBOARD (Simplified)
// ---------------------------------------------------------------------------
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.red[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              "Welcome, Admin!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Use the Firebase Console to manage users.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
