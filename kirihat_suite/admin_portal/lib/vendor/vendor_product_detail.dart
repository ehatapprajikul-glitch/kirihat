import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_product_screen.dart'; // To allow editing from this screen

class VendorProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> productData;
  final String productId;

  const VendorProductDetailScreen({
    super.key,
    required this.productData,
    required this.productId,
  });

  @override
  State<VendorProductDetailScreen> createState() =>
      _VendorProductDetailScreenState();
}

class _VendorProductDetailScreenState extends State<VendorProductDetailScreen> {
  int _currentImage = 0;

  // --- DELETE LOGIC ---
  Future<void> _deleteProduct() async {
    bool confirm = await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Delete Product?"),
            content: const Text("This action cannot be undone."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .delete();
      if (mounted) {
        Navigator.pop(context); // Close Detail Screen
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Product Deleted")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.productData;
    List<dynamic> images = data['images'] ?? [data['imageUrl']];
    if (images.isEmpty) images = [""];

    // Pricing & Stock Data
    double price = (data['price'] ?? 0).toDouble();
    double? regularPrice = data['regular_price'] != null
        ? (data['regular_price'] as num).toDouble()
        : null;
    int stock = data['stock_quantity'] ?? 0;
    String sku = data['sku'] ?? "No SKU";
    bool isActive = data['isActive'] ?? false;

    // NEW: STORAGE DATA
    Map<String, dynamic> location = data['storage_location'] ?? {};
    String locationStr =
        "${location['aisle'] ?? '-'}/${location['shelf'] ?? '-'}/${location['bin'] ?? '-'}";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Product Details"),
        backgroundColor: Colors.orange[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              // Navigate to Edit Screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AddProductScreen(
                      initialData: data, docId: widget.productId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteProduct,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE GALLERY
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (idx) => setState(() => _currentImage = idx),
                    itemBuilder: (context, index) {
                      return Image.network(
                        images[index],
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Center(
                            child: Icon(Icons.image,
                                size: 80, color: Colors.grey)),
                      );
                    },
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                            images.length,
                            (index) => Container(
                                  margin: const EdgeInsets.all(4),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImage == index
                                        ? Colors.deepOrange
                                        : Colors.grey[300],
                                  ),
                                )),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. HEADER INFO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['category'] ?? "Uncategorized",
                              style: TextStyle(
                                  color: Colors.deepOrange[400],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['name'] ?? "Product Name",
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isActive ? Colors.green : Colors.red),
                        ),
                        child: Text(
                          isActive ? "Active" : "Inactive",
                          style: TextStyle(
                              color: isActive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. STATS GRID (Vendor Specific)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem("Price", "₹$price"),
                            _buildStatItem("Stock", "$stock",
                                color: stock < 5 ? Colors.red : Colors.black),
                            _buildStatItem("SKU", sku),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // NEW: STORAGE LOCATION DISPLAY
                            _buildStatItem("Location (A/S/B)",
                                locationStr.isEmpty ? "N/A" : locationStr),
                            _buildStatItem("Regular",
                                regularPrice != null ? "₹$regularPrice" : "-"),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. DESCRIPTION
                  const Text("Description",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    data['description'] ?? "No description provided.",
                    style: const TextStyle(color: Colors.black87, height: 1.5),
                  ),

                  const SizedBox(height: 20),

                  // 5. ATTRIBUTES
                  if (data['attributes'] != null &&
                      (data['attributes'] as List).isNotEmpty) ...[
                    const Text("Specifications",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...(data['attributes'] as List).map((attr) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(attr['name'],
                                style: const TextStyle(color: Colors.grey)),
                            Text(attr['value'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value,
      {Color color = Colors.black}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }
}
