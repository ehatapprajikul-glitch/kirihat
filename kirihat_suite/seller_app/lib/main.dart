import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Screens
import 'auth/login_screen.dart';
import 'auth/seller_registration_screen.dart';
import 'auth/approval_waiting_screen.dart';
import 'seller/seller_dashboard.dart';
import 'auth/verify_email_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SellerApp());
}

class SellerApp extends StatelessWidget {
  const SellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kirihat Seller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9759)), // Kirihat Green
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
          return const LoginScreen();
        }

        User user = snapshot.data!;
        
        // CHECK EMAIL VERIFICATION (bypass for seller@kirihat.com)
        final bypassEmails = ['seller@kirihat.com'];
        if (!user.emailVerified && !bypassEmails.contains(user.email?.toLowerCase())) {
          return const VerifyEmailScreen();
        }

        // Listen to User Doc
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              var userData = userSnapshot.data!.data() as Map<String, dynamic>;
              String role = (userData['role'] ?? 'customer').toString().toLowerCase().trim();
              
              if (role != 'seller') {
                return _buildUnauthorizedScreen(role);
              }

              // Bypass for testing - seller@kirihat.com goes directly to dashboard
              if (user.email?.toLowerCase() == 'seller@kirihat.com') {
                return const SellerDashboard();
              }

              // Check if seller profile is linked
              String? sellerId = userData['seller_id'];
              
              if (sellerId == null || sellerId.isEmpty) {
                // Seller account created but profile not setup
                return const SellerRegistrationScreen();
              }

              // Listen to Seller Doc for status
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('sellers').doc(sellerId).snapshots(),
                builder: (context, sellerSnapshot) {
                  if (sellerSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }

                  if (sellerSnapshot.hasData && sellerSnapshot.data!.exists) {
                    var sellerData = sellerSnapshot.data!.data() as Map<String, dynamic>;
                    String status = (sellerData['status'] ?? 'pending').toString().toLowerCase();

                    if (status == 'active') {
                      return const SellerDashboard();
                    } else if (status == 'rejected') {
                       return const ApprovalWaitingScreen(); 
                    } else {
                      return const ApprovalWaitingScreen();
                    }
                  }
                  
                  return const SellerRegistrationScreen();
                },
              );
            }
            
             return const LoginScreen(); 
          },
        );
      },
    );
  }

  Widget _buildUnauthorizedScreen(String role) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                "Unauthorized Access",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                "You are logged in as a '$role', but this app is for Sellers only.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
