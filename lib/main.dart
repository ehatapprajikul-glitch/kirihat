import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Needed for restricting inputs to numbers

// Make sure these files exist in your project, or the code won't compile!
import 'firebase_options.dart';
import 'user_manager.dart';
import 'vendor_dashboard.dart';
import 'customer_shop.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure you have run 'flutterfire configure' to generate firebase_options.dart
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

// ---------------------------------------------------------
// 1. THE TRAFFIC CONTROLLER (AuthWrapper) - [FIXED]
// ---------------------------------------------------------
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // FIX 1: Check if Firebase is still loading the auth state
        // Prevents the Login Screen from "flashing" briefly on startup
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If not logged in, show Phone+PIN Login
        if (!snapshot.hasData) return const LoginScreen();

        // If logged in, CHECK ROLE from Firestore
        User user = snapshot.data!;

        // FIX 2: Safety check. If email is null (unlikely but possible), use UID
        String docId = user.email ?? user.uid;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(docId)
              .get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Default to Customer if no role is found
            String role = 'customer';
            if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
              Map<String, dynamic>? data =
                  roleSnapshot.data!.data() as Map<String, dynamic>?;
              role = data?['role'] ?? 'customer';
            }

            // ROUTING LOGIC
            if (role == 'admin') return const AdminDashboard();
            if (role == 'vendor') return const VendorPanel();
            if (role == 'rider') return const RiderPanel();
            return const CustomerShop();
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------
// 2. LOGIN SCREEN (Phone + PIN) - [UPDATED WITH RED ERROR]
// ---------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1. Create a GlobalKey to manage the Form
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    // 2. TRIGGER VALIDATION: This checks all fields before logging in
    if (!_formKey.currentState!.validate()) {
      // If validation fails (returns false), the red errors appear automatically.
      // We stop the login process here.
      return;
    }

    setState(() => _loading = true);

    String fakeEmail = "${_phoneController.text.trim()}@kirihat.com";
    String pin = _pinController.text.trim();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: fakeEmail,
        password: pin,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Failed: ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            // 3. Wrap everything in a Form widget using the key
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storefront, size: 80, color: Colors.green),
                  const SizedBox(height: 20),
                  const Text(
                    "Kiri Hat",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Village Market Link",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  // PHONE NUMBER FIELD (With Validation)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    // Blocks non-digits physically
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "Mobile Number",
                      prefixText: "+91 ",
                      border: OutlineInputBorder(),
                      counterText: "",
                      // Icon to make it look nice
                      prefixIcon: Icon(Icons.phone),
                    ),
                    // 4. THE VALIDATOR LOGIC
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter a number";
                      }
                      // Regex check: If it contains anything NOT 0-9
                      if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                        return "Put only numbers"; // <--- RED ERROR MESSAGE
                      }
                      if (value.length != 10) {
                        return "Number must be 10 digits";
                      }
                      return null; // valid
                    },
                  ),
                  const SizedBox(height: 15),

                  // PIN FIELD (With Validation)
                  TextFormField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "6-Digit PIN",
                      border: OutlineInputBorder(),
                      counterText: "",
                      prefixIcon: Icon(Icons.lock),
                    ),
                    // 4. THE VALIDATOR LOGIC
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter PIN";
                      }
                      if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                        return "Put only numbers"; // <--- RED ERROR MESSAGE
                      }
                      if (value.length != 6) {
                        return "PIN must be 6 digits";
                      }
                      return null; // valid
                    },
                  ),

                  const SizedBox(height: 20),
                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _login,
                            child: const Text(
                              "Login",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. ADMIN PANEL
// ---------------------------------------------------------
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin: Owner Panel"),
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
              "Welcome, Boss!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // Button 1: Hire Staff
            SizedBox(
              width: 250,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserManagerScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.people),
                label: const Text("Manage Users & Staff"),
              ),
            ),

            const SizedBox(height: 15),

            // Button 2: Orders
            const SizedBox(
              width: 250,
              height: 50,
              child: ElevatedButton(
                onPressed: null,
                child: Text("View Orders (Coming Soon)"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 4. VENDOR PANEL
// ---------------------------------------------------------
class VendorPanel extends StatelessWidget {
  const VendorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // Requires 'vendor_dashboard.dart' to exist!
    return const VendorDashboard();
  }
}

// ---------------------------------------------------------
// 5. RIDER PANEL
// ---------------------------------------------------------
class RiderPanel extends StatelessWidget {
  const RiderPanel({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rider: Van Route"),
        backgroundColor: Colors.blue[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: const Center(child: Text("Rider Map Loaded!")),
    );
  }
}

// 6. CUSTOMER SHOP (Updated)
class CustomerShop extends StatelessWidget {
  const CustomerShop({super.key});

  @override
  Widget build(BuildContext context) {
    // Points to the new file we just made
    return const CustomerMarket();
  }
}
