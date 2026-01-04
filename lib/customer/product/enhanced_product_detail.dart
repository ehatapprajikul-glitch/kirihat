import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/cart_helper.dart';
import '../cart_screen.dart';
import '../../services/home_layout_service.dart';

class EnhancedProductDetailScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const EnhancedProductDetailScreen({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<EnhancedProductDetailScreen> createState() => _EnhancedProductDetailScreenState();
}

class _EnhancedProductDetailScreenState extends State<EnhancedProductDetailScreen> {
  final HomeLayoutService _layoutService = HomeLayoutService();
  int _currentImageIndex = 0;
  int _quantity = 1;
  bool _isInWishlist = false;
  List<Map<String, dynamic>> _relatedProducts = [];

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
    _loadRelatedProducts();
  }

  Future<void> _checkWishlistStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('wishlist')
          .doc(widget.productId)
          .get();
      
      if (mounted) setState(() => _isInWishlist = doc.exists);
    } catch (e) {
      debugPrint("Error checking wishlist: $e");
    }
  }

  Future<void> _toggleWishlist() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to add to wishlist")),
      );
      return;
    }

    try {
      var wishlistRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('wishlist')
          .doc(widget.productId);

      if (_isInWishlist) {
        await wishlistRef.delete();
        if (mounted) {
          setState(() => _isInWishlist = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Removed from wishlist")),
          );
        }
      } else {
        await wishlistRef.set({
          'product_id': widget.productId,
          'name': widget.productData['name'] ?? '',
          'price': widget.productData['price'] ?? 0,
          'imageUrl': _getFirstImage(),
          'added_at': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() => _isInWishlist = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Added to wishlist")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error toggling wishlist: $e");
    }
  }

  Future<void> _loadRelatedProducts() async {
    try {
      final category = widget.productData['category'];
      final subcategory = widget.productData['subcategory'];
      final vendorId = widget.productData['vendor_id'];

      if (category == null || vendorId == null) return;

      // Fetch products from same category/subcategory
      final inventoryDocs = await _layoutService.getAggregatedProducts(
        vendorIds: [vendorId],
        limit: 20,
      ).first;

      List<Map<String, dynamic>> related = [];

      for (var doc in inventoryDocs.docs) {
        if (doc.id == widget.productId) continue; // Skip current product

        final inventoryData = doc.data() as Map<String, dynamic>;
        final enriched = await _layoutService.enrichInventoryWithProduct(inventoryData);

        // Match category or subcategory
        if (enriched['category'] == category || 
            (subcategory != null && enriched['subcategory'] == subcategory)) {
          enriched['id'] = doc.id;
          related.add(enriched);
          if (related.length >= 6) break; // Limit to 6 related products
        }
      }

      if (mounted) {
        setState(() => _relatedProducts = related);
      }
    } catch (e) {
      debugPrint('Error loading related products: $e');
    }
  }

  String _getFirstImage() {
    if (widget.productData['images'] != null && 
        (widget.productData['images'] as List).isNotEmpty) {
      return widget.productData['images'][0];
    }
    return widget.productData['imageUrl'] ?? '';
  }

  List<String> _getAllImages() {
    if (widget.productData['images'] != null && 
        (widget.productData['images'] as List).isNotEmpty) {
      return List<String>.from(widget.productData['images']);
    }
    if (widget.productData['imageUrl'] != null && 
        widget.productData['imageUrl'].toString().isNotEmpty) {
      return [widget.productData['imageUrl']];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.productData['name'] ?? 'Product';
    final price = widget.productData['price'] ?? 0;
    final mrp = widget.productData['mrp'] ?? price;
    final unit = widget.productData['unit'] ?? '';
    final description = widget.productData['description'] ?? '';
    final images = _getAllImages();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isInWishlist ? Icons.favorite : Icons.favorite_border,
              color: _isInWishlist ? Colors.red : Colors.black,
            ),
            onPressed: _toggleWishlist,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Carousel
                  _buildImageCarousel(images),
                  
                  // Product Info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name & Unit
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unit.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            unit,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Price
                        Row(
                          children: [
                            Text(
                              '₹$price',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D9759),
                              ),
                            ),
                            if (mrp > price) ...[
                              const SizedBox(width: 12),
                              Text(
                                '₹$mrp',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${(((mrp - price) / mrp) * 100).toStringAsFixed(0)}% OFF',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Description
                        const Text(
                          'Product Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Related Products
                        if (_relatedProducts.isNotEmpty) _buildRelatedProducts(),
                        
                        const SizedBox(height: 80), // Space for sticky bar
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sticky Bottom Bar
          _buildStickyBottomBar(),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 350,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image, size: 80, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 350,
            viewportFraction: 1.0,
            enableInfiniteScroll: images.length > 1,
            onPageChanged: (index, reason) {
              setState(() => _currentImageIndex = index);
            },
          ),
          items: images.map((imageUrl) {
            return CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error, size: 50),
              ),
            );
          }).toList(),
        ),
        
        // Image Indicators
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: images.asMap().entries.map((entry) {
                return Container(
                  width: _currentImageIndex == entry.key ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentImageIndex == entry.key
                        ? const Color(0xFF0D9759)
                        : Colors.grey[300],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildRelatedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'You may also like',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _relatedProducts.length,
          itemBuilder: (context, index) {
            final product = _relatedProducts[index];
            return GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EnhancedProductDetailScreen(
                      productId: product['id'],
                      productData: product,
                    ),
                  ),
                );
              },
              child: _buildRelatedProductCard(product),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRelatedProductCard(Map<String, dynamic> product) {
    final imageUrl = product['imageUrl'] ?? 
        (product['images'] != null && (product['images'] as List).isNotEmpty
            ? product['images'][0]
            : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              image: imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl.isEmpty
                ? const Center(child: Icon(Icons.image, color: Colors.grey))
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          product['name'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          '₹${product['price'] ?? 0}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D9759),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Add to Cart Button
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final success = await CartHelper.addToCart(context, widget.productData);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to cart'),
                      backgroundColor: Color(0xFF0D9759),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D9759),
                side: const BorderSide(color: Color(0xFF0D9759), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Add to Cart',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Buy Now Button
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final success = await CartHelper.addToCart(context, widget.productData);
                if (success && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Buy Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
