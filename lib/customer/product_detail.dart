import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../cart_page.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ProductDetailScreen({super.key, required this.data});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = widget.data;

    List<String> images = [];
    if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
      images.add(data['imageUrl']);
    }
    if (data['gallery'] != null) {
      for (var img in data['gallery']) {
        images.add(img.toString());
      }
    }

    int price = data['price'] ?? 0;
    int mrp = data['mrp'] ?? (price + 20);
    int discount = (mrp > price) ? (((mrp - price) / mrp) * 100).round() : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
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
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: images.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 80,
                              color: Colors.grey,
                            ),
                          )
                        : PageView.builder(
                            itemCount: images.length,
                            onPageChanged: (index) =>
                                setState(() => _currentImageIndex = index),
                            itemBuilder: (context, index) {
                              return Image.network(
                                images[index],
                                fit: BoxFit.contain,
                              );
                            },
                          ),
                  ),
                  if (images.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: images.asMap().entries.map((entry) {
                        return Container(
                          width: 8.0,
                          height: 8.0,
                          margin: const EdgeInsets.symmetric(
                            vertical: 10.0,
                            horizontal: 4.0,
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == entry.key
                                ? Colors.green
                                : Colors.grey.shade300,
                          ),
                        );
                      }).toList(),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            data['category'] ?? 'General',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data['name'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "₹$price",
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "M.R.P.: ₹$mrp",
                              style: const TextStyle(
                                fontSize: 16,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (discount > 0)
                              Text(
                                "$discount% OFF",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 30),
                        const Text(
                          "About this item",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data['description'] ?? "No details provided.",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 5),
                            Text(
                              (data['stock'] ?? 0) > 0
                                  ? "In Stock"
                                  : "Out of Stock",
                              style: TextStyle(
                                color: (data['stock'] ?? 0) > 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                  const Divider(height: 40),
                  const Text("Related Products",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 140,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('products')
                          .where('category', isEqualTo: data['category'])
                          .limit(5)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        var relatedDocs = snapshot.data!.docs;
                        var list = relatedDocs
                            .where((d) => d['name'] != data['name'])
                            .toList();

                        if (list.isEmpty) {
                          return const Text("No similar items found.");
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            var rData =
                                list[index].data() as Map<String, dynamic>;
                            bool rHasImage = rData['imageUrl'] != null &&
                                rData['imageUrl'].toString().isNotEmpty;

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailScreen(data: rData)),
                                );
                              },
                              child: Container(
                                width: 110,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(10)),
                                        ),
                                        child: rHasImage
                                            ? Image.network(rData['imageUrl'],
                                                fit: BoxFit.cover)
                                            : const Icon(Icons.shopping_bag,
                                                color: Colors.green),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(rData['name'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                          Text("₹${rData['price']}",
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _addToCart(context, data),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.green),
                ),
                child: const Text(
                  "Add to Cart",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _addToCart(context, data);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartPage()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  "Buy Now",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToCart(
      BuildContext context, Map<String, dynamic> productData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('cart')
        .doc(productData['id']);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(cartRef);

      if (snapshot.exists) {
        transaction.update(cartRef, {'qty': FieldValue.increment(1)});
      } else {
        transaction.set(cartRef, {
          'id': productData['id'],
          'name': productData['name'],
          'price': productData['price'],
          'imageUrl': productData['imageUrl'],
          'vendor_id': productData['vendor_id'],
          'qty': 1,
        });
      }
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✅ Added to Cart"),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: "GO TO CART",
            textColor: Colors.yellow,
            onPressed: () {
              if (context.mounted) {
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const CartPage()));
              }
            },
          ),
        ),
      );
    }
  }
}
