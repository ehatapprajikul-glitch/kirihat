import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// IMPORTS FOR ALL DASHBOARDS
import '../customer/customer_dashboard.dart';
import '../vendor/vendor_dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../rider/rider_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Brand Colors
  final Color _brandColor = Colors.green;
  final Color _buttonColor = Colors.green.shade600;
  final Color _textDark = const Color(0xFF212121);
  final Color _textGrey = const Color(0xFF878787);
  final Color _borderGrey = const Color(0xFFE0E0E0);
  final Color _errorRed = const Color(0xFFFF0000);

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  bool _isValidPhone(String phone) => RegExp(r'^[6-9]\d{9}$').hasMatch(phone);

  // --- ROUTING LOGIC (Fixed) ---
  void _navigateBasedOnRole(String roleRaw, BuildContext context) {
    Widget targetScreen;

    // FIX: Normalize the string to handle "Vendor", "vendor ", etc.
    String role = roleRaw.toLowerCase().trim();

    print("NAVIGATION: Detected cleaned role -> '$role'");

    switch (role) {
      case 'vendor':
        targetScreen = const VendorDashboard();
        break;
      case 'admin':
        targetScreen = const AdminDashboard();
        break;
      case 'rider':
        targetScreen = const RiderDashboard();
        break;
      case 'customer':
        targetScreen = const CustomerDashboard();
        break;
      default:
        print(
            "NAVIGATION WARNING: Unknown role '$role', defaulting to Customer.");
        targetScreen = const CustomerDashboard();
        break;
    }

    // Show a quick message so you know what happened (Remove this line later if you want)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text("Welcome! Logging in as: ${role.toUpperCase()}"),
          duration: const Duration(seconds: 1)),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // --- LOGIN ---
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (userCredential.user != null) {
          String uid = userCredential.user!.uid;
          print("DEBUG: Auth Successful. UID: $uid");

          // FETCH USER DOC
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          if (!mounted) return;

          if (userDoc.exists) {
            // FIX: Safely read the role
            var data = userDoc.data() as Map<String, dynamic>;
            String role = data['role'] ?? 'customer';

            print("DEBUG: Firestore Document Found. Raw Role: '$role'");
            _navigateBasedOnRole(role, context);
          } else {
            // CRITICAL FIX: User exists in Auth but NOT in Database.
            // This happens if you manually created user in Auth tab but forgot Firestore tab.
            print(
                "DEBUG: User missing in Firestore! Creating default customer entry.");

            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'email': _emailController.text.trim(),
              'role': 'customer', // Defaulting to customer for safety
              'created_at': FieldValue.serverTimestamp(),
              'hasAddress': false,
            });

            _navigateBasedOnRole('customer', context);
          }
        }
      } else {
        // --- SIGN UP (Always Customer) ---
        UserCredential cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': 'customer', // Always Customer on Sign Up
          'created_at': FieldValue.serverTimestamp(),
          'hasAddress': false,
        });

        if (mounted) {
          _navigateBasedOnRole('customer', context);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Account not found. Switching to Sign Up..."),
              backgroundColor: Colors.orange));
          setState(() => _isLogin = false);
          return;
        case 'wrong-password':
          errorMessage = "Incorrect password.";
          break;
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
          errorMessage = "Invalid email or password. If new, please Sign Up.";
          break;
        case 'email-already-in-use':
          errorMessage = "Email already registered. Please login.";
          break;
        default:
          errorMessage = e.message ?? "Authentication failed.";
      }
      _showError(errorMessage);
    } catch (e) {
      if (mounted) _showError("Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _errorRed));
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) {
      _showError("Enter a valid email first");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Reset link sent!"), backgroundColor: Colors.green));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(e.message ?? "Failed to send reset email");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return constraints.maxWidth > 768
                ? _buildDesktopLayout()
                : _buildMobileLayout();
          },
        ),
      ),
    );
  }

  // --- UI WIDGETS ---

  Widget _buildDesktopLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 600),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              color: _brandColor,
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isLogin ? "Login" : "Welcome!",
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 20),
                      Text(
                          _isLogin
                              ? "Access your dashboard."
                              : "Sign up to start shopping.",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withAlpha(230))),
                    ],
                  ),
                  Icon(Icons.shopping_bag_outlined,
                      size: 120, color: Colors.white.withAlpha(77)),
                ],
              ),
            ),
          ),
          Expanded(
              flex: 6,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: _buildFormContent())),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: _buildFormContent())),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.of(context).size.width < 768) ...[
            Icon(Icons.shopping_bag_outlined, size: 60, color: _brandColor),
            const SizedBox(height: 10),
            Center(
                child: Text("Kiri Hat",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _brandColor))),
            const SizedBox(height: 30),
            Text(_isLogin ? "Login" : "Sign Up",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textDark)),
            const SizedBox(height: 30),
          ],
          if (!_isLogin) ...[
            _buildInputField(
                controller: _nameController,
                label: "Full Name",
                icon: Icons.person_outline,
                validator: (val) =>
                    (val == null || val.length < 3) ? "Name required" : null),
            const SizedBox(height: 20),
            _buildInputField(
                controller: _phoneController,
                label: "Mobile Number",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (val) => (val == null || !_isValidPhone(val))
                    ? "Valid phone required"
                    : null),
            const SizedBox(height: 20),
          ],
          _buildInputField(
              controller: _emailController,
              label: "Email",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (val) => (val == null || !_isValidEmail(val))
                  ? "Valid email required"
                  : null),
          const SizedBox(height: 20),
          _buildInputField(
              controller: _passwordController,
              label: "Password",
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (val) => (val == null || val.length < 6)
                  ? "Min 6 chars required"
                  : null),
          if (_isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: _handleForgotPassword,
                  child: Text("Forgot Password?",
                      style: TextStyle(
                          color: _brandColor, fontWeight: FontWeight.w600))),
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2))),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(_isLogin ? "Login" : "Sign Up",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() => _isLogin = !_isLogin);
                      _formKey.currentState?.reset();
                    },
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: _textDark),
                  children: [
                    TextSpan(
                        text: _isLogin
                            ? "New to Kiri Hat? "
                            : "Already have an account? "),
                    TextSpan(
                        text: _isLogin ? "Create an account" : "Login",
                        style: TextStyle(
                            color: _brandColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool isPassword = false,
      TextInputType? keyboardType,
      int? maxLength,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _textGrey, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: _textGrey),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword))
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
      validator: validator,
    );
  }
}
