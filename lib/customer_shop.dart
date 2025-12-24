import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cart_page.dart';

class CustomerMarket extends StatefulWidget {
  const CustomerMarket({super.key});

  @override
  State<CustomerMarket> createState() => _CustomerMarketState();
}

class _CustomerMarketState extends State<CustomerMarket> {
  String _searchQuery = "";
  // Function to Save Item to Firestore Cart
  Future<void> _addToCartDB(Map<String, dynamic> productData) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('cart')
        .add({
          'name': productData['name'],
          'price': productData['price'],
          'imageUrl': productData['imageUrl'],
          'vendor_id': productData['vendor_id'],
          'qty': 1,
          'added_at': FieldValue.serverTimestamp(),
        });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Added to Cart"),
          duration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kiri Hat Market"),
        backgroundColor: Colors.green[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search for rice, oil, etc...",
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;

          // ADVANCED SEARCH LOGIC (Name + Tags)
          var filteredDocs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;

            // 1. Name Check
            var name = data['name'].toString().toLowerCase();
            if (name.contains(_searchQuery)) return true;

            // 2. Tag Check
            if (data['tags'] != null) {
              List<dynamic> tags = data['tags'];
              if (tags.any(
                (t) => t.toString().toLowerCase().contains(_searchQuery),
              )) {
                return true;
              }
            }
            return false;
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text("No items found."));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              var data = filteredDocs[index].data() as Map<String, dynamic>;

              // Helper to check for image
              bool hasImage =
                  data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty;

              // Calculate Discount
              int price = data['price'] ?? 0;
              int mrp = data['mrp'] ?? (price + 20);
              int discount = 0;
              if (mrp > price) {
                discount = (((mrp - price) / mrp) * 100).round();
              }

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(data: data),
                    ),
                  );
                },
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. PRODUCT IMAGE (Updated)
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: hasImage
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(15),
                                  ),
                                  child: Image.network(
                                    data['imageUrl'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, o, s) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.shopping_bag,
                                  size: 50,
                                  color: Colors.green,
                                ),
                        ),
                      ),

                      // 2. Info Section
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  "₹$price",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "₹$mrp",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (discount > 0)
                              Text(
                                "$discount% OFF",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------
// PRODUCT DETAIL SCREEN (With Images)
// ------------------------------------------------------------------
class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ProductDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    int price = data['price'] ?? 0;
    int mrp = data['mrp'] ?? (price + 20);
    int stock = data['stock'] ?? 0;
    String category = data['category'] ?? 'Groceries';
    bool hasImage =
        data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(data['name']),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Large Image Header
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.white,
              child: hasImage
                  ? Image.network(data['imageUrl'], fit: BoxFit.contain)
                  : const Icon(
                      Icons.shopping_bag,
                      size: 100,
                      color: Colors.green,
                    ),
            ),

            // 2. Details Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50], // Light background for contrast
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(color: Colors.deepOrange),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    data['name'],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Text(
                        "₹$price",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text(
                        "MRP ₹$mrp",
                        style: const TextStyle(
                          fontSize: 18,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const Text(
                    "Specifications",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(data['description'] ?? "No description available."),
                  const SizedBox(height: 5),
                  Text("Stock Available: $stock units"),

                  const SizedBox(height: 30),

                  // RELATED PRODUCTS (Hidden for brevity, add back if needed or keep blank for now)
                  // You can paste the "Related Products" list code from the previous response here if you want it.
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(15),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.email)
                      .collection('cart')
                      .add({
                        'name': data['name'],
                        'price': data['price'],
                        'imageUrl': data['imageUrl'],
                        'vendor_id': data['vendor_id'],
                        'qty': 1,
                        'added_at': FieldValue.serverTimestamp(),
                      });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Added to Cart")),
                  );
                },
                child: const Text("Add to Cart"),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Buy Now"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
