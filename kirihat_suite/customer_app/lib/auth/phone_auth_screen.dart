import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../customer/onboarding/pincode_gate.dart';
import '../customer/onboarding/account_setup_screen.dart';
import '../customer/customer_dashboard.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:kirihat_core/services/user_service.dart';
import 'otp_verification_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kirihat_core/utils/policy_links.dart';

class PhoneAuthScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess; // Optional callback after successful login
  final bool isNestedFlow; // New Flag: Explicitly handle nested navigation
  
  const PhoneAuthScreen({
    super.key, 
    this.onLoginSuccess,
    this.isNestedFlow = false,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final phoneNumber = '+91${_phoneController.text.trim()}';

    // Navigate immediately to OTP Verification Screen
    // The screen itself will handle sending the OTP
    if (mounted) {
       setState(() => _isLoading = false);
       
       final result = await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => OTPVerificationScreen(
            phoneNumber: phoneNumber,
            verificationId: null, // Let screen handle it
            onLoginSuccess: widget.onLoginSuccess,
            isNestedFlow: widget.isNestedFlow,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutQuart;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );

      // Handle success returns from OTP screen
      if (result == true && mounted) {
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        }
        // Always pop to return to previous screen (Checkout/Profile)
        // Since we are in a nested flow or handling a result, we must close this screen.
        Navigator.pop(context);
      }
    }
  }
  
  bool _isSigningIn = false;

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    if (_isSigningIn) return;
    
    // Check if user is already signed in to avoid double-processing
    if (FirebaseAuth.instance.currentUser != null) {
       debugPrint('✅ Already signed in, skipping credential sign-in');
       await _handlePostLoginNavigation(false);
       return;
    }

    setState(() => _isSigningIn = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;
      
      debugPrint('✅ Signed in: ${user.uid}');
      
      // Check if user document exists in Firestore to determine true 'isNewUser' status
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final bool isNewUser = !userDoc.exists;

      // Prepare parallel tasks for lightning speed
      final List<Future> setupTasks = [];

      // Task 1: Create/Update User (Only if new)
      if (isNewUser) {
         setupTasks.add(FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'phone': user.phoneNumber,          // Standard field
          'phone_number': user.phoneNumber,   // Legacy support
          'role': 'customer',
          'created_at': FieldValue.serverTimestamp(),
        }));
      }

      // We should also run Cart Migration here because this is the auto-verification path!
      setupTasks.add(CartHelper.migrateGuestCartToFirestore(user.uid));
      setupTasks.add(SessionService().setCustomerMode(true));

      await Future.wait(setupTasks);
      
      if (mounted) {
        await _handlePostLoginNavigation(isNewUser);
      }
    } catch (e) {
      debugPrint('❌ Sign-in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Handles navigation after successful login based on profile completion
  Future<void> _handlePostLoginNavigation(bool isNewUser) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    
    // Check if profile is complete (has name, gender, and address)
    final isProfileComplete = await UserService().checkProfileCompletionWithCache(user.uid);
    
    debugPrint('📋 Profile complete: $isProfileComplete, isNewUser: $isNewUser');
    
    if (!mounted) return;
    
    if (!isProfileComplete) {
      // Go to account setup
      if (widget.onLoginSuccess != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AccountSetupScreen(isNestedFlow: true),
          ),
        );
         if (mounted && widget.onLoginSuccess != null) {
           widget.onLoginSuccess!();
        }
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AccountSetupScreen()),
          (route) => false,
        );
      }
    } else {
      // Profile is complete
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        // Go to main dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerDashboard()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D9759).withOpacity(0.05),
              Colors.white,
              const Color(0xFF0D9759).withOpacity(0.02),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Back Button
                  if (Navigator.canPop(context))
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
                      ),
                    ),
                  
                  const SizedBox(height: 40),

                  // Hero Icon / Image
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9759).withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9759).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(25.0),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),

                  // Header Section
                  const Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login to your Kirihat account using your mobile number',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Label
                  Text(
                    'Mobile Number',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Premium Input Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9759).withOpacity(0.05),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '🇮🇳',
                                style: TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+91',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              hintText: '00000 00000',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                letterSpacing: 2,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              counterText: '',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter number';
                              if (value.length != 10) return 'Invalid length';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Dynamic Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9759).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOTP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9759),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 24, 
                                    height: 24, 
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  ),
                                  SizedBox(width: 12),
                                  Text("Sending...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Get Verification Code',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.arrow_forward_rounded, color: Colors.white.withOpacity(0.8)),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Footer - Policy
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
                          children: [
                            const TextSpan(text: 'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  launchUrl(Uri.parse(PolicyLinks.termsAndConditions));
                                },
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  launchUrl(Uri.parse(PolicyLinks.privacyPolicy));
                                },
                            ),
                          ],
                        ),
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

