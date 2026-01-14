import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartHelper {
  static const String _guestCartKey = 'guest_cart';
  static const String _cartVendorKey = 'cart_vendor_id';
  
  // Notifier for real-time updates
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  /// Initialize notifier (call this on app start if possible, or lazy load)
  static Future<void> init() async {
    await _updateNotifier();
  }

  static Future<void> _updateNotifier() async {
    int count = await getCartCount();
    cartCountNotifier.value = count;
  }

  /// Add product to cart (works for both guest and logged-in users)
  static Future<bool> addToCart(BuildContext context, Map<String, dynamic> productData, {bool showSuccessMessage = true}) async {
    User? user = FirebaseAuth.instance.currentUser;
    
    try {
      String productId = productData['id'] ?? '';
      String vendorId = productData['vendor_id'] ?? '';

      if (productId.isEmpty || vendorId.isEmpty) {
        return false;
      }

      bool success;
      if (user == null) {
        // GUEST MODE - use SharedPreferences
        success = await _addToGuestCart(context, productData, productId, vendorId);
      } else {
        // LOGGED-IN MODE - use Firestore
        success = await _addToFirestoreCart(context, user, productData, productId, vendorId);
      }
      
      if (success) {
        await _updateNotifier();
        
        // Show success message if requested
        if (showSuccessMessage && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to cart!'),
              backgroundColor: Color(0xFF0D9759),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
      return success;
    } catch (e) {
      debugPrint("Cart Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to add to cart")),
        );
      }
      return false;
    }
  }

  /// Add to guest cart (SharedPreferences)
  static Future<bool> _addToGuestCart(
    BuildContext context,
    Map<String, dynamic> productData,
    String productId,
    String vendorId,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Check vendor consistency
    String? cartVendorId = prefs.getString(_cartVendorKey);
    if (cartVendorId != null && cartVendorId != vendorId) {
      bool? shouldReset = await _showVendorMismatchDialog(context);
      if (shouldReset != true) return false;
      
      // Clear guest cart
      await prefs.remove(_guestCartKey);
      await prefs.setString(_cartVendorKey, vendorId);
    } else if (cartVendorId == null) {
      await prefs.setString(_cartVendorKey, vendorId);
    }

    // Get existing cart
    List<Map<String, dynamic>> cart = await _getGuestCartItems();
    
    // Check if product exists
    int existingIndex = cart.indexWhere((item) => item['product_id'] == productId);
    
    if (existingIndex >= 0) {
      // Increment quantity
      cart[existingIndex]['quantity'] = (cart[existingIndex]['quantity'] ?? 1) + 1;
    } else {
      // Add new item
      cart.add({
        'product_id': productId,
        'name': productData['name'] ?? '',
        'price': productData['price'] ?? 0,
        'imageUrl': productData['imageUrl'] ?? 
            (productData['images'] != null && (productData['images'] as List).isNotEmpty 
                ? productData['images'][0] 
                : ''),
        'vendor_id': vendorId,
        'seller_id': productData['seller_id'] ?? '', // Add seller_id
        'quantity': 1,
        'added_at': DateTime.now().toIso8601String(),
      });
    }

    // Save back to SharedPreferences
    await prefs.setString(_guestCartKey, json.encode(cart));
    
    debugPrint('✅ Added to guest cart: $productId, total items: ${cart.length}');
    
    // Success message moved to public method
    debugPrint('✅ Added to guest cart: $productId, total items: ${cart.length}');
    
    return true;
  }

  /// Add to Firestore cart (logged-in users)
  static Future<bool> _addToFirestoreCart(
    BuildContext context,
    User user,
    Map<String, dynamic> productData,
    String productId,
    String vendorId,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cartVendorId = prefs.getString(_cartVendorKey);

    if (cartVendorId != null && cartVendorId != vendorId) {
      bool? shouldReset = await _showVendorMismatchDialog(context);
      if (shouldReset != true) return false;

      // Clear existing cart
      var existingCart = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .get();

      for (var doc in existingCart.docs) {
        await doc.reference.delete();
      }

      await prefs.setString(_cartVendorKey, vendorId);
    } else if (cartVendorId == null) {
      await prefs.setString(_cartVendorKey, vendorId);
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
        'imageUrl': productData['imageUrl'] ?? 
            (productData['images'] != null && (productData['images'] as List).isNotEmpty 
                ? productData['images'][0] 
                : ''),
        'vendor_id': vendorId,
        'seller_id': productData['seller_id'] ?? '', // Add seller_id
        'quantity': 1,
        'added_at': FieldValue.serverTimestamp(),
      });
    }

    return true;
  }

  /// Show vendor mismatch dialog
  static Future<bool?> _showVendorMismatchDialog(BuildContext context) {
    return showDialog<bool>(
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
            child: const Text("RESET & ADD", 
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Get guest cart items from SharedPreferences
  static Future<List<Map<String, dynamic>>> _getGuestCartItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cartJson = prefs.getString(_guestCartKey);
    
    if (cartJson == null) return [];
    
    try {
      List<dynamic> decoded = json.decode(cartJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error decoding guest cart: $e');
      return [];
    }
  }

  /// Get cart count (guest or logged-in)
  static Future<int> getCartCount() async {
    User? user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      // Guest mode
      List<Map<String, dynamic>> cart = await _getGuestCartItems();
      int total = 0;
      for (var item in cart) {
        total += (item['quantity'] ?? 1) as int;
      }
      return total;
    } else {
      // Logged-in mode
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

        return totalCount;
      } catch (e) {
        return 0;
      }
    }
  }

  /// Update cart item quantity
  static Future<void> updateCartItemQuantity(BuildContext context, String productId, int newQuantity) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (newQuantity < 1) {
      await removeCartItem(context, productId);
      return;
    }

    if (user == null) {
      // Guest mode
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> cart = await _getGuestCartItems();
      
      int index = cart.indexWhere((item) => item['product_id'] == productId);
      if (index >= 0) {
        cart[index]['quantity'] = newQuantity;
        await prefs.setString(_guestCartKey, json.encode(cart));
        await _updateNotifier(); // Update UI
      }
    } else {
      // Logged-in mode
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(productId)
            .update({'quantity': newQuantity});
        await _updateNotifier(); // Update UI
      } catch (e) {
        debugPrint("Error updating cart quantity: $e");
      }
    }
  }

  /// Remove cart item
  static Future<void> removeCartItem(BuildContext context, String productId) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Guest mode
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> cart = await _getGuestCartItems();
      
      cart.removeWhere((item) => item['product_id'] == productId);
      await prefs.setString(_guestCartKey, json.encode(cart));
      await _updateNotifier(); // Update UI
    } else {
      // Logged-in mode
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(productId)
            .delete();
        await _updateNotifier(); // Update UI
      } catch (e) {
        debugPrint("Error removing cart item: $e");
      }
    }
  }

  /// Stream cart item quantity
  static Stream<int> watchCartItemQuantity(String productId) {
    User? user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      // Guest mode - listen to notifier changes and re-read prefs
      return Stream<int>.multi((controller) {
        // Initial value
        _getGuestCartItemQuantity(productId).then((qty) {
           if (!controller.isClosed) controller.add(qty);
        });

        // Listen to updates
        void listener() {
          _getGuestCartItemQuantity(productId).then((qty) {
            if (!controller.isClosed) controller.add(qty);
          });
        }

        cartCountNotifier.addListener(listener);

        controller.onCancel = () {
          cartCountNotifier.removeListener(listener);
        };
      });
    }
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .doc(productId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0;
      return doc.data()?['quantity'] ?? 0;
    });
  }

  static Future<int> _getGuestCartItemQuantity(String productId) async {
    List<Map<String, dynamic>> cart = await _getGuestCartItems();
    var item = cart.firstWhere(
      (element) => element['product_id'] == productId,
      orElse: () => {},
    );
    return (item['quantity'] ?? 0) as int;
  }

  /// Migrate guest cart to Firestore after login
  static Future<void> migrateGuestCartToFirestore(String userId) async {
    try {
      List<Map<String, dynamic>> guestCart = await _getGuestCartItems();
      
      if (guestCart.isEmpty) {
        debugPrint('No guest cart to migrate');
        await _updateNotifier();
        return;
      }

      debugPrint('Migrating ${guestCart.length} items from guest cart to Firestore');

      // Add all guest cart items to Firestore
      for (var item in guestCart) {
        String productId = item['product_id'];
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cart')
            .doc(productId)
            .set({
          'product_id': productId,
          'name': item['name'],
          'price': item['price'],
          'imageUrl': item['imageUrl'],
          'vendor_id': item['vendor_id'],
          'seller_id': item['seller_id'] ?? '', // Add seller_id
          'quantity': item['quantity'],
          'added_at': FieldValue.serverTimestamp(),
        });
      }

      // Clear guest cart
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestCartKey);
      
      debugPrint('✅ Guest cart migrated successfully');
      await _updateNotifier(); // Update UI
    } catch (e) {
      debugPrint('Error migrating guest cart: $e');
    }
  }

  /// Clear entire cart
  static Future<void> clearCart() async {
    User? user = FirebaseAuth.instance.currentUser;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    if (user == null) {
      // Clear guest cart
      await prefs.remove(_guestCartKey);
      await prefs.remove(_cartVendorKey);
    } else {
      // Clear Firestore cart
      var cartDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .get();
      
      for (var doc in cartDocs.docs) {
        await doc.reference.delete();
      }
      
      await prefs.remove(_cartVendorKey);
    }
    await _updateNotifier(); // Update UI
  }
}
