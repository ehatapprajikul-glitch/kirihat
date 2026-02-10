import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:kirihat_core/utils/cart_helper.dart';
import 'package:kirihat_core/utils/currency_helper.dart';
import 'package:kirihat_core/services/product_service.dart';
import 'checkout_screen.dart';
import '../auth/phone_auth_screen.dart';
import 'customer_profile.dart';

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
    List<Map<String, dynamic>> rawItems = [];

    if (user == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cartJson = prefs.getString('guest_cart');
      if (cartJson != null) {
        try {
          List<dynamic> decoded = json.decode(cartJson);
          rawItems = decoded.cast<Map<String, dynamic>>();
        } catch (e) {
          rawItems = [];
        }
      }
    } else {
      try {
        var snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .get();

        rawItems = snapshot.docs.map((doc) {
          var data = doc.data();
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
        rawItems = [];
      }
    }

    // Fetch fresh stock data
    if (rawItems.isNotEmpty) {
      try {
        final vendorId = rawItems.first['vendor_id'] as String;
        final productIds = rawItems.map((e) => e['product_id'] as String).toList();
        
        final freshProducts = await ProductService().getFeaturedProducts(
          vendorId: vendorId,
          productIds: productIds,
        );

        final freshMap = {for (var p in freshProducts) p['id']: p};

        _cartItems = rawItems.map((item) {
          final fresh = freshMap[item['product_id']];
          return {
            ...item,
            'stock_quantity': fresh?['stock_quantity'] ?? 999, 
            'isAvailable': fresh?['isAvailable'] ?? true,
          };
        }).toList();
      } catch (e) {
        debugPrint('Error fetching fresh cart data: $e');
        _cartItems = rawItems;
      }
    } else {
      _cartItems = [];
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateQuantity(String productId, int newQty, int stock) async {
    if (newQty > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Max stock reached"),
          duration: Duration(milliseconds: 500),
        ),
      );
      return;
    }

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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              "Your cart is empty",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Looks like you haven't added anything yet",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.shopping_bag),
              label: const Text("Start Shopping"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
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
                    CurrencyHelper.format(total),
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
                          // Await the entire login flow (Phone -> OTP -> [Setup] -> [Address])
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PhoneAuthScreen(isNestedFlow: true),
                            ),
                          );
                          
                          // Check if user is now logged in
                          final currentUser = FirebaseAuth.instance.currentUser;
                          
                          if (currentUser != null && mounted) {
                             setState(() => _isLoading = true);
                             
                             // Refresh cart from server to merge guest items if needed
                             await _loadCart();
                             
                             // Proceed to checkout if cart has items
                             if (mounted && _cartItems.isNotEmpty) {
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
    
    final int stock = (item['stock_quantity'] ?? 999) is int 
        ? item['stock_quantity'] 
        : (item['stock_quantity'] ?? 999).toInt();

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
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                      errorWidget: (context, url, error) => Container(
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
                    CurrencyHelper.format(price),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9759),
                    ),
                  ),
                  if (stock < 5 && stock > 0)
                     Text('Only $stock left!', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),

            // Quantity Controls
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _updateQuantity(productId, quantity - 1, stock),
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
                       onPressed: quantity >= stock 
                          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max stock reached"), duration: Duration(milliseconds: 500))) 
                          : () => _updateQuantity(productId, quantity + 1, stock),
                      icon: Icon(Icons.add_circle_outline, color: quantity >= stock ? Colors.grey : const Color(0xFF0D9759)),
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
