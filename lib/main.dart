import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Ensure flutter material is here if not already
import 'services/session_service.dart';
import 'firebase_options.dart';

// Screens
import 'auth/phone_auth_screen.dart';
import 'auth/login_screen.dart';
import 'customer/customer_dashboard.dart';
import 'vendor/vendor_dashboard.dart';
import 'admin/admin_web_layout.dart';
import 'rider/rider_dashboard.dart';
import 'seller/seller_dashboard.dart';

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

            final bool isCustomerMode = modeSnapshot.data ?? false;

            // 3. If User is Logged In -> Check Role in Firestore (REALTIME)
            User user = snapshot.data!;
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  // Get Role
                  var data = userSnapshot.data!.data() as Map<String, dynamic>;
                  String role = (data['role'] ?? 'customer').toString().toLowerCase().trim();
                  
                  // Debug Prints
                  print("AUTH WRAPPER: Found role '$role'");
                  if (isCustomerMode) print("AUTH WRAPPER: Forcing Customer Mode");
                  
                  // ROUTING LOGIC
                  // If 'Force Customer Mode' is ON, skip role checks and go to customer app
                  if (!isCustomerMode) {
                    if (role == 'admin') return const AdminWebLayout();
                    if (role == 'vendor') return const VendorDashboard();
                    if (role == 'rider') return const RiderDashboard();
                    if (role == 'seller') return const SellerDashboard();
                  }

                  // --- CUSTOMER LOGIC (Logged In) ---
                  return const PincodeGateScreen(); 
                }

                // Fallback (new user without role data yet) -> PincodeGate
                return const PincodeGateScreen();
              },
            );
          }
        );
      },
    );
  }
}
