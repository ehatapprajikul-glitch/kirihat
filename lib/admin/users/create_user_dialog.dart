import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class CreateUserDialog extends StatefulWidget {
  final String? uid;
  final Map<String, dynamic>? initialData;

  const CreateUserDialog({super.key, this.uid, this.initialData});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'customer';
  bool _isLoading = false;
  bool get _isEditMode => widget.uid != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode && widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _emailController.text = widget.initialData!['email'] ?? '';
      _phoneController.text = widget.initialData!['phone'] ?? '';
      _selectedRole = (widget.initialData!['role'] ?? 'customer').toString().toLowerCase();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isEditMode ? Icons.edit : Icons.person_add,
                    color: const Color(0xFF0D9759),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditMode ? 'Edit User' : 'Create New User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                enabled: !_isEditMode, // Can't change email in edit mode
                decoration: InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                  helperText: _isEditMode ? 'Email cannot be changed' : null,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Role Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('Customer')),
                  DropdownMenuItem(value: 'vendor', child: Text('Vendor')),
                  DropdownMenuItem(value: 'rider', child: Text('Rider')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  setState(() => _selectedRole = value!);
                },
              ),

              const SizedBox(height: 16),

              // Password Field (only for create mode)
              if (!_isEditMode) ...[
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    helperText: 'Minimum 6 characters',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 8),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_isEditMode ? 'UPDATE' : 'CREATE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditMode) {
        // Update existing user
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': _selectedRole,
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new user using a Secondary Firebase App
        // This prevents the current Admin from being logged out
        FirebaseApp tempApp = await Firebase.initializeApp(
          name: 'tempUserCreation',
          options: Firebase.app().options,
        );

        try {
          auth.UserCredential userCredential = await auth.FirebaseAuth.instanceFor(app: tempApp)
              .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

          // Create user document in Firestore (using main instance)
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'role': _selectedRole,
            'disabled': false,
            'created_at': FieldValue.serverTimestamp(),
            'created_by': auth.FirebaseAuth.instance.currentUser?.uid,
            'uid': userCredential.user!.uid, // Ensure UID is stored
          });
          
          // Initialize vendor profile if role is vendor
          if (_selectedRole == 'vendor') {
             await FirebaseFirestore.instance.collection('vendors').doc(userCredential.user!.uid).set({
                'business_name': _nameController.text.trim(),
                'phone': _phoneController.text.trim(),
                'email': _emailController.text.trim(),
                'is_verified': false,
                'created_at': FieldValue.serverTimestamp(),
             });
          }

          // Initialize rider profile if role is rider
          if (_selectedRole == 'rider') {
             await FirebaseFirestore.instance.collection('riders').doc(userCredential.user!.uid).set({
                'name': _nameController.text.trim(),
                'phone': _phoneController.text.trim(),
                'email': _emailController.text.trim(),
                'is_active': true,
                'is_verified': false,
                'current_zone': null,
                'wallet_balance': 0.0,
                'total_earnings': 0.0,
                'rating': 5.0,
                'created_at': FieldValue.serverTimestamp(),
             });
          }

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } finally {
          // Always delete the temp app
          await tempApp.delete();
        }
      }
    } catch (e) {
      debugPrint("Error creating user: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }
}
