import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // For number input formatting

class UserManagerScreen extends StatefulWidget {
  const UserManagerScreen({super.key});

  @override
  State<UserManagerScreen> createState() => _UserManagerScreenState();
}

class _UserManagerScreenState extends State<UserManagerScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _nameController = TextEditingController();

  // Default role selection
  String _selectedRole = 'vendor';
  bool _loading = false;

  // Function to create a new user in Firestore
  Future<void> _createUser() async {
    if (_phoneController.text.length != 10 || _pinController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please check Phone (10 digits) and PIN (6 digits)."),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    // We use the Phone Number (plus fake email extension) as the unique ID
    String fakeEmail = "${_phoneController.text.trim()}@kirihat.com";

    try {
      // 1. We create a document in the 'users' collection
      // We use .set() so we can specify the document ID (the fake email)
      await FirebaseFirestore.instance.collection('users').doc(fakeEmail).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'pin': _pinController.text
            .trim(), // Storing PIN plain text for simplicity (Note: In a real bank app, we'd encrypt this)
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Success! Created $_selectedRole: ${_nameController.text}",
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Clear the form
        _phoneController.clear();
        _pinController.clear();
        _nameController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hire Staff & Vendors"),
        backgroundColor: Colors.red[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Create New Account",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text("Add vendors, riders, or other admins here."),
            const Divider(),
            const SizedBox(height: 20),

            // 1. Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),

            // 2. Phone Field
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                prefixText: "+91 ",
                border: OutlineInputBorder(),
                counterText: "",
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 15),

            // 3. PIN Field
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: "Assign 6-Digit PIN",
                border: OutlineInputBorder(),
                counterText: "",
                prefixIcon: Icon(Icons.lock),
                helperText: "User will use this PIN to login",
              ),
            ),
            const SizedBox(height: 20),

            // 4. Role Selection (Dropdown)
            const Text(
              "Select Role:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: _selectedRole,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'vendor',
                  child: Text("Vendor (Shop Owner)"),
                ),
                DropdownMenuItem(
                  value: 'rider',
                  child: Text("Rider (Delivery)"),
                ),
                DropdownMenuItem(
                  value: 'admin',
                  child: Text("Admin (Partner)"),
                ),
                DropdownMenuItem(
                  value: 'customer',
                  child: Text("Customer (User)"),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),

            const SizedBox(height: 30),

            // 5. Create Button
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _createUser,
                      child: const Text("Create User"),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
