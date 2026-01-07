import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/cart_helper.dart';
import 'checkout_screen.dart';
import '../auth/phone_auth_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Guest mode - load from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cartJson = prefs.getString('guest_cart');
      
      if (cartJson != null) {
        try {
          List<dynamic> decoded = json.decode(cartJson);
          _cartItems = decoded.cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('Error loading guest cart: $e');
          _cartItems = [];
        }
      }
    } else {
      // Logged-in mode - load from Firestore
      try {
        var snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .get();

        _cartItems = snapshot.docs.map((doc) {
          var data = doc.data();
          // Ensure all required fields are present
          return {
            'product_id': doc.id,
            'name': data['name'] ?? '',
            'price': data['price'] ?? 0,
            'imageUrl': data['imageUrl'] ?? '',
            'quantity': data['quantity'] ?? 1,
            'vendor_id': data['vendor_id'] ?? '',
          };
        }).toList();
      } catch (e) {
        debugPrint('Error loading Firestore cart: $e');
        _cartItems = [];
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _updateQuantity(String productId, int newQty) async {
    if (newQty < 1) {
      await CartHelper.removeCartItem(context, productId);
    } else {
      await CartHelper.updateCartItemQuantity(context, productId, newQty);
    }
    await _loadCart();
  }

  Future<void> _removeItem(String productId) async {
    await CartHelper.removeCartItem(context, productId);
    await _loadCart();
  }

  double _calculateTotal() {
    double total = 0;
    for (var item in _cartItems) {
      final price = (item['price'] ?? 0).toDouble();
      final quantity = (item['quantity'] ?? 1) as int;
      total += price * quantity;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cart"),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? _buildEmptyCart()
              : _buildCartContent(isGuest),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            "Your cart is empty",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add items to get started",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(bool isGuest) {
    final total = _calculateTotal();
    final vendorId = _cartItems.isNotEmpty ? _cartItems[0]['vendor_id'] : null;

    return Column(
      children: [
        // Cart Items List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              return _buildCartItem(item);
            },
          ),
        ),

        // Bottom Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "₹${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9759),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Checkout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: isGuest
                    ? ElevatedButton.icon(
                        onPressed: () async {
                          // Navigate to login and wait for success (true)
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => const PhoneAuthScreen(),
                            ),
                          );
                          
                          // If login successful
                          if (result == true && mounted) {
                             setState(() => _isLoading = true);
                             
                             // 1. Reload cart to get migrated items
                             await _loadCart();
                             
                             // 2. Navigate to Checkout immediately
                             if (mounted && _cartItems.isNotEmpty) {
                                // Extract vendorId from first item (all items should be from same vendor)
                                final vendorId = _cartItems.first['vendor_id'] ?? '';
                                final total = _calculateTotal();
                                
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutScreen(
                                      cartItems: _cartItems,
                                      subtotal: total,
                                      vendorId: vendorId,
                                    )
                                  )
                                );
                             }
                             
                             setState(() => _isLoading = false);
                          }
                        },
                        icon: const Icon(Icons.login, size: 20),
                        label: const Text(
                          "LOGIN TO CHECKOUT",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9759),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          if (vendorId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Error: No vendor found")),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(
                                cartItems: _cartItems,
                                subtotal: total,
                                vendorId: vendorId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9759),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "PROCEED TO CHECKOUT",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Unknown Product';
    final double price = (item['price'] ?? 0).toDouble();
    final int quantity = (item['quantity'] ?? 1);
    final String imageUrl = item['imageUrl'] ?? '';
    final String productId = item['product_id'] ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹$price",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9759),
                    ),
                  ),
                ],
              ),
            ),

            // Quantity Controls
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _updateQuantity(productId, quantity - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: const Color(0xFF0D9759),
                      iconSize: 24,
                    ),
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _updateQuantity(productId, quantity + 1),
                      icon: const Icon(Icons.add_circle_outline),
                      color: const Color(0xFF0D9759),
                      iconSize: 24,
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _removeItem(productId),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text(
                    'Remove',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
