import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'firebase_options.dart';

// Screens
import 'auth/phone_auth_screen.dart';
import 'auth/login_screen.dart';
import 'customer/customer_dashboard.dart';
// import 'vendor/vendor_dashboard.dart'; // Removed for Customer App
// import 'admin/admin_web_layout.dart'; // Removed for Customer App
// import 'rider/rider_dashboard.dart'; // Removed for Customer App
// import 'seller/seller_dashboard.dart'; // Removed for Customer App

// IMPORT THE GATES
import 'customer/onboarding/pincode_gate.dart';

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
      title: 'Kiri Hat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const AuthWrapper(), // The Traffic Cop
    );
  }
}

// --- THE TRAFFIC COP (Decides which screen to show on app start) ---
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
        // 1. If Waiting for Auth Data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // 2. If User is NOT Logged In -> Show PincodeGate (Guest Mode)
        // Customers can browse without login
        if (!snapshot.hasData) {
          return const PincodeGateScreen();
        }

        return FutureBuilder<bool>(
          future: SessionService().isCustomerMode(),
          builder: (context, modeSnapshot) {
            // Wait for pref check
            if (modeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // In Customer App, we don't strictly enforce roles. 
            // If they are logged in, they see the Customer Dashboard (via PincodeGate).
            return const PincodeGateScreen(); 
          }
        );
      },
    );
  }
}
