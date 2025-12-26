import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../customer/address_screen.dart';
import '../customer/customer_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // State
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

  // Email validation regex
  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  // Phone validation (Indian format: starts with 6-9, 10 digits)
  bool _isValidPhone(String phone) {
    return RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
  }

  Future<void> _submit() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      print("Form validation failed");
      return;
    }

    // Remove focus from input fields
    FocusScope.of(context).unfocus();

    // Set loading state
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        print("Attempting login...");

        // LOGIN
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        print("Login successful for user: ${userCredential.user?.email}");

        // Check if user document exists in Firestore
        if (userCredential.user != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

          print("User document exists: ${userDoc.exists}");

          if (!mounted) return;

          // Navigate based on whether user has completed profile
          if (userDoc.exists) {
            Map<String, dynamic>? userData =
                userDoc.data() as Map<String, dynamic>?;
            bool hasAddress = userData?['hasAddress'] ?? false;

            print("Has address: $hasAddress");

            if (hasAddress) {
              // User has completed profile, go to dashboard
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerDashboard(),
                ),
                (route) => false,
              );
            } else {
              // User needs to add address
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AddressScreen()),
                (route) => false,
              );
            }
          } else {
            // User document doesn't exist, go to address screen to complete profile
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const AddressScreen()),
              (route) => false,
            );
          }
        }
      } else {
        print("Attempting signup...");

        // SIGN UP
        UserCredential cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        print("Signup successful for user: ${cred.user?.email}");

        // Create user document in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
              'phone': _phoneController.text.trim(),
              'role': 'customer',
              'created_at': FieldValue.serverTimestamp(),
              'hasAddress': false,
            });

        print("User document created in Firestore");

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AddressScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException: ${e.code} - ${e.message}");

      if (!mounted) return;

      String errorMessage;

      switch (e.code) {
        case 'user-not-found':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Account not found. Please complete details to Sign Up.",
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          setState(() => _isLogin = false);
          return;

        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = "Incorrect password. Please try again.";
          break;

        case 'email-already-in-use':
          errorMessage = "This email is already registered. Please login.";
          break;

        case 'weak-password':
          errorMessage = "Password is too weak. Use at least 6 characters.";
          break;

        case 'invalid-email':
          errorMessage = "Invalid email format.";
          break;

        case 'network-request-failed':
          errorMessage = "Network error. Please check your connection.";
          break;

        case 'too-many-requests':
          errorMessage = "Too many attempts. Please try again later.";
          break;

        default:
          errorMessage =
              e.message ?? "Authentication failed. Please try again.";
      }

      _showError(errorMessage);
    } catch (e) {
      print("General exception: $e");

      if (mounted) {
        _showError("An unexpected error occurred: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _errorRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError("Please enter your email address first");
      return;
    }

    if (!_isValidEmail(email)) {
      _showError("Please enter a valid email address");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password reset link sent to your email!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'user-not-found') {
          _showError("No account found with this email");
        } else {
          _showError(e.message ?? "Failed to send reset email");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 768;
            if (isDesktop) {
              return _buildDesktopLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }

  // DESKTOP LAYOUT
  Widget _buildDesktopLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 600),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // LEFT PANEL
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: _brandColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLogin ? "Login" : "Looks like you're new here!",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isLogin
                            ? "Get access to your Orders, Wishlist and Recommendations"
                            : "Sign up to get started",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 120,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // RIGHT PANEL
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: _buildFormContent(),
            ),
          ),
        ],
      ),
    );
  }

  // MOBILE LAYOUT
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: _buildFormContent(),
        ),
      ),
    );
  }

  // FORM CONTENT
  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mobile Header
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 768) {
                return Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 60,
                      color: _brandColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Kiri Hat",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _brandColor,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _isLogin ? "Login" : "Sign Up",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? "Enter your email to continue"
                          : "Create your account",
                      style: TextStyle(fontSize: 14, color: _textGrey),
                    ),
                    const SizedBox(height: 30),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Name field (Sign Up only)
          if (!_isLogin) ...[
            _buildInputField(
              controller: _nameController,
              label: "Full Name",
              hint: "Enter your full name",
              icon: Icons.person_outline,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return "Full name is required";
                }
                if (val.trim().length < 3) {
                  return "Name must be at least 3 characters";
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],

          // Phone field (Sign Up only)
          if (!_isLogin) ...[
            _buildInputField(
              controller: _phoneController,
              label: "Mobile Number",
              hint: "10-digit mobile number",
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return "Mobile number is required";
                }
                if (!_isValidPhone(val.trim())) {
                  return "Enter a valid 10-digit mobile number";
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],

          // Email field
          _buildInputField(
            controller: _emailController,
            label: "Email",
            hint: "Enter your email",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return "Email is required";
              }
              if (!_isValidEmail(val.trim())) {
                return "Enter a valid email address";
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Password field
          _buildInputField(
            controller: _passwordController,
            label: "Password",
            hint: "Enter your password",
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return "Password is required";
              }
              if (val.length < 6) {
                return "Password must be at least 6 characters";
              }
              return null;
            },
          ),

          // Forgot Password (Login only)
          if (_isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: _brandColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          // Terms text
          Text(
            "By continuing, you agree to our Terms of Use and Privacy Policy",
            style: TextStyle(color: _textGrey, fontSize: 11),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _isLogin ? "Login" : "Sign Up",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Toggle Login/Signup
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                      _formKey.currentState?.reset();
                    },
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: _textDark),
                  children: [
                    TextSpan(
                      text: _isLogin
                          ? "New to Kiri Hat? "
                          : "Already have an account? ",
                    ),
                    TextSpan(
                      text: _isLogin ? "Create an account" : "Login",
                      style: TextStyle(
                        color: _brandColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CUSTOM INPUT FIELD
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: TextStyle(color: _textDark, fontSize: 15),
      cursorColor: _brandColor,
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: _textGrey.withOpacity(0.6), fontSize: 14),
        labelStyle: TextStyle(color: _textGrey, fontSize: 14),
        floatingLabelStyle: TextStyle(color: _brandColor, fontSize: 14),
        prefixIcon: Icon(icon, color: _textGrey, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: _textGrey,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: _borderGrey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: _borderGrey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: _brandColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: _errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: _errorRed, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}
