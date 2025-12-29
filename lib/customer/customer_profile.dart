import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_orders.dart';
import 'manage_addresses.dart';
import '../auth/login_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isCallbackLoading = false;
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
    setState(() => _isCallbackLoading = true);
    try {
      var existingRequests = await FirebaseFirestore.instance
          .collection('support_requests')
          .where('user_id', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'Pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        if (mounted) {
          showDialog(
              context: context,
              builder: (c) => AlertDialog(
                    title:
                        const Icon(Icons.info, color: Colors.orange, size: 50),
                    content: const Text(
                        "You already have a pending callback request.\n\nPlease wait for our team to contact you before raising another."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text("OK"))
                    ],
                  ));
        }
      } else {
        await FirebaseFirestore.instance.collection('support_requests').add({
          'user_id': user!.uid,
          'user_email': user!.email,
          'phone': user!.phoneNumber ?? "Not provided",
          'type': 'Callback Request',
          'status': 'Pending',
          'created_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          showDialog(
              context: context,
              builder: (c) => AlertDialog(
                    title: const Icon(Icons.check_circle,
                        color: Colors.green, size: 50),
                    content: const Text(
                        "Request Received! Our team will call you within 12 hours."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text("OK"))
                    ],
                  ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
    if (mounted) {
      setState(() => _isCallbackLoading = false);
    }
  }

  // --- 4. LOGOUT ---
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            Text(user!.email ?? "",
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
                        child: OutlinedButton.icon(
                          onPressed:
                              _isCallbackLoading ? null : _raiseCallbackRequest,
                          icon: _isCallbackLoading
                              ? const SizedBox()
                              : const Icon(Icons.headset_mic),
                          label: _isCallbackLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text("Request Callback (12 hrs)"),
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
