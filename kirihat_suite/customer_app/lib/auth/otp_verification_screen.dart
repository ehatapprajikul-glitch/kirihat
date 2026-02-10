import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import '../customer/onboarding/pincode_gate.dart';
import '../customer/onboarding/account_setup_screen.dart';
import '../customer/customer_dashboard.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:kirihat_core/services/user_service.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String? verificationId;
  final int? resendToken;
  final VoidCallback? onLoginSuccess;
  final bool isNestedFlow;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.verificationId,
    this.resendToken,
    this.onLoginSuccess,
    this.isNestedFlow = false,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> with CodeAutoFill {
  final _otpController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _signInComplete = false; // Guard against double sign-in
  Timer? _timer;
  int _remainingSeconds = 60; // Standard 60s for resend
  String? _currentVerificationId; // Mutable to handle resend

  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    
    // If we have a verification ID, start timer and listen
    if (_currentVerificationId != null) {
      _startTimer();
      listenForCode();
    } else {
      // Otherwise, we need to send the code first
      _sendOTP();
    }
  }

  @override
  void codeUpdated() {
    if (code != null && code!.isNotEmpty) {
      _otpController.text = code!;
      if (code!.length == 6 && !_signInComplete) {
        _verifyOTP();
      }
    }
  }

  @override
  void dispose() {
    cancel();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _verifyOTPWithCredential(PhoneAuthCredential credential) async {
    // Guard: Already signed in (e.g., auto-verification completed first)
    if (_signInComplete) {
      debugPrint('⚠️ Sign-in already complete, skipping duplicate');
      return;
    }
    
    // Guard: User already signed in from another path
    if (FirebaseAuth.instance.currentUser != null) {
      debugPrint('✅ User already signed in, handling navigation');
      _signInComplete = true;
      await _handlePostLoginNavigation(false); // Existing user
      return;
    }
    
    try {
      _signInComplete = true; // Set BEFORE async call to prevent race
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      debugPrint('✅ OTP verified successfully: ${user.uid}');
      
      // Check if user document exists in Firestore to determine true 'isNewUser' status
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final bool isNewUser = !userDoc.exists;

      // Prepare parallel tasks for lightning speed
      final List<Future> setupTasks = [];

      // Task 1: Create/Update User (Optimized)
      if (isNewUser) {
        // New user: Just set the doc, no need to read first
        setupTasks.add(_firestore.collection('users').doc(user.uid).set({
          'phone': widget.phoneNumber,        // Standard field used by profile
          'phone_number': widget.phoneNumber, // Legacy support
          'role': 'customer',
          'created_at': FieldValue.serverTimestamp(),
        }));
      }

      // Task 2: Migrate Guest Cart
      setupTasks.add(CartHelper.migrateGuestCartToFirestore(user.uid));

      // Task 3: Set Session Mode
      setupTasks.add(SessionService().setCustomerMode(true));

      // Execute all setup tasks in parallel
      await Future.wait(setupTasks);
      debugPrint('🚀 Login setup complete (Parallel)');

      if (mounted) {
        await _handlePostLoginNavigation(isNewUser);
      }
    } on FirebaseAuthException catch (e) {
      _signInComplete = false; // Reset on failure
      String errorMessage;
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Invalid OTP. Please check and try again.';
          break;
        case 'session-expired':
          errorMessage = 'The sms code has expired. Please re-send the verification code to try again.';
          break;
        default:
          errorMessage = e.message ?? 'Verification failed';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _signInComplete = false; // Reset on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
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
    
    debugPrint('📋 _handlePostLoginNavigation: Profile complete: $isProfileComplete, isNewUser: $isNewUser, isNestedFlow: ${widget.isNestedFlow}');
    
    if (!mounted) {
       debugPrint('🛑 _handlePostLoginNavigation: Context not mounted, aborting navigation.');
       return;
    }
    
    if (!isProfileComplete) {
      // Go to account setup
      // IMPORTANT: If we have a success callback (from Checkout/Profile), we must NOT clear stack.
      // We push Account Setup on top, so when it finishes (pops), we are back here.
      if (widget.isNestedFlow) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountSetupScreen(isNestedFlow: true),
          ),
        );
        // After returning from setup flow, we assume profile is now complete.
        // We return 'true' to signal success to PhoneAuthScreen, which will handle the final pop.
        if (mounted) {
           Navigator.pop(context, true);
        }
      } else {
        // Standard Onboarding Flow: Clear stack and go to Setup -> Address -> Dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AccountSetupScreen()),
          (route) => false,
        );
      }
    } else {
      // Profile is complete
      if (widget.isNestedFlow) {
        // Return 'true' to signal success to PhoneAuthScreen
        Navigator.pop(context, true);
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

  Future<void> _verifyOTP() async {
    // Guard: Already signed in
    if (_signInComplete || FirebaseAuth.instance.currentUser != null) {
      debugPrint('✅ Already signed in, handling navigation');
      if (!_signInComplete) {
        _signInComplete = true;
        await _handlePostLoginNavigation(false);
      }
      return;
    }
    
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter complete OTP'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_currentVerificationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for the code to be sent'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId!, // Use mutable verificationId
        smsCode: _otpController.text.trim(),
      );

      await _verifyOTPWithCredential(credential);

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Invalid OTP. Please check and try again.';
          break;
        case 'session-expired':
          errorMessage = 'The sms code has expired. Please re-send the verification code to try again.';
          break;
        default:
          errorMessage = e.message ?? 'Verification failed';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }



  Future<void> _sendOTP() async {
    // Reset state for sending
    setState(() {
      _isLoading = true;
      _remainingSeconds = 60; // Reset timer for new send
    });
    
    listenForCode();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: widget.resendToken,
        timeout: const Duration(seconds: 60),
        
        // Auto-verification (Android only)
        verificationCompleted: (PhoneAuthCredential credential) async {
             debugPrint('✅ Auto-verification completed');
             await _verifyOTPWithCredential(credential);
        },
        
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Verification failed: ${e.code} - ${e.message}');
          if (mounted) {
            String message = e.message ?? 'Failed to send OTP';
             if (e.code == 'invalid-phone-number') {
                message = 'The phone number is invalid.';
             }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
            
            // If initial send failed, we might want to pop back
            if (_currentVerificationId == null) {
               // Maybe give them a button to retry instead of popping immediately?
               // For now, let's just leave them on screen to try "Resend"
            }
          }
           setState(() => _isLoading = false);
        },
        
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ OTP sent to ${widget.phoneNumber}');
          if (mounted) {
            setState(() {
              _currentVerificationId = verificationId; 
              _remainingSeconds = 60;
              _signInComplete = false;
              _isLoading = false;
            });
            
            // Only start timer if not already running
            if (_timer == null || !_timer!.isActive) {
               _startTimer();
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP sent successfully'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏱️ Auto-retrieval timeout');
          if (mounted) {
            setState(() => _currentVerificationId = verificationId);
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error sending OTP: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    await _sendOTP();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A1A1A),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: const Color(0xFF0D9759), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9759).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFF0D9759).withOpacity(0.05),
        border: Border.all(color: const Color(0xFF0D9759).withOpacity(0.5)),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Back Button
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

                // Hero Icon
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
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
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9759).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 40,
                          color: Color(0xFF0D9759),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Title
                const Text(
                  'Verify it\'s you',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
                    children: [
                      const TextSpan(text: 'We\'ve sent a 6-digit code to '),
                      TextSpan(
                        text: widget.phoneNumber,
                        style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Edit phone number',
                    style: TextStyle(
                      color: Color(0xFF0D9759),
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // OTP Input
                Center(
                  child: Pinput(
                    controller: _otpController,
                    length: 6,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    submittedPinTheme: submittedPinTheme,
                    onCompleted: (pin) => _verifyOTP(),
                    showCursor: true,
                    hapticFeedbackType: HapticFeedbackType.lightImpact,
                    separatorBuilder: (index) => const SizedBox(width: 8),
                  ),
                ),

                const SizedBox(height: 40),

                // Timer & Resend
                Center(
                  child: Column(
                    children: [
                      if (_remainingSeconds > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer_outlined, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Resend code in ${_formatTime(_remainingSeconds)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      else
                        TextButton(
                          onPressed: _isLoading ? null : _resendOTP,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0D9759),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF0D9759), width: 1.5),
                            ),
                          ),
                          child: const Text(
                            'Resend Code',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Verify Button
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
                      onPressed: _isLoading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9759),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                          : const Text(
                              'Verify & Continue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

