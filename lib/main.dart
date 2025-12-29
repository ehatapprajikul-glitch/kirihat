import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Screens
import 'auth/login_screen.dart';
import 'customer/customer_dashboard.dart';
import 'vendor/vendor_dashboard.dart';
import 'admin/admin_dashboard.dart';
import 'rider/rider_dashboard.dart';

// IMPORT THE GATE
import 'customer/location_gate.dart';

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

        // 2. If User is Logged Out -> Show Login
        // Note: If you want guests to view products, change this to LocationGate()
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 3. If User is Logged In -> Check Role in Firestore
        User user = snapshot.data!;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              // Get Role
              var data = userSnapshot.data!.data() as Map<String, dynamic>;
              String role = (data['role'] ?? 'customer').toLowerCase();
              
              // ROUTING LOGIC
              if (role == 'admin') {
                return const AdminDashboard();
              }
              if (role == 'vendor') {
                return const VendorDashboard();
              }
              if (role == 'rider') {
                return const RiderDashboard();
              }

              // --- CUSTOMER LOGIC ---
              // Instead of going straight to Dashboard, we send them to the GATE.
              // The Gate will check GPS -> Then send them to Dashboard.
              return const LocationGate(); 
            }

            // Fallback (e.g. new user without data yet) -> Send to Gate
            return const LocationGate();
          },
        );
      },
    );
  }
}