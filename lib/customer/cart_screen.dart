import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Coupon State
  final TextEditingController _couponController = TextEditingController();
  double _discountAmount = 0;
  bool _isCouponApplied = false;

  // --- COUPON LOGIC (Simulated) ---
  void _applyCoupon() {
    String code = _couponController.text.trim().toUpperCase();
    if (code == "WELCOME50") {
      setState(() {
        _discountAmount = 50.0;
        _isCouponApplied = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Coupon Applied!"), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Invalid Code"), backgroundColor: Colors.red));
    }
  }

  void _removeCoupon() {
    setState(() {
      _discountAmount = 0;
      _isCouponApplied = false;
      _couponController.clear();
    });
  }

  // --- CART ACTIONS ---
  Future<void> _updateQty(String docId, int current, bool increase) async {
    if (user == null) {
      return;
    }
    int newQty = increase ? current + 1 : current - 1;

    if (newQty < 1) {
      _removeItem(docId);
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .doc(docId)
          .update({'quantity': newQty});
    }
  }

  Future<void> _removeItem(String docId) async {
    if (user == null) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please Login")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cart"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('cart')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var cartItems = snapshot.data!.docs;

          if (cartItems.isEmpty) {
            return const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Cart is Empty",
                      style: TextStyle(color: Colors.grey, fontSize: 18))
                ]));
          }

          // CALCULATION
          double subtotal = 0;
          String? vendorId; // Capture vendor ID for checkout logic
          List<Map<String, dynamic>> cartDataList = [];

          for (var doc in cartItems) {
            var data = doc.data() as Map<String, dynamic>;
            subtotal += (data['price'] ?? 0) * (data['quantity'] ?? 1);

            // Capture the vendor ID from the first item (Logic enforces single vendor cart)
            if (vendorId == null && data['vendor_id'] != null) {
              vendorId = data['vendor_id'];
            }

            cartDataList.add(data);
          }

          double finalTotal = subtotal - _discountAmount;
          if (finalTotal < 0) {
            finalTotal = 0;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    var data = cartItems[index].data() as Map<String, dynamic>;
                    double price = (data['price'] ?? 0).toDouble();
                    int qty = (data['quantity'] ?? 1);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                              image: data['imageUrl'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(data['imageUrl']),
                                      fit: BoxFit.cover)
                                  : null),
                          child: data['imageUrl'] == null
                              ? const Icon(Icons.image, color: Colors.grey)
                              : null,
                        ),
                        title: Text(data['name'] ?? "Product",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("₹$price"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red),
                                onPressed: () => _updateQty(
                                    cartItems[index].id, qty, false)),
                            Text("$qty",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                                icon: const Icon(Icons.add_circle_outline,
                                    color: Colors.green),
                                onPressed: () =>
                                    _updateQty(cartItems[index].id, qty, true)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // COUPON SECTION
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300)),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_outlined,
                        color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        enabled: !_isCouponApplied,
                        decoration: const InputDecoration(
                            hintText: "Enter Coupon Code",
                            border: InputBorder.none),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _isCouponApplied ? _removeCoupon : _applyCoupon,
                      child: Text(_isCouponApplied ? "REMOVE" : "APPLY",
                          style: TextStyle(
                              color:
                                  _isCouponApplied ? Colors.red : Colors.blue,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),

              // CHECKOUT SUMMARY
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, -5))
                    ]),
                child: Column(
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Subtotal",
                              style: TextStyle(color: Colors.grey)),
                          Text("₹$subtotal",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold))
                        ]),
                    if (_discountAmount > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Discount",
                                  style: TextStyle(color: Colors.green)),
                              Text("- ₹$_discountAmount",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green))
                            ]),
                      ),
                    const Divider(height: 20),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("₹$finalTotal",
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue))
                        ]),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (vendorId == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("Error: No Vendor Identified")));
                            }
                            return;
                          }

                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CheckoutScreen(
                                  cartItems: cartDataList,
                                  subtotal: finalTotal,
                                  vendorId:
                                      vendorId!, // Critical for Order Routing
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: const Text("PROCEED TO CHECKOUT",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
