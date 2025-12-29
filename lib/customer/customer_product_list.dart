import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_detail.dart';
import 'customer_home.dart';

class CustomerProductListScreen extends StatefulWidget {
  final String vendorId;
  final String vendorName;

  const CustomerProductListScreen(
      {super.key, required this.vendorId, required this.vendorName});

  @override
  State<CustomerProductListScreen> createState() =>
      _CustomerProductListScreenState();
}

class _CustomerProductListScreenState extends State<CustomerProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  Future<void> _changeShop() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_vendor_id'); // Clear Preference
    await prefs.remove('selected_vendor_name');

    if (mounted) {
      // Go back to Home Screen (Shop List)
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F2F6), // Professional Light Grey
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.vendorName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text("Shopping here",
                style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          TextButton.icon(
              onPressed: _changeShop,
              icon: const Icon(Icons.store, color: Colors.white, size: 16),
              label: const Text("Change Shop",
                  style: TextStyle(color: Colors.white, fontSize: 12)))
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search in ${widget.vendorName}...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // Product Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('vendor_id', isEqualTo: widget.vendorId)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = (data['name'] ?? "").toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                      child: Text("No products found in this shop."));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65, // Taller for cleaner look
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildFlipkartStyleCard(docs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipkartStyleCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String imageUrl = data['imageUrl'] ?? "";
    String name = data['name'] ?? "Product";

    double price = (data['price'] ?? 0).toDouble();
    double? salePrice = data['sale_price'] != null
        ? (data['sale_price'] as num).toDouble()
        : null;
    double? regularPrice = data['regular_price'] != null
        ? (data['regular_price'] as num).toDouble()
        : null;

    // Calculate Discount
    int discountPercent = 0;
    if (regularPrice != null && regularPrice > price) {
      discountPercent = ((regularPrice - price) / regularPrice * 100).round();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ProductDetailScreen(productData: data, productId: doc.id)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Area
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.contain)
                        : const Icon(Icons.image, color: Colors.grey, size: 50),
                  ),
                  // Favorite Icon
                  const Positioned(
                    top: 5,
                    right: 5,
                    child: Icon(Icons.favorite_border,
                        color: Colors.grey, size: 20),
                  ),
                ],
              ),
            ),

            // Info Area
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 6),

                  // Price Row
                  Row(
                    children: [
                      Text("₹$price",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (discountPercent > 0) ...[
                        const SizedBox(width: 6),
                        Text("₹$regularPrice",
                            style: const TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey)),
                        const SizedBox(width: 6),
                        Text("$discountPercent% off",
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (discountPercent > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(2)),
                      child: const Text("Free Delivery",
                          style:
                              TextStyle(fontSize: 10, color: Colors.black54)),
                    )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
