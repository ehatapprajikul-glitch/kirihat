import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_home.dart'; // Make sure this import points to your home page

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _stateController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Save address to a sub-collection or main user document
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'address': {
          'street': _streetController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'zip': _zipController.text.trim(),
        },
        'hasAddress': true,
      });

      if (mounted) _goToHome();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
      setState(() => _isLoading = false);
    }
  }

  void _goToHome() {
    // Navigate to the main Customer Market and remove previous screens from history
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Delivery Address"),
        actions: [
          TextButton(
            onPressed: _goToHome,
            child: const Text(
              "SKIP",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              const Text(
                "Where should we deliver?",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              _buildTextField(_streetController, "Street Address"),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTextField(_cityController, "City")),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      _zipController,
                      "Zip Code",
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildTextField(_stateController, "State/Province"),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SAVE ADDRESS"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green, width: 2),
        ),
      ),
      validator: (val) => val!.isEmpty ? "Required" : null,
    );
  }
}
