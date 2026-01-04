import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartHelper {
  static Future<bool> addToCart(BuildContext context, Map<String, dynamic> productData) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to add items to cart")),
      );
      return false;
    }

    try {
      String productId = productData['id'] ?? '';
      String vendorId = productData['vendor_id'] ?? '';

      if (productId.isEmpty || vendorId.isEmpty) {
        return false;
      }

      // Check if cart has items from different vendor
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cartVendorId = prefs.getString('cart_vendor_id');

      if (cartVendorId != null && cartVendorId != vendorId) {
        // Show dialog to reset cart
        bool? shouldReset = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Start new basket?"),
            content: const Text("You have items from another shop. Clear existing cart?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("RESET & ADD", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldReset != true) {
          return false;
        }

        // Clear existing cart
        var existingCart = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .get();

        for (var doc in existingCart.docs) {
          await doc.reference.delete();
        }

        await prefs.setString('cart_vendor_id', vendorId);
      } else if (cartVendorId == null) {
        await prefs.setString('cart_vendor_id', vendorId);
      }

      // Check if product already in cart
      var existingItem = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(productId)
          .get();

      if (existingItem.exists) {
        // Increment quantity
        int currentQty = existingItem.data()?['quantity'] ?? 1;
        await existingItem.reference.update({'quantity': currentQty + 1});
      } else {
        // Add new item
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(productId)
            .set({
          'product_id': productId,
          'name': productData['name'] ?? '',
          'price': productData['price'] ?? 0,
          'imageUrl': productData['imageUrl'] ?? (productData['images'] != null && (productData['images'] as List).isNotEmpty 
              ? productData['images'][0] 
              : ''),
          'vendor_id': vendorId,
          'quantity': 1,
          'added_at': FieldValue.serverTimestamp(),
        });
      }

      // Update cart count
      await _updateCartCount(user.uid);

      return true;
    } catch (e) {
      debugPrint("Cart Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add to cart")),
      );
      return false;
    }
  }

  static Future<int> getCartCount() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .get();

      int totalCount = 0;
      for (var doc in snapshot.docs) {
        totalCount += (doc.data()['quantity'] ?? 1) as int;
      }

      // Save to prefs for quick access
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cart_count', totalCount);

      return totalCount;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> _updateCartCount(String uid) async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('cart').get();

      int totalCount = 0;
      for (var doc in snapshot.docs) {
        totalCount += (doc.data()['quantity'] ?? 1) as int;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cart_count', totalCount);
    } catch (e) {
      debugPrint("Error updating cart count: $e");
    }
  }

  static Stream<int> cartCountStream() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .snapshots()
        .map((snapshot) {
      int totalCount = 0;
      for (var doc in snapshot.docs) {
        totalCount += (doc.data()['quantity'] ?? 1) as int;
      }
      return totalCount;
    });
  }
}
