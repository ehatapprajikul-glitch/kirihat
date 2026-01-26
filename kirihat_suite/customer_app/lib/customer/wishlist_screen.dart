import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirihat_core/services/wishlist_service.dart';
import '../widgets/product_card.dart';
import 'product/enhanced_product_detail.dart';
import 'widgets/customer_header.dart';
import 'widgets/draggable_cart_wrapper.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final WishlistService _wishlistService = WishlistService();
  List<Map<String, dynamic>> _wishlistProducts = [];
  bool _isLoading = true;
  String? _vendorId;

  StreamSubscription? _subscription;
  Map<String, Map<String, dynamic>>? _inventoryCache;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initStream() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Load inventory cache once (or could be better to load always)
    await _loadInventoryCache();

    // Subscribe to wishlist changes
    _subscription = _wishlistService.watchWishlistSet(userId).listen((idSet) {
      _fetchProducts(idSet.toList());
    });
  }

  Future<void> _loadInventoryCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _vendorId = prefs.getString('assigned_vendor_id');
      
      _inventoryCache = {};
      
      if (_vendorId != null) {
        final inventorySnap = await FirebaseFirestore.instance
            .collection('vendor_inventory')
            .where('vendor_id', isEqualTo: _vendorId)
            .get();

        for (var doc in inventorySnap.docs) {
          final data = doc.data();
          final productId = data['product_id'];
          final isAvailable = data['isAvailable'] ?? true;
          if (productId != null) {
             _inventoryCache![productId] = {
              'price': data['selling_price'],
              'stock_quantity': data['stock_quantity'] ?? 0,
              'isAvailable': isAvailable,
            };
          }
        }
      }
    } catch (e) {
      print("Error loading inventory: $e");
    }
  }

  Future<void> _fetchProducts(List<String> productIds) async {
    if (!mounted) return;
    // Don't set loading true here to avoid flickering on every update, 
    // strictly use internal logic or a skeleton if needed. Used to init.
    if (_wishlistProducts.isEmpty) {
       setState(() => _isLoading = true);
    }

    if (productIds.isEmpty) {
      if (mounted) {
        setState(() {
          _wishlistProducts = [];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      List<Map<String, dynamic>> products = [];
      const int batchSize = 10;

      for (int i = 0; i < productIds.length; i += batchSize) {
        final batchIds = productIds.skip(i).take(batchSize).toList();
        final snap = await FirebaseFirestore.instance
            .collection('master_products')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (var doc in snap.docs) {
          Map<String, dynamic> productData = doc.data();
          productData['id'] = doc.id;

          // Merge with inventory
          if (_inventoryCache != null && _inventoryCache!.containsKey(doc.id)) {
            final inv = _inventoryCache![doc.id]!;
            productData['price'] = inv['price'] ?? productData['price'];
            productData['stock_quantity'] = inv['stock_quantity'] ?? 0;
            productData['isAvailable'] = inv['isAvailable'] ?? true;
            productData['isAvailableInCurrentVendor'] = true;
            productData['vendor_id'] = _vendorId; // CRITICAL for "You may also like"
          } else {
             // Not in current vendor
             productData['stock_quantity'] = 0;
             productData['isAvailable'] = false;
             productData['isAvailableInCurrentVendor'] = false;
             productData['vendor_id'] = _vendorId; // Still set for context
          }

          products.add(productData);
        }
      }

      if (mounted) {
        setState(() {
          _wishlistProducts = products;
          _isLoading = false;
          // Sort newly fetched if needed?
        });
      }
    } catch (e) {
      print('Error fetching wishlist products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'My Wishlist',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DraggableCartWrapper(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : userId == null
                ? _buildLoginPrompt()
                : _wishlistProducts.isEmpty
                    ? _buildEmptyState()
                    : _buildWishlistGrid(),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Please log in to view your wishlist',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Your wishlist is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding products you love!',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Start Shopping'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9759),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 160).floor();
        if (crossAxisCount < 2) crossAxisCount = 2;
        if (crossAxisCount > 4) crossAxisCount = 4;

        double spacing = 12.0;
        double cardWidth = (constraints.maxWidth - (spacing * 2) - ((crossAxisCount - 1) * spacing)) / crossAxisCount;
        double desiredHeight = 270.0;
        double childAspectRatio = cardWidth / desiredHeight;

        return GridView.builder(
          padding: EdgeInsets.all(spacing),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: _wishlistProducts.length,
          itemBuilder: (context, index) {
            final product = _wishlistProducts[index];
            return ProductCard(
              product: product,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EnhancedProductDetailScreen(
                      productId: product['id'],
                      productData: product,
                    ),
                  ),
                );
              },
              onAdd: () {
                if (product['isAvailableInCurrentVendor'] == true) {
                  // ScaffoldMessenger.of(context).showSnackBar(
                  //   const SnackBar(content: Text('Added to cart')),
                  // );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product not available in your area'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}
