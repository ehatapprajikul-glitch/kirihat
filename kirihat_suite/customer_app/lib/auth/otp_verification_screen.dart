import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import '../customer/onboarding/pincode_gate.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
  final VoidCallback? onLoginSuccess;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
    this.onLoginSuccess,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> with CodeAutoFill {
  final _otpController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  Timer? _timer;
  int _remainingSeconds = 600; // 10 minutes

  @override
  void initState() {
    super.initState();
    _startTimer();
    listenForCode();
  }

  @override
  void codeUpdated() {
    if (code != null && code!.isNotEmpty) {
      _otpController.text = code!;
      if (code!.length == 6) {
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
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      debugPrint('✅ OTP verified successfully: ${user.uid}');

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        // Critical: User record must exist before other ops might rely on it (though parallel is often fine, let's keep this critical step or verify safe parallelization. 
        // Actually, cart migration relies on UID, not necessarily the firestore doc existing, but safer to let user doc creation happen.
        // However, 'isNewUser' only covers creation. Let's optimize:
        await _createOrUpdateUser(user.uid, widget.phoneNumber);
      }

      debugPrint('🚀 Performing parallel login setup...');
      
      // Run these independent high-latency tasks in parallel
      await Future.wait([
        // Task 1: Migrate Guest Cart
        CartHelper.migrateGuestCartToFirestore(user.uid)
            .then((_) => debugPrint('✅ Cart Migrated'))
            .catchError((e) => debugPrint('⚠️ Cart Migration Warning: $e')),

        // Task 2: Set Session Mode
        SessionService().setCustomerMode(true)
            .then((_) => debugPrint('✅ Customer Mode Set')),
            
        // You could add more parallel tasks here if needed
      ]);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Invalid OTP. Please check and try again.';
          break;
        case 'session-expired':
          errorMessage = 'OTP expired. Please request a new one.';
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
  }

  Future<void> _verifyOTP() async {
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
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
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
          errorMessage = 'OTP expired. Please request a new one.';
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

  Future<void> _createOrUpdateUser(String uid, String phoneNumber) async {
    final userDoc = _firestore.collection('users').doc(uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'phone_number': phoneNumber,
        'role': 'customer',
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);
    listenForCode();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: widget.resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _verifyOTPWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.message ?? 'Failed to resend OTP'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _remainingSeconds = 600;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP resent successfully'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
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

