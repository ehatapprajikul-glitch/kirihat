import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorRequestStockScreen extends StatefulWidget {
  const VendorRequestStockScreen({super.key});

  @override
  State<VendorRequestStockScreen> createState() => _VendorRequestStockScreenState();
}

class _VendorRequestStockScreenState extends State<VendorRequestStockScreen> {
  String _searchQuery = '';
  String? _vendorId;
  String? _vendorName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVendorData();
  }

  Future<void> _loadVendorData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _vendorId = data?['vendor_id'] ?? userId;
          _vendorName = data?['vendor_name'] ?? data?['name'] ?? 'My Store';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading vendor data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Stock from Warehouse'),
        backgroundColor: Colors.purple.shade700,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search warehouse products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Available Products from Warehouse
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('warehouse_inventory')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No products available in warehouse',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                var products = snapshot.data!.docs;

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  products = products.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final productName = (data['product_name'] ?? '').toString().toLowerCase();
                    return productName.contains(_searchQuery);
                  }).toList();
                }

                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      'No products match your search',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final doc = products[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final productId = doc.id;
                    final productName = data['product_name'] ?? 'Unknown Product';
                    final availableQty = data['quantity'] ?? 0;

                    return _buildProductCard(productId, productName, availableQty);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(String productId, String productName, int availableQty) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Available in warehouse: $availableQty units',
                        style: TextStyle(
                          fontSize: 14,
                          color: availableQty > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: availableQty > 0
                    ? () => _showRequestDialog(productId, productName, availableQty)
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Request Stock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRequestDialog(String productId, String productName, int maxAvailable) async {
    final TextEditingController qtyController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request: $productName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: $maxAvailable units'),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity Needed',
                border: OutlineInputBorder(),
                hintText: 'Enter quantity',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Reason for request...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text.trim());
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid quantity')),
                );
                return;
              }
              if (qty > maxAvailable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Maximum available: $maxAvailable units')),
                );
                return;
              }
              Navigator.pop(context, {
                'quantity': qty,
                'notes': notesController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _submitRequest(productId, productName, result['quantity'], result['notes']);
    }
  }

  Future<void> _submitRequest(String productId, String productName, int quantity, String notes) async {
    if (_vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Vendor ID not found')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('vendor_stock_requests').add({
        'vendor_id': _vendorId,
        'vendor_name': _vendorName,
        'product_id': productId,
        'product_name': productName,
        'requested_quantity': quantity,
        'approved_quantity': 0,
        'status': 'pending',
        'notes': notes.isNotEmpty ? notes : null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
