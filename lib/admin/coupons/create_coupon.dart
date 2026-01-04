import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class CreateCoupon extends StatefulWidget {
  final String? existingId;
  final Map<String, dynamic>? existingData;
  
  const CreateCoupon({super.key, this.existingId, this.existingData});

  @override
  State<CreateCoupon> createState() => _CreateCouponState();
}

class _CreateCouponState extends State<CreateCoupon> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _usageLimitController = TextEditingController();
  final _perUserLimitController = TextEditingController();

  String _couponType = 'general';
  String _discountType = 'percentage';
  DateTime? _validFrom;
  DateTime? _validUntil;
  List<String> _selectedCategories = [];
  List<String> _selectedProducts = [];
  bool _isLoading = false;

  final List<String> _availableCategories = [
    'Groceries',
    'Dairy',
    'Fruits',
    'Vegetables',
    'Snacks',
    'Beverages',
  ];

  @override
  void initState() {
    super.initState();
    // Load existing data if editing
    if (widget.existingData != null) {
      _codeController.text = widget.existingData!['code'] ?? '';
      _couponType = widget.existingData!['type'] ?? 'general';
      _discountType = widget.existingData!['discount_type'] ?? 'percentage';
      _discountValueController.text = (widget.existingData!['discount_value'] ?? '').toString();
      _minOrderController.text = (widget.existingData!['min_order_value'] ?? '').toString();
      _maxDiscountController.text = (widget.existingData!['max_discount'] ?? '').toString();
      _usageLimitController.text = (widget.existingData!['usage_limit'] ?? '').toString();
      _perUserLimitController.text = (widget.existingData!['per_user_limit'] ?? '').toString();
      
      if (widget.existingData!['valid_from'] != null) {
        _validFrom = (widget.existingData!['valid_from'] as Timestamp).toDate();
      }
      if (widget.existingData!['valid_until'] != null) {
        _validUntil = (widget.existingData!['valid_until'] as Timestamp).toDate();
      }
      
      if (widget.existingData!['applicable_categories'] != null) {
        _selectedCategories = List<String>.from(widget.existingData!['applicable_categories']);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _discountValueController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _usageLimitController.dispose();
    _perUserLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.local_offer, color: Color(0xFF0D9759)),
                  const SizedBox(width: 12),
                  Text(
                    widget.existingId == null ? 'Create Discount Coupon' : 'Edit Discount Coupon',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coupon Code
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'Coupon Code *',
                                hintText: 'e.g., WELCOME10',
                                border: OutlineInputBorder(),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Code is required';
                                }
                                if (value.length < 4) {
                                  return 'Code must be at least 4 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _generateRandomCode,
                            icon: const Icon(Icons.shuffle, size: 18),
                            label: const Text('Generate'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Coupon Type
                      DropdownButtonFormField<String>(
                        value: _couponType,
                        decoration: const InputDecoration(
                          labelText: 'Coupon Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'general', child: Text('General - All Users')),
                          DropdownMenuItem(value: 'new_user', child: Text('New User Only')),
                          DropdownMenuItem(value: 'category', child: Text('Category Specific')),
                          DropdownMenuItem(value: 'product', child: Text('Product Specific')),
                        ],
                        onChanged: (value) {
                          setState(() => _couponType = value!);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Discount Configuration
                      const Text(
                        'Discount Configuration',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _discountType,
                              decoration: const InputDecoration(
                                labelText: 'Discount Type',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                                DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount (₹)')),
                              ],
                              onChanged: (value) {
                                setState(() => _discountType = value!);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _discountValueController,
                              decoration: InputDecoration(
                                labelText: _discountType == 'percentage' ? 'Discount (%)' : 'Amount (₹)',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                num? val = num.tryParse(value);
                                if (val == null || val <= 0) {
                                  return 'Must be > 0';
                                }
                                if (_discountType == 'percentage' && val > 100) {
                                  return 'Max 100%';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Min Order Value & Max Discount
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minOrderController,
                              decoration: const InputDecoration(
                                labelText: 'Min Order Value (₹)',
                                border: OutlineInputBorder(),
                                hintText: 'Optional',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maxDiscountController,
                              decoration: const InputDecoration(
                                labelText: 'Max Discount (₹)',
                                border: OutlineInputBorder(),
                                hintText: 'Optional',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Usage Limits
                      const Text(
                        'Usage Limits',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _usageLimitController,
                              decoration: const InputDecoration(
                                labelText: 'Total Usage Limit',
                                border: OutlineInputBorder(),
                                hintText: 'Unlimited',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _perUserLimitController,
                              decoration: const InputDecoration(
                                labelText: 'Per User Limit',
                                border: OutlineInputBorder(),
                                hintText: '1',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Validity Period
                      const Text(
                        'Validity Period',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(context, true),
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_validFrom == null
                                  ? 'Start Date (Now)'
                                  : '${_validFrom!.day}/${_validFrom!.month}/${_validFrom!.year}'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(context, false),
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_validUntil == null
                                  ? 'End Date (Never)'
                                  : '${_validUntil!.day}/${_validUntil!.month}/${_validUntil!.year}'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _validUntil == null ? Colors.grey : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Category Selection (if type is category)
                      if (_couponType == 'category') ...[
                        const Text(
                          'Applicable Categories',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableCategories.map((category) {
                            bool isSelected = _selectedCategories.contains(category);
                            return FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.remove(category);
                                  }
                                });
                              },
                              selectedColor: const Color(0xFF0D9759).withOpacity(0.2),
                              checkmarkColor: const Color(0xFF0D9759),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

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
                    onPressed: _isLoading ? null : (widget.existingId == null ? _createCoupon : _updateCoupon),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(widget.existingId == null ? 'CREATE COUPON' : 'UPDATE COUPON'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    String code = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
    _codeController.text = code;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _validFrom = picked;
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  Future<void> _createCoupon() async {
    if (!_formKey.currentState!.validate()) return;

    if (_couponType == 'category' && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? admin = FirebaseAuth.instance.currentUser;

      Map<String, dynamic> couponData = {
        'code': _codeController.text.trim().toUpperCase(),
        'type': _couponType,
        'discount_type': _discountType,
        'discount_value': num.parse(_discountValueController.text),
        'min_order_value': _minOrderController.text.isNotEmpty
            ? num.parse(_minOrderController.text)
            : null,
        'max_discount': _maxDiscountController.text.isNotEmpty
            ? num.parse(_maxDiscountController.text)
            : null,
        'usage_limit': _usageLimitController.text.isNotEmpty
            ? int.parse(_usageLimitController.text)
            : null,
        'per_user_limit': _perUserLimitController.text.isNotEmpty
            ? int.parse(_perUserLimitController.text)
            : 1,
        'used_count': 0,
        'valid_from': _validFrom != null ? Timestamp.fromDate(_validFrom!) : Timestamp.now(),
        'valid_until': _validUntil != null ? Timestamp.fromDate(_validUntil!) : null,
        'applicable_categories': _couponType == 'category' ? _selectedCategories : null,
        'applicable_products': _couponType == 'product' ? _selectedProducts : null,
        'is_active': true,
        'created_by': admin?.uid,
        'created_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('coupons').add(couponData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coupon created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateCoupon() async {
    if (!_formKey.currentState!.validate()) return;

    if (_couponType == 'category' && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> couponData = {
        'code': _codeController.text.trim().toUpperCase(),
        'type': _couponType,
        'discount_type': _discountType,
        'discount_value': num.parse(_discountValueController.text),
        'min_order_value': _minOrderController.text.isNotEmpty
            ? num.parse(_minOrderController.text)
            : null,
        'max_discount': _maxDiscountController.text.isNotEmpty
            ? num.parse(_maxDiscountController.text)
            : null,
        'usage_limit': _usageLimitController.text.isNotEmpty
            ? int.parse(_usageLimitController.text)
            : null,
        'per_user_limit': _perUserLimitController.text.isNotEmpty
            ? int.parse(_perUserLimitController.text)
            : 1,
        'valid_from': _validFrom != null ? Timestamp.fromDate(_validFrom!) : Timestamp.now(),
        'valid_until': _validUntil != null ? Timestamp.fromDate(_validUntil!) : null,
        'applicable_categories': _couponType == 'category' ? _selectedCategories : null,
        'applicable_products': _couponType == 'product' ? _selectedProducts : null,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('coupons')
          .doc(widget.existingId)
          .update(couponData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coupon updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
