import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../manage_addresses.dart'; // Or address_screen.dart directly if we want to force add
import '../address_screen.dart';
import '../customer_dashboard.dart';

class AccountSetupScreen extends StatefulWidget {
  final bool isNestedFlow;

  const AccountSetupScreen({
    super.key, 
    this.isNestedFlow = false,
  });

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pincodeController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;
  final _userService = UserService();
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadAutoFillData();
  }

  Future<void> _loadAutoFillData() async {
    if (_user != null) {
      _phoneController.text = _user?.phoneNumber ?? '';
      _nameController.text = _user?.displayName ?? '';
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final pincode = prefs.getString('current_pincode');
      if (pincode != null) {
        _pincodeController.text = pincode;
      }
    } catch (e) {
      debugPrint('Error loading auto-fill data: $e');
    }
    
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (_user == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Update Profile (Name & Gender)
      await _userService.updateProfile(
        _user!.uid,
        name: _nameController.text.trim(),
        gender: _selectedGender,
      );

      // 2. Check complete status again to see where to go next
      // Ideally, if we just updated name/gender, we know we need an address.
      // But let's check if they ALREADY have an address (edge case: skipped name but added address?)
      // For now, let's assume if they are here, they need to add an address too.
      // BUT, to be safe, let's just go to Address Screen.
      
      if (mounted) {
         // Proceed to Add Address
         if (widget.isNestedFlow) {
           await Navigator.push(
            context,
             MaterialPageRoute(
               builder: (_) => AddressScreen(
                 isOnboarding: true, // Still onboarding
                 isNestedFlow: widget.isNestedFlow, // Pass flow type
               ),
             ),
           );
           // After returning from Address Screen (which means address is saved), we pop this screen too
           if (mounted) Navigator.pop(context);
         } else {
           Navigator.pushReplacement(
            context,
             MaterialPageRoute(
               builder: (_) => AddressScreen(
                 isOnboarding: true, // Still onboarding
                 isNestedFlow: widget.isNestedFlow, // Pass flow type
               ),
             ),
           );
         }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Modern clean look
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                // Header
                const Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We need a few details to set up your profile.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

                // Name Input
                Text(
                  'Full Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  // Read-only if name is already set (e.g. from Google/Truecaller)
                  // BUT editable if empty, otherwise user can't proceed!
                  readOnly: _nameController.text.isNotEmpty,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    filled: true,
                    // If read-only, show grey background
                    fillColor: _nameController.text.isNotEmpty ? Colors.grey[200] : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                    suffixIcon: _nameController.text.isNotEmpty 
                        ? const Icon(Icons.lock_outline, size: 18, color: Colors.grey)
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Phone Input (Read-only)
                Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Mobile Number',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                    suffixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 24),

                // Pincode Input (Read-only)
                Text(
                  'Pincode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pincodeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Pincode',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                    suffixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 32),

                // Gender Input
                Text(
                  'Gender',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildGenderOption('Male')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildGenderOption('Female')),
                  ],
                ),
                const SizedBox(height: 16),
                 Row(
                  children: [
                    Expanded(child: _buildGenderOption('Other')),
                  ],
                ),


                const SizedBox(height: 56),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
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

  Widget _buildGenderOption(String gender) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9759).withOpacity(0.1) : const Color(0xFFF5F5F5),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9759) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          gender,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF0D9759) : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
