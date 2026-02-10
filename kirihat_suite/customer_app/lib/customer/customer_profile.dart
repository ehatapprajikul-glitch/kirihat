import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart'; // Import AuthWrapper
import 'customer_orders.dart';
import 'manage_addresses.dart';
import 'wishlist_screen.dart';
import '../auth/phone_auth_screen.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kirihat_core/utils/policy_links.dart';
import 'delete_account_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  final bool openEditProfile;

  const CustomerProfileScreen({super.key, this.openEditProfile = false});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  static DateTime? _lastResetTime;

  // Enhanced color scheme
  static const Color primaryGreen = Color(0xFF0D9759);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF087F43);
  static const Color accentGreen = Color(0xFFE8F5E9);
  static const Color cardBackground = Colors.white;

  @override
  void initState() {
    super.initState();
    if (widget.openEditProfile) {
      _fetchAndOpenEditDialog();
    }
  }

  Future<void> _fetchAndOpenEditDialog() async {
    if (user == null) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    try {
      var snapshot = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      Map<String, dynamic> data = snapshot.exists ? (snapshot.data() ?? {}) : {};
      
      if (mounted) {
        _showEditProfileDialog(data);
      }
    } catch (e) {
      debugPrint("Error opening profile dialog: $e");
    }
  }

  // --- 1. EDIT PROFILE DIALOG (Enhanced Design) ---
  void _showEditProfileDialog(Map<String, dynamic> currentData) {
    final nameController = TextEditingController(text: currentData['name'] ?? '');

    String? rawGender = currentData['gender'];
    String? selectedGender;
    final List<String> genderOptions = ["Male", "Female", "Other"];

    if (rawGender != null && rawGender.isNotEmpty) {
      String normalized = rawGender[0].toUpperCase() + rawGender.substring(1).toLowerCase();
      if (genderOptions.contains(normalized)) {
        selectedGender = normalized;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, accentGreen.withOpacity(0.3)],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: primaryGreen,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Edit Personal Info",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: darkGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Update your profile information",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Name Field
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            labelStyle: const TextStyle(color: primaryGreen),
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: primaryGreen),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: primaryGreen, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Gender Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedGender,
                          decoration: InputDecoration(
                            labelText: "Gender",
                            labelStyle: const TextStyle(color: primaryGreen),
                            prefixIcon: const Icon(Icons.wc_rounded, color: primaryGreen),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: primaryGreen, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: genderOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              selectedGender = newValue;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Action Buttons
                        Row(
                          children: [
                            if (!isLoading)
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            if (!isLoading) const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        if (nameController.text.trim().isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Name cannot be empty"),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        setDialogState(() => isLoading = true);

                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user!.uid)
                                              .set({
                                            'name': nameController.text.trim(),
                                            'gender': selectedGender ?? "Not Specified",
                                          }, SetOptions(merge: true));
                                          
                                          if (mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text("Profile updated successfully!"),
                                                backgroundColor: primaryGreen,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setDialogState(() => isLoading = false);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Error saving profile: $e"),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Save Changes",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 2. CHANGE PASSWORD ---
  void _changePassword() {
    if (user?.email == null) return;

    if (_lastResetTime != null) {
      final difference = DateTime.now().difference(_lastResetTime!);
      if (difference.inMinutes < 5) {
        int remaining = 5 - difference.inMinutes;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Please wait $remaining minutes before requesting another link."),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    }

    FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
    _lastResetTime = DateTime.now();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, color: primaryGreen, size: 50),
            ),
            const SizedBox(height: 16),
            const Text("Email Sent!", style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Text(
            "Reset link sent to ${user!.email}.\n\nCheck your inbox (and spam folder). Link expires in 1 hour.",
            textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(c),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("OK"),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. RAISE CALLBACK REQUEST ---
  Future<void> _raiseCallbackRequest() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final reasonController = TextEditingController();
    final messageController = TextEditingController();
    
    var userData = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (userData.exists) {
      var data = userData.data()!;
      nameController.text = data['name'] ?? '';
      phoneController.text = data['phone'] ?? user!.phoneNumber ?? '';
    }

    String selectedReason = 'General Inquiry';
    
    bool? submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, accentGreen.withOpacity(0.2)],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryGreen, lightGreen],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryGreen.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.headset_mic_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Request Callback',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: darkGreen,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'We\'ll call you within 12 hours',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context, false),
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Name Field
                        TextField(
                          controller: nameController,
                          decoration: _buildInputDecoration(
                            'Your Name *',
                            Icons.person_rounded,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Phone Field
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _buildInputDecoration(
                            'Phone Number *',
                            Icons.phone_rounded,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Reason Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedReason,
                          decoration: _buildInputDecoration(
                            'Reason for Callback',
                            Icons.help_outline_rounded,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'General Inquiry', child: Text('General Inquiry')),
                            DropdownMenuItem(value: 'Order Issue', child: Text('Order Issue')),
                            DropdownMenuItem(value: 'Product Question', child: Text('Product Question')),
                            DropdownMenuItem(value: 'Payment Issue', child: Text('Payment Issue')),
                            DropdownMenuItem(value: 'Delivery Issue', child: Text('Delivery Issue')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedReason = value!;
                            });
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Message Field
                        TextField(
                          controller: messageController,
                          maxLines: 3,
                          decoration: _buildInputDecoration(
                            'Message (Optional)',
                            Icons.message_rounded,
                            hintText: 'Tell us how we can help you...',
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty || 
                                  phoneController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill in all required fields'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              
                              var existing = await FirebaseFirestore.instance
                                  .collection('callback_requests')
                                  .where('user_id', isEqualTo: user!.uid)
                                  .where('status', isEqualTo: 'pending')
                                  .get();
                                  
                              if (existing.docs.isNotEmpty) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('You already have a pending callback request'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  Navigator.pop(context, false);
                                }
                                return;
                              }
                              
                              await FirebaseFirestore.instance.collection('callback_requests').add({
                                'user_id': user!.uid,
                                'customer_name': nameController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'reason': selectedReason,
                                'message': messageController.text.trim(),
                                'status': 'pending',
                                'is_priority': false,
                                'created_at': FieldValue.serverTimestamp(),
                              });
                              
                              if (context.mounted) {
                                Navigator.pop(context, true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: primaryGreen.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'SUBMIT REQUEST',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
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
          },
        );
      },
    );
    
    if (submitted == true && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen.withOpacity(0.1), accentGreen],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: primaryGreen,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Submitted!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our team will call you within 12 hours',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      );
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: primaryGreen),
      hintText: hintText,
      prefixIcon: Icon(icon, color: primaryGreen),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  // --- 4. LOGOUT ---
  void _logout() async {
    await SessionService().setCustomerMode(false);
    
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()), 
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user != null) {
        print('DEBUG PROFILE: Email=${user!.email}, Phone=${user!.phoneNumber}');
        print('DEBUG PROFILE: Providers=${user!.providerData.map((e) => e.providerId).toList()}');
    }
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("My Profile"),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: accentGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline_rounded, size: 80, color: primaryGreen),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Login to View Profile",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: darkGreen),
                ),
                const SizedBox(height: 12),
                Text(
                  "Access your profile, orders, and saved addresses",
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [primaryGreen, lightGreen],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PhoneAuthScreen(
                              onLoginSuccess: () {
                                // Pop the auth screen and force rebuild
                                Navigator.pop(context);
                                setState(() {}); 
                              },
                            ),
                          ),
                        );
                      },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text("LOGIN",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: darkGreen,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }
          var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // --- A. PROFILE HEADER (Enhanced) ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryGreen, lightGreen],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: Text(
                            (data['name'] ?? "U").substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name'] ?? "User",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (user!.email != null && user!.email!.isNotEmpty) 
                                  ? user!.email! 
                                  : (user!.phoneNumber ?? ""),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            if (data['gender'] != null)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  data['gender'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit_rounded, color: primaryGreen),
                          onPressed: () => _showEditProfileDialog(data),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- B. ACCOUNT ACTIONS ---
                _buildSectionTitle("My Account"),
                _buildMenuCard([
                  _buildMenuItem(Icons.shopping_bag_rounded, "My Orders", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CustomerOrdersScreen()));
                  }),
                  _buildMenuItem(Icons.favorite_rounded, "My Wishlist", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WishlistScreen()));
                  }),
                  _buildMenuItem(Icons.location_on_rounded, "Manage Addresses",
                      () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManageAddressesScreen()));
                  }),
                  if (user!.providerData.any((p) => p.providerId == 'password'))
                    _buildMenuItem(
                        Icons.lock_rounded, "Change Password", _changePassword),
                  _buildMenuItem(Icons.storefront_rounded, "Become a Seller", () async {
                    final url = Uri.parse('https://kirihat.com/seller-registration');
                    try {
                      final canLaunch = await canLaunchUrl(url);
                      if (canLaunch) {
                        await launchUrl(url, mode: LaunchMode.platformDefault);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open seller registration form. Please check your internet connection.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error opening link: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }),
                ]),

                const SizedBox(height: 24),

                // --- LEGAL & POLICIES ---
                _buildSectionTitle("Legal & Policies"),
                _buildMenuCard([
                  _buildMenuItem(Icons.privacy_tip_rounded, "Privacy Policy", () {
                    launchUrl(Uri.parse(PolicyLinks.privacyPolicy));
                  }),
                  _buildMenuItem(Icons.description_rounded, "Terms & Conditions", () {
                    launchUrl(Uri.parse(PolicyLinks.termsAndConditions));
                  }),
                  _buildMenuItem(Icons.assignment_return_rounded, "Return & Refund", () {
                    launchUrl(Uri.parse(PolicyLinks.returnRefundPolicy));
                  }),
                  _buildMenuItem(Icons.local_shipping_rounded, "Shipping Policy", () {
                    launchUrl(Uri.parse(PolicyLinks.shippingPolicy));
                  }),
                  _buildMenuItem(Icons.cancel_rounded, "Cancellation Policy", () {
                    launchUrl(Uri.parse(PolicyLinks.cancellationPolicy));
                  }),
                ]),

                const SizedBox(height: 24),

                // --- C. HELP & SUPPORT (Enhanced) ---
                _buildSectionTitle("Help & Support"),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSupportRow(Icons.phone_rounded, "+91 9957693472"),
                      const Divider(height: 24),
                      _buildSupportRow(Icons.email_rounded, "support@kirihat.com"),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [primaryGreen, lightGreen],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryGreen.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _raiseCallbackRequest,
                          icon: const Icon(Icons.headset_mic_rounded),
                          label: const Text(
                            "Request Callback (12 hrs)",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentGreen.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: primaryGreen, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Kirihat Shop, Kachakhana, Golakganj, Dhubri, Assam, 783334",
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- D. LOGOUT & DELETE (Enhanced) ---
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text(
                            "Log Out",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountEnhancedScreen()));
                          },
                          icon: const Icon(Icons.delete_forever_rounded, size: 20),
                          label: const Text(
                            "Delete Account",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: darkGreen,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accentGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: primaryGreen, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSupportRow(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: accentGreen.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: darkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}