import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestProductDialog extends StatefulWidget {
  const RequestProductDialog({super.key});

  @override
  State<RequestProductDialog> createState() => _RequestProductDialogState();
}

class _RequestProductDialogState extends State<RequestProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _mrpController = TextEditingController();
  final _unitController = TextEditingController();
  final _imageUrlController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _mrpController.dispose();
    _unitController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      await FirebaseFirestore.instance.collection('product_requests').add({
        'vendor_id': FirebaseAuth.instance.currentUser!.uid,
        'vendor_name': vendorDoc.data()?['businessName'] ?? 'Unknown Vendor',
        'product_name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'suggested_mrp': double.parse(_mrpController.text),
        'category': _selectedCategory,
        'unit': _unitController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product request submitted!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request New Product'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _mrpController,
                        decoration: const InputDecoration(labelText: 'MRP *', prefixText: '₹', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val!.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(labelText: 'Unit', hintText: '500g', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                  builder: (context, snapshot) {
                    List<String> categories = [];
                    if (snapshot.hasData) {
                      categories = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Submit'),
        ),
      ],
    );
  }
}
