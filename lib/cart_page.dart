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

  // 2. CHECKOUT LOGIC
  Future<void> _placeOrder(List<QueryDocumentSnapshot> cartItems) async {
    setState(() => _isCheckingOut = true);

    // A. Group items by Vendor
    Map<String, List<Map<String, dynamic>>> ordersByVendor = {};

    for (var doc in cartItems) {
      var data = doc.data() as Map<String, dynamic>;
      String vendorId = data['vendor_id'] ?? 'unknown';

      if (!ordersByVendor.containsKey(vendorId)) {
        ordersByVendor[vendorId] = [];
      }

      ordersByVendor[vendorId]!.add({
        'name': data['name'],
        'price': data['price'],
        'qty': data['qty'] ?? 1,
        'imageUrl': data['imageUrl'],
        'productId': doc.id,
      });
    }

    // B. Create Order Documents
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // FIXED: Renamed 'sum' to 'currentSum' to avoid type conflict
    ordersByVendor.forEach((vendorId, items) {
      double orderTotal = items.fold(
        0,
        (currentSum, item) => currentSum + (item['price'] * item['qty']),
      );

      DocumentReference orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc();

      batch.set(orderRef, {
        'order_id': orderRef.id,
        'vendor_id': vendorId,
        'customer_id': user?.email,
        'customer_phone': user?.email?.split('@')[0] ?? "Unknown",
        'items': items,
        'total_amount': orderTotal,
        'status': 'Pending',
        'created_at': FieldValue.serverTimestamp(),
      });
    });

    // C. Clear Cart
    for (var doc in cartItems) {
      batch.delete(doc.reference);
    }

    // D. Commit
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
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // FIXED: Added Block
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }

    setState(() => _isCheckingOut = false);
  }

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
          if (!snapshot.hasData) {
            // FIXED: Added Block
            return const Center(child: CircularProgressIndicator());
          }

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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  // FIXED: Replaced withOpacity(0.1) -> withAlpha(25)
                  boxShadow: [
                    BoxShadow(blurRadius: 10, color: Colors.grey.withAlpha(25)),
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
