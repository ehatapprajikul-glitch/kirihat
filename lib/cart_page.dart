import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isCheckingOut = false;

  // 1. CALCULATE TOTAL PRICE
  double _calculateTotal(List<QueryDocumentSnapshot> docs) {
    double total = 0;
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      total += (data['price'] ?? 0) * (data['qty'] ?? 1);
    }
    return total;
  }

  // 2. CHECKOUT LOGIC (The most important part)
  Future<void> _placeOrder(List<QueryDocumentSnapshot> cartItems) async {
    setState(() => _isCheckingOut = true);

    // A. Group items by Vendor (So we create separate orders for separate shops)
    Map<String, List<Map<String, dynamic>>> ordersByVendor = {};

    for (var doc in cartItems) {
      var data = doc.data() as Map<String, dynamic>;
      String vendorId = data['vendor_id'] ?? 'unknown';

      if (!ordersByVendor.containsKey(vendorId)) {
        ordersByVendor[vendorId] = [];
      }

      // Add item to that vendor's list
      ordersByVendor[vendorId]!.add({
        'name': data['name'],
        'price': data['price'],
        'qty': data['qty'] ?? 1,
        'imageUrl': data['imageUrl'],
        'productId': doc.id, // Reference to original product
      });
    }

    // B. Create an Order Document for each Vendor
    WriteBatch batch = FirebaseFirestore.instance.batch();

    ordersByVendor.forEach((vendorId, items) {
      // Calculate total for just this vendor's order
      double orderTotal = items.fold(
        0,
        (sum, item) => sum + (item['price'] * item['qty']),
      );

      DocumentReference orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc();

      batch.set(orderRef, {
        'order_id': orderRef.id,
        'vendor_id': vendorId,
        'customer_id': user?.email, // Or user.uid
        'customer_phone':
            user?.email?.split('@')[0] ??
            "Unknown", // Extract phone from fake email
        'items': items,
        'total_amount': orderTotal,
        'status': 'Pending', // Pending -> Packed -> Shipped -> Delivered
        'created_at': FieldValue.serverTimestamp(),
      });
    });

    // C. Clear the User's Cart
    for (var doc in cartItems) {
      batch.delete(doc.reference);
    }

    // D. Commit all changes
    try {
      await batch.commit();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 50,
            ),
            content: const Text("Order Placed Successfully!"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Go back to shop
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _isCheckingOut = false);
  }

  // 3. DELETE ITEM FROM CART
  void _removeFromCart(String docId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user?.email)
        .collection('cart')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cart"),
        backgroundColor: Colors.green[100],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.email)
            .collection('cart')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var cartItems = snapshot.data!.docs;
          if (cartItems.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 10),
                  Text("Your cart is empty"),
                ],
              ),
            );
          }

          return Column(
            children: [
              // LIST OF ITEMS
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    var doc = cartItems[index];
                    var data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child:
                              (data['imageUrl'] != null &&
                                  data['imageUrl'].isNotEmpty)
                              ? Image.network(
                                  data['imageUrl'],
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  Icons.shopping_bag,
                                  color: Colors.green,
                                ),
                        ),
                        title: Text(data['name']),
                        subtitle: Text(
                          "Price: ₹${data['price']} | Qty: ${data['qty'] ?? 1}",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeFromCart(doc.id),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // BOTTOM CHECKOUT BAR
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.grey.withOpacity(0.1),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Total:",
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            "₹${_calculateTotal(cartItems)}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _isCheckingOut
                            ? null
                            : () => _placeOrder(cartItems),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                        ),
                        child: _isCheckingOut
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text("Place Order"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
