import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MasterCatalogBrowser extends StatefulWidget {
  const MasterCatalogBrowser({super.key});

  @override
  State<MasterCatalogBrowser> createState() => _MasterCatalogBrowserState();
}

class _MasterCatalogBrowserState extends State<MasterCatalogBrowser> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final String vendorId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remove Scaffold/AppBar, use Column directly
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Action Bar (Replacing AppBar)
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search master catalog...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                  builder: (context, snapshot) {
                    List<String> categories = ['All'];
                    if (snapshot.hasData) {
                      categories.addAll(
                        snapshot.data!.docs.map((doc) => doc['name'] as String),
                      );
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val!),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showRequestProductDialog(context),
                icon: const Icon(Icons.add),
                label: const Text("Request Product"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Products Grid
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('master_products')
                .where('isActive', isEqualTo: true)
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
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No products in master catalog',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              // Filter products
              var filteredDocs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String name = (data['name'] ?? '').toString().toLowerCase();
                String category = data['category'] ?? '';
                bool matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery);
                bool matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;
                return matchesSearch && matchesCategory;
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text('No products match your filters'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300, // Responsive grid cards
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  var doc = filteredDocs[index];
                  var productData = doc.data() as Map<String, dynamic>;
                  return _ProductCard(
                    productId: doc.id,
                    productData: productData,
                    vendorId: vendorId,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRequestProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RequestProductDialog(),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final String vendorId;

  const _ProductCard({
    required this.productId,
    required this.productData,
    required this.vendorId,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isAvailable = false;
  double? _sellingPrice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventoryStatus();
  }

  Future<void> _loadInventoryStatus() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: widget.vendorId)
          .where('product_id', isEqualTo: widget.productId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        setState(() {
          _isAvailable = data['isAvailable'] ?? false;
          _sellingPrice = data['selling_price']?.toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error loading inventory: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    if (value && _sellingPrice == null) {
      // Show pricing dialog
      await _showPricingDialog();
    } else {
      await _updateAvailability(value);
    }
  }

  Future<void> _showPricingDialog() async {
    final priceController = TextEditingController(text: _sellingPrice?.toString() ?? '');
    double mrp = widget.productData['mrp']?.toDouble() ?? 0;

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Selling Price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${widget.productData['name']}'),
            const SizedBox(height: 8),
            Text('MRP: ₹$mrp', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Your Selling Price',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Must be less than or equal to MRP',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              double? price = double.tryParse(priceController.text);
              if (price == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid price')),
                );
                return;
              }
              if (price > mrp) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Price cannot exceed MRP')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      double price = double.parse(priceController.text);
      await _updateInventory(true, price);
    }
  }

  Future<void> _updateAvailability(bool value) async {
    await _updateInventory(value, _sellingPrice);
  }

  Future<void> _updateInventory(bool isAvailable, double? price) async {
    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: widget.vendorId)
          .where('product_id', isEqualTo: widget.productId)
          .limit(1)
          .get();

      var data = {
        'vendor_id': widget.vendorId,
        'product_id': widget.productId,
        'isAvailable': isAvailable,
        'selling_price': price,
        'last_updated': FieldValue.serverTimestamp(),
      };

      if (querySnapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('vendor_inventory').add(data);
      } else {
        await querySnapshot.docs.first.reference.update(data);
      }

      setState(() {
        _isAvailable = isAvailable;
        _sellingPrice = price;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAvailable ? 'Product listed in your inventory' : 'Product removed from inventory'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    double mrp = widget.productData['mrp']?.toDouble() ?? 0;

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: widget.productData['imageUrl'] != null
                  ? Image.network(
                      widget.productData['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48),
                    )
                  : const Icon(Icons.image, size: 48),
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productData['name'] ?? 'Unnamed',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.productData['unit'] ?? ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'MRP: ₹$mrp',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (_sellingPrice != null)
                  Text(
                    'Your Price: ₹$_sellingPrice',
                    style: const TextStyle(
                      color: Color(0xFF0D9759),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 8),

                // Toggle and Edit Price
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        value: _isAvailable,
                        onChanged: _toggleAvailability,
                        title: Text(
                          _isAvailable ? 'Available' : 'Not Listed',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isAvailable ? Colors.green : Colors.grey,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    if (_isAvailable)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: _showPricingDialog,
                        tooltip: 'Edit Price',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
          const SnackBar(content: Text('Product request submitted! Admin will review it.')),
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
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _mrpController,
                        decoration: const InputDecoration(
                          labelText: 'Suggested MRP *',
                          prefixText: '₹',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val!.isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: '500g',
                          border: OutlineInputBorder(),
                        ),
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
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9759),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Submit Request'),
        ),
      ],
    );
  }
}
