import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_orders.dart';
import 'manage_addresses.dart';
import '../auth/login_screen.dart';
import '../auth/phone_auth_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  static DateTime? _lastResetTime;

  // --- 1. EDIT PROFILE DIALOG (Updated with Dropdown) ---
  void _showEditProfileDialog(Map<String, dynamic> currentData) {
    final nameController = TextEditingController(text: currentData['name']);

    // Set initial gender value (ensure it matches one of the dropdown items or is null)
    String? selectedGender = currentData['gender'];
    final List<String> genderOptions = ["Male", "Female", "Other"];

    // Validate if current data matches options, else reset
    if (!genderOptions.contains(selectedGender)) {
      selectedGender = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // Helper to update state inside Dialog
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Personal Info"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: "Full Name",
                          border: OutlineInputBorder())),
                  const SizedBox(height: 15),

                  // GENDER DROPDOWN
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: const InputDecoration(
                      labelText: "Gender",
                      border: OutlineInputBorder(),
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
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .update({
                        'name': nameController.text.trim(),
                        'gender': selectedGender ?? "Not Specified",
                      });
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text("Save"),
                )
              ],
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
        title: const Icon(Icons.mark_email_read, color: Colors.green, size: 50),
        content: Text(
            "Reset link sent to ${user!.email}.\n\nCheck your inbox (and spam folder). Link expires in 1 hour."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))
        ],
      ),
    );
  }

  // --- 3. RAISE CALLBACK REQUEST ---
  Future<void> _raiseCallbackRequest() async {
    // Show beautiful dialog to collect callback details
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final reasonController = TextEditingController();
    final messageController = TextEditingController();
    
    // Pre-fill with user data
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9759).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.headset_mic,
                              color: Color(0xFF0D9759),
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'We\'ll call you within 12 hours',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Name Field
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Your Name *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF0D9759)),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Phone Field
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFF0D9759)),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Reason Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedReason,
                        decoration: InputDecoration(
                          labelText: 'Reason for Callback',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.help_outline, color: Color(0xFF0D9759)),
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
                        decoration: InputDecoration(
                          labelText: 'Message (Optional)',
                          hintText: 'Tell us how we can help you...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.message, color: Color(0xFF0D9759)),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
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
                            
                            // Check for existing pending requests
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
                            
                            // Submit callback request
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
                            backgroundColor: const Color(0xFF0D9759),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'SUBMIT REQUEST',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF0D9759),
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Submitted!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our team will call you within 12 hours',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // --- 4. LOGOUT ---
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PhoneAuthScreen()), // Changed from LoginScreen
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
      return const Scaffold(body: Center(child: Text("Please Login")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // --- A. PROFILE HEADER ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.green.shade100,
                        child: Text(
                          (data['name'] ?? "U").substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['name'] ?? "User",
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(
                                (user!.email != null && user!.email!.isNotEmpty) 
                                    ? user!.email! 
                                    : (user!.phoneNumber ?? ""),
                                style: const TextStyle(color: Colors.grey)),
                            if (data['gender'] != null)
                              Text(data['gender'],
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditProfileDialog(data),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- B. ACCOUNT ACTIONS ---
                _buildSectionTitle("My Account"),
                _buildMenuCard([
                  _buildMenuItem(Icons.shopping_bag_outlined, "My Orders", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CustomerOrdersScreen()));
                  }),
                  _buildMenuItem(Icons.location_on_outlined, "Manage Addresses",
                      () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManageAddressesScreen()));
                  }),
                  // Only show Change Password if logged in with Email/Password
                  if (user!.providerData.any((p) => p.providerId == 'password'))
                    _buildMenuItem(
                        Icons.lock_outline, "Change Password", _changePassword),
                ]),

                const SizedBox(height: 20),

                // --- C. HELP & SUPPORT ---
                _buildSectionTitle("Help & Support"),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildSupportRow(Icons.phone, "+91 9957693472"),
                      const Divider(),
                      _buildSupportRow(Icons.email, "support@kirihat.com"),
                      const Divider(),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _raiseCallbackRequest,
                          icon: const Icon(Icons.headset_mic),
                          label: const Text("Request Callback (12 hrs)"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9759),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Office: Kirihat Shop, Kachakhana, Golakganj, Dhubri, Assam, 783334",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- D. LOGOUT ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0),
                    child: const Text("Log Out",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87)),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSupportRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 15),
          Text(text,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
