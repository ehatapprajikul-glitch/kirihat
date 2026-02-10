import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

// IMPORTS FOR PORTAL ROLES
import '../vendor/vendor_dashboard.dart';
import '../admin/admin_web_layout.dart';
import '../vendor/vendor_dashboard.dart';
import '../admin/admin_web_layout.dart';

class LoginScreen extends StatefulWidget {
  final String targetRole; // 'admin' or 'vendor'

  const LoginScreen({
    super.key, 
    this.targetRole = 'admin', // Default fallback
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Theme Constants
  late Color _brandColor;
  late Color _buttonColor;
  late String _portalTitle;
  late IconData _portalIcon;

  final Color _textDark = const Color(0xFF212121);
  final Color _textGrey = const Color(0xFF878787);
  final Color _errorRed = const Color(0xFFFF0000);

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeTheme();
  }

  void _initializeTheme() {
    switch (widget.targetRole) {
      case 'vendor':
        _brandColor = Colors.blue;
        _buttonColor = Colors.blue.shade700;
        _portalTitle = 'Vendor Portal';
        _portalIcon = Icons.store;
        break;
      case 'admin':
      default:
        _brandColor = Colors.purple;
        _buttonColor = Colors.purple.shade700;
        _portalTitle = 'Admin Console';
        _portalIcon = Icons.admin_panel_settings;
        break;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  // --- ROUTING LOGIC (STRICT) ---
  void _navigateBasedOnRole(String userRoleRaw, BuildContext context) {
    String userRole = userRoleRaw.toLowerCase().trim();
    String targetRole = widget.targetRole.toLowerCase().trim();

    // STRICT VALIDATION: User role MUST match the Portal they are trying to access
    if (userRole == targetRole) {
       Navigator.pushAndRemoveUntil(
         context,
         MaterialPageRoute(builder: (context) => const AuthWrapper()),
         (route) => false,
       );
    } else {
       // Optional: Allow Admin to access anywhere
       if (userRole == 'admin') {
          Navigator.pushAndRemoveUntil(
           context,
           MaterialPageRoute(builder: (context) => const AuthWrapper()),
           (route) => false,
         );
         return;
       } 
       
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text("Access Denied: You are a '$userRole', but this is the '$targetRole' portal."), 
           backgroundColor: Colors.red,
           duration: const Duration(seconds: 4),
         ),
       );
       FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      // --- LOGIN ---
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        String uid = userCredential.user!.uid;
        
        // FETCH USER DOC
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (!mounted) return;

        if (userDoc.exists) {
          var data = userDoc.data() as Map<String, dynamic>;
          String role = data['role'] ?? 'customer';
          _navigateBasedOnRole(role, context);
        } else {
          // User exists in Auth but NOT in Database.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User profile not found."), backgroundColor: Colors.red),
          );
          FirebaseAuth.instance.signOut();
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "Account not found.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password.";
          break;
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
          errorMessage = "Invalid email or password.";
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
                      Text("Login",
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 20),
                      Text(
                          "Access your $_portalTitle.",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withAlpha(230))),
                    ],
                  ),
                  Icon(_portalIcon,
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            Icon(_portalIcon, size: 60, color: _brandColor),
            const SizedBox(height: 10),
            Center(
                child: Text(_portalTitle,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _brandColor))),
            const SizedBox(height: 30),
            Text("Login",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textDark)),
            const SizedBox(height: 30),
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
                  : const Text("Login",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          // REMOVED SIGN UP TOGGLE
          const SizedBox(height: 24),
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
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _brandColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}
