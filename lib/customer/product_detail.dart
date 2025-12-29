import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_screen.dart'; // Ensure this import exists

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> productData;
  final String productId;

  const ProductDetailScreen(
      {super.key, required this.productData, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  bool _isAdding = false;

  // --- CART LOGIC ---
  Future<void> _addToCart() async {
    setState(() => _isAdding = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String currentVendorId = widget.productData['vendor_id'];

      // 1. Check Existing Cart Vendor
      // We store the 'cart_vendor_id' whenever we add the first item.
      String? cartVendorId = prefs.getString('cart_vendor_id');

      if (cartVendorId != null && cartVendorId != currentVendorId) {
        // CONFLICT DETECTED!
        _showResetCartDialog(currentVendorId);
        setState(() => _isAdding = false);
        return;
      }

      // 2. Add Item to Firestore (or Local DB)
      // Assuming you use a 'cart' subcollection under the user or a main 'carts' collection
      // Here is a standard Firestore implementation:

      // Get User ID (You might want to pass this or get from Auth)
      // For now, we assume you handle user auth globally.
      // await FirebaseFirestore.instance.collection('users').doc(uid).collection('cart').add(...)

      // For this example, I will simulate the "Success" and saving the Vendor ID
      await prefs.setString('cart_vendor_id', currentVendorId);

      // TODO: Call your actual Cart Provider/Function here using widget.productData & _quantity
      // Example: Provider.of<CartProvider>(context, listen: false).addItem(...);

      // Show Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("Added $_quantity x ${widget.productData['name']} to Cart"),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'VIEW CART',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CartScreen()));
              }
            },
          ),
        ));
      }
    } catch (e) {
      debugPrint("Cart Error: $e");
    }

    setState(() => _isAdding = false);
  }

  // --- RESET DIALOG ---
  void _showResetCartDialog(String newVendorId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Start new basket?"),
        content: const Text(
            "You have items from another shop in your cart. Adding this will clear your previous selection."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              // 1. Clear Cart Data (Logic depends on your Cart Provider)
              // Provider.of<CartProvider>(context, listen: false).clearCart();

              // 2. Update Vendor ID in Prefs
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setString('cart_vendor_id', newVendorId);

              Navigator.pop(ctx);
              _addToCart(); // Retry adding the item
            },
            child: const Text("RESET & ADD",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.productData;
    String imageUrl = data['imageUrl'] ?? "";
    String name = data['name'] ?? "Product Name";
    String description = data['description'] ?? "No description available.";

    double price = (data['price'] ?? 0).toDouble();
    double? salePrice = data['sale_price'] != null
        ? (data['sale_price'] as num).toDouble()
        : null;
    double? regularPrice = data['regular_price'] != null
        ? (data['regular_price'] as num).toDouble()
        : null;

    double finalPrice = salePrice ?? price;
    bool isOnSale = salePrice != null && salePrice < (regularPrice ?? price);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. HERO IMAGE
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image,
                          size: 50, color: Colors.grey)),
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.white.withAlpha(200),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 2. DETAILS
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("₹$finalPrice",
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                            if (isOnSale)
                              Text("₹$regularPrice",
                                  style: const TextStyle(
                                      fontSize: 14,
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey)),
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Quantity Selector
                    Row(
                      children: [
                        const Text("Quantity",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              IconButton(
                                  onPressed: () {
                                    if (_quantity > 1) {
                                      setState(() => _quantity--);
                                    }
                                  },
                                  icon: const Icon(Icons.remove)),
                              Text("$_quantity",
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                  onPressed: () {
                                    setState(() => _quantity++);
                                  },
                                  icon: const Icon(Icons.add)),
                            ],
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Description
                    const Text("Description",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.grey, height: 1.5)),

                    const SizedBox(height: 80), // Spacing for bottom button
                  ],
                ),
              ),
            ]),
          )
        ],
      ),

      // 3. BOTTOM ACTION BAR
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, -5))
        ]),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _isAdding ? null : _addToCart,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(_isAdding
                ? "Adding..."
                : "ADD TO CART - ₹${finalPrice * _quantity}"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ),
    );
  }
}
