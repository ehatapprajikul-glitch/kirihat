import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import 'package:kirihat_core/services/product_display_settings_service.dart';
import 'package:share_plus/share_plus.dart';
import 'fullscreen_image_viewer.dart';
import 'widgets/collapsible_description.dart';
import 'widgets/product_details_table.dart';
import 'widgets/recommendation_card.dart';
import '../cart_screen.dart';
import 'package:kirihat_core/services/home_layout_service.dart';
import 'package:kirihat_core/services/wishlist_service.dart';
import '../widgets/draggable_cart_wrapper.dart';
import '../../services/recently_viewed_service.dart';
import '../widgets/floating_cart_button.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

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
  final WishlistService _wishlistService = WishlistService();
  final ProductDisplaySettingsService _settingsService = ProductDisplaySettingsService();
  int _currentImageIndex = 0;
  int _quantity = 1;
  bool _isInWishlist = false;
  List<Map<String, dynamic>> _relatedProducts = [];
  String? _sellerName;
  String? _sellerCity;
  String? _sellerState;
  Map<String, Map<String, dynamic>> _groupedSpecifications = {};
  Map<String, dynamic> _fullProductData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fullProductData = Map<String, dynamic>.from(widget.productData);
    _settingsService.initialize();
    _checkWishlistStatus();
    _initializeData();
    
    // Track this product view
    RecentlyViewedService.addProduct(widget.productData);
  }

  Future<void> _initializeData() async {
    try {
      debugPrint('🔍 === INITIALIZATION START ===');
      debugPrint('🔍 Product ID: ${widget.productId}');
      debugPrint('🔍 Initial productData keys: ${widget.productData.keys.toList()}');
      
      // Always fetch from master_products to get complete data
      try {
        debugPrint('🔍 Fetching from master_products...');
        final doc = await FirebaseFirestore.instance
            .collection('master_products')
            .doc(widget.productId)
            .get();
            
        if (doc.exists && doc.data() != null) {
          final masterData = doc.data()!;
          debugPrint('✅ Master product data fetched');
          debugPrint('🔍 Master data keys: ${masterData.keys.toList()}');
          debugPrint('🔍 Has specifications: ${masterData.containsKey('specifications')}');
          
          if (masterData.containsKey('specifications')) {
            debugPrint('🔍 Specifications data: ${masterData['specifications']}');
          }
          
          // Merge master data with widget data
          _fullProductData = Map<String, dynamic>.from(widget.productData);
          _fullProductData.addAll(masterData);
          
          debugPrint('🔍 Merged data keys: ${_fullProductData.keys.toList()}');
        } else {
          debugPrint('⚠️ Master product document not found!');
        }
      } catch (e, stack) {
        debugPrint('❌ Error fetching master product: $e');
        debugPrintStack(stackTrace: stack);
      }

      // Load dependent data
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        await Future.wait([
          _fetchSellerInfo(),
          _fetchVendorInventoryData(), // Added to fetch Return Policy
          _loadMergedSpecifications(),
          _loadRelatedProducts(),
        ]);
      }
      
      debugPrint('🔍 === INITIALIZATION COMPLETE ===');
    } catch (e, stack) {
      debugPrint('❌ Error in _initializeData: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchSellerInfo() async {
    final vendorId = _fullProductData['vendor_id'];
    debugPrint('🔍 Fetching seller info for vendor_id: $vendorId');
    if (vendorId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('sellers')
          .doc(vendorId)
          .get();
          
      if (!mounted) return;
      
      if (doc.exists) {
        final data = doc.data();
        debugPrint('✅ Seller data fetched: $data');
        setState(() {
          _sellerName = data?['business_name'];
          _sellerCity = data?['city'];
          _sellerState = data?['state'];
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching seller info: $e");
    }
  }

  Future<void> _fetchVendorInventoryData() async {
    final vendorId = _fullProductData['vendor_id'];
    if (vendorId == null) {
       debugPrint("⚠️ No vendor_id found, cannot fetch inventory policy");
       return;
    }

    try {
      debugPrint('🔍 Fetching vendor_inventory for policy. Vendor: $vendorId, Product: ${widget.productId}');
      final query = await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('product_id', isEqualTo: widget.productId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        debugPrint('✅ Inventory data fetched: ${data.keys.toList()}');
        
        setState(() {
          // Merge specific fields we care about
          if (data.containsKey('return_policy_type')) {
            _fullProductData['return_policy_type'] = data['return_policy_type'];
          }
          if (data.containsKey('return_window_days')) {
            _fullProductData['return_window_days'] = data['return_window_days'];
          }
          // Also sync price/stock if available to be latest
          if (data.containsKey('selling_price')) {
             _fullProductData['selling_price'] = data['selling_price'];
             _fullProductData['price'] = data['selling_price']; // Update display price
          }
           if (data.containsKey('stock_quantity')) {
             _fullProductData['stock_quantity'] = data['stock_quantity'];
          }
        });
      } else {
        debugPrint("⚠️ No vendor_inventory doc found");
      }
    } catch (e) {
      debugPrint("❌ Error fetching inventory data: $e");
    }
  }

  Future<void> _loadMergedSpecifications() async {
    debugPrint('🔍 === LOADING SPECIFICATIONS ===');
    
    // Get product's own specifications
    final productSpecs = _fullProductData['specifications'] as Map<String, dynamic>? ?? {};
    debugPrint('🔍 Product Specs: $productSpecs');
    debugPrint('🔍 Product Specs count: ${productSpecs.length}');
    debugPrint('🔍 Full product data keys: ${_fullProductData.keys.toList()}');
    
    // If no specs at all, show warning
    if (productSpecs.isEmpty) {
      debugPrint('⚠️ ========================================');
      debugPrint('⚠️ NO SPECIFICATIONS FOUND IN PRODUCT DATA');
      debugPrint('⚠️ Product ID: ${widget.productId}');
      debugPrint('⚠️ This product needs specifications added in master_products collection');
      debugPrint('⚠️ ========================================');
      if (mounted) {
        setState(() {
          _groupedSpecifications = {};
        });
      }
      return;
    }
    
    // Get category info
    final categoryId = _fullProductData['category_id'] as String?;
    final subcategoryId = _fullProductData['subcategory_id'] as String?;
    
    debugPrint('🔍 Category ID: $categoryId');
    debugPrint('🔍 Subcategory ID: $subcategoryId');
    
    // If no category template, show all specs in General section
    if (categoryId == null || categoryId.isEmpty) {
      debugPrint('⚠️ No category_id, using General section');
      if (mounted) {
        setState(() {
          _groupedSpecifications = {
            'General': Map<String, dynamic>.from(productSpecs)
          };
        });
      }
      return;
    }
    
    try {
      debugPrint('🔍 Fetching category specifications template...');
      QuerySnapshot query;
      
      // Try subcategory template first
      if (subcategoryId != null && subcategoryId.isNotEmpty) {
        query = await FirebaseFirestore.instance
            .collection('category_specifications')
            .where('category_id', isEqualTo: categoryId)
            .where('subcategory_id', isEqualTo: subcategoryId)
            .orderBy('version', descending: true)
            .limit(1)
            .get();
            
        debugPrint('🔍 Subcategory query results: ${query.docs.length}');
            
        if (query.docs.isEmpty) {
          debugPrint('🔍 No subcategory template, trying category only...');
          query = await FirebaseFirestore.instance
              .collection('category_specifications')
              .where('category_id', isEqualTo: categoryId)
              .orderBy('version', descending: true)
              .limit(1)
              .get();
          debugPrint('🔍 Category query results: ${query.docs.length}');
        }
      } else {
        query = await FirebaseFirestore.instance
            .collection('category_specifications')
            .where('category_id', isEqualTo: categoryId)
            .orderBy('version', descending: true)
            .limit(1)
            .get();
        debugPrint('🔍 Category query results: ${query.docs.length}');
      }
      
      // If no template found, use General section
      if (query.docs.isEmpty) {
        debugPrint('⚠️ No template found, using General section');
        if (mounted) {
          setState(() {
            _groupedSpecifications = {
              'General': Map<String, dynamic>.from(productSpecs)
            };
          });
        }
        return;
      }
      
      // Process template
      final categoryDoc = query.docs.first;
      final templateData = categoryDoc.data() as Map<String, dynamic>;
      final fields = templateData['fields'] as List<dynamic>? ?? [];
      
      debugPrint('✅ Template found: ${categoryDoc.id}');
      debugPrint('🔍 Template fields count: ${fields.length}');
      debugPrint('🔍 Template fields: $fields');
      
      // Group specs by section
      final Map<String, Map<String, dynamic>> grouped = {};
      final Map<String, int> sectionOrders = {};
      final Set<String> usedKeys = {};

      for (var field in fields) {
        // Support both fieldName and field_name
        final fieldName = (field['fieldName'] ?? field['field_name']) as String?;
        if (fieldName == null) continue;
        
        final section = (field['section'] ?? field['section']) as String? ?? 'General';
        final sectionOrder = (field['sectionOrder'] ?? field['section_order']) as int? ?? 0;
        
        // Update section order
        sectionOrders[section] = sectionOrder;

        // Check if this field exists in product specs
        if (productSpecs.containsKey(fieldName)) {
          if (!grouped.containsKey(section)) {
            grouped[section] = {};
          }
          grouped[section]![fieldName] = productSpecs[fieldName];
          usedKeys.add(fieldName);
          debugPrint('✅ Mapped field: $fieldName -> $section');
        }
      }
      
      // Add unmapped specs to "Additional Specifications"
      productSpecs.forEach((key, value) {
        if (!usedKeys.contains(key)) {
          if (!grouped.containsKey('Additional Specifications')) {
            grouped['Additional Specifications'] = {};
            sectionOrders['Additional Specifications'] = 999;
          }
          grouped['Additional Specifications']![key] = value;
          debugPrint('✅ Added to Additional: $key');
        }
      });
      
      // Sort sections
      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) => (sectionOrders[a] ?? 0).compareTo(sectionOrders[b] ?? 0));
        
      final Map<String, Map<String, dynamic>> finalGrouped = {};
      for (var key in sortedKeys) {
        if (grouped[key]!.isNotEmpty) {
          finalGrouped[key] = grouped[key]!;
        }
      }
      
      debugPrint('✅ Final grouped sections: ${finalGrouped.keys.toList()}');
      debugPrint('✅ Final grouped specs: $finalGrouped');
      
      if (mounted) {
        setState(() => _groupedSpecifications = finalGrouped);
      }
    } catch (e, stack) {
      debugPrint('❌ Error merging specifications: $e');
      debugPrintStack(stackTrace: stack);
      
      // Fallback: show all specs in General section
      if (mounted) {
        setState(() {
          _groupedSpecifications = {
            'General': Map<String, dynamic>.from(productSpecs)
          };
        });
      }
    }
  }

  Future<void> _checkWishlistStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final inList = await _wishlistService.isInWishlist(userId, widget.productId);
      if (mounted) setState(() => _isInWishlist = inList);
    } catch (e) {
      debugPrint("Error checking wishlist: $e");
    }
  }

  Future<void> _toggleWishlist() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to add to wishlist")),
      );
      return;
    }

    try {
      final wasAdded = await _wishlistService.toggleWishlist(
        userId,
        widget.productId,
        sourceVendorId: widget.productData['vendor_id'],
      );

      if (mounted) {
        setState(() => _isInWishlist = wasAdded);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(wasAdded ? "❤️ Added to wishlist" : "Removed from wishlist")),
        );
      }
    } catch (e) {
      debugPrint("Error toggling wishlist: $e");
    }
  }

  Future<void> _loadRelatedProducts() async {
    try {
      final category = _fullProductData['category'];
      final subcategory = _fullProductData['subcategory'];
      final vendorId = _fullProductData['vendor_id'];
      final brand = _fullProductData['brand'];
      final currentPrice = _fullProductData['price'] ?? 0;

      if (category == null || vendorId == null) return;

      final priceRange = _settingsService.getPriceRange(currentPrice.toDouble());
      final minPrice = priceRange['min']!;
      final maxPrice = priceRange['max']!;

      final inventoryDocs = await _layoutService.getAggregatedProducts(
        vendorIds: [vendorId],
        limit: 30,
      ).first;

      List<Map<String, dynamic>> related = [];
      final maxProducts = _settingsService.numberOfRecommendations;

      for (var doc in inventoryDocs.docs) {
        if (_settingsService.excludeCurrentProduct && doc.id == widget.productId) continue;

        final inventoryData = doc.data() as Map<String, dynamic>;
        final enriched = await _layoutService.enrichInventoryWithProduct(inventoryData);

        bool matchesFilter = true;

        if (_settingsService.filterSameCategory) {
          matchesFilter = matchesFilter && (enriched['category'] == category || 
              (subcategory != null && enriched['subcategory'] == subcategory));
        }

        if (_settingsService.filterSimilarPrice) {
          final productPrice = enriched['price'] ?? 0;
          matchesFilter = matchesFilter && 
              (productPrice >= minPrice && productPrice <= maxPrice);
        }

        if (_settingsService.recommendationLogic == 'same_brand' && brand != null) {
          matchesFilter = matchesFilter && (enriched['brand'] == brand);
        }

        if (matchesFilter) {
          enriched['id'] = doc.id;
          related.add(enriched);
          if (related.length >= maxProducts) break;
        }
      }

      if (mounted) {
        setState(() => _relatedProducts = related);
      }
    } catch (e) {
      debugPrint('Error loading related products: $e');
    }
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
    final category = widget.productData['category'] ?? '';
    final subcategory = widget.productData['subcategory'];
    final images = _getAllImages();

    final disclaimerText = _settingsService.getDisclaimerForCategory(
      category, 
      subcategoryName: subcategory
    );

    if (_isLoading) {
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
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
            onPressed: () async {
              final name = widget.productData['name'] ?? 'Product';
              final price = widget.productData['price'] ?? 0;
              final category = widget.productData['category'] ?? '';
              
              await Share.share(
                'Check out this amazing product on Kirihat!\n\n'
                '$name\n'
                'Price: ${CurrencyHelper.format(price)}\n\n'
                'Download Kirihat app to order now!',
                subject: 'Product Recommendation from Kirihat',
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildStickyBottomBar(),
      body: DraggableCartWrapper(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._settingsService.sectionOrder.map((section) {
                      switch (section) {
                        case 'images':
                          return _buildImageCarousel(images);
                        case 'overview':
                          return _buildProductInfo();
                        case 'details':
                          return _buildDetailsTableSection(disclaimerText);
                        case 'related':
                          return _buildRelatedProducts();
                        default:
                          return const SizedBox.shrink();
                      }
                    }).toList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const FloatingCartButton(),
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
            return GestureDetector(
              onTap: () {
                if (_settingsService.enableImageZoom && _settingsService.enableFullscreenMode) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullscreenImageViewer(
                        imageUrls: images,
                        initialIndex: _currentImageIndex,
                        showCounter: _settingsService.showImageCounter,
                      ),
                    ),
                  );
                }
              },
              child: CachedNetworkImage(
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
              ),
            );
          }).toList(),
        ),
        
        if (images.length > 1 && _settingsService.showImageDots)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: images.asMap().entries.map((entry) {
                final isActive = _currentImageIndex == entry.key;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: isActive ? 32 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isActive
                        ? const Color(0xFF0D9759)
                        : Colors.grey[300],
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0D9759).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildRelatedProducts() {
    if (!_settingsService.showRecommendationsSection || _relatedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            _settingsService.recommendationsSectionTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _relatedProducts.length,
              itemBuilder: (context, index) {
                final product = _relatedProducts[index];
                return RecommendationCard(
                  product: product,
                  showDiscountBadge: _settingsService.showDiscountBadge,
                  showAddButton: _settingsService.showAddButton,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<int>(
              stream: CartHelper.watchCartItemQuantity(widget.productData['id']),
              builder: (context, snapshot) {
                final int quantity = snapshot.data ?? 0;
                
                if (quantity > 0) {
                  return Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9759),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white),
                          onPressed: () {
                            CartHelper.updateCartItemQuantity(
                              context, 
                              widget.productData['id'], 
                              quantity - 1
                            );
                          },
                        ),
                        Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () {
                            CartHelper.updateCartItemQuantity(
                              context, 
                              widget.productData['id'], 
                              quantity + 1
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }

                return ElevatedButton(
                  onPressed: () async {
                    final success = await CartHelper.addToCart(context, widget.productData);
                    if (success && mounted) {
                      // Success handled by helper
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
                );
              },
            ),
          ),
          const SizedBox(width: 12),
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

  Widget _buildProductInfo() {
    final name = widget.productData['name'] ?? 'Product';
    final price = widget.productData['price'] ?? 0;
    final mrp = widget.productData['mrp'] ?? price;
    final unit = widget.productData['unit'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: Color(0xFF1C1C1C),
            ),
          ),
          
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              unit,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyHelper.format(price),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D9759),
                  height: 1.0,
                ),
              ),
              if (mrp > price) ...[
                const SizedBox(width: 8),
                Text(
                  CurrencyHelper.format(mrp),
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[500],
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(((mrp - price) / mrp) * 100).toStringAsFixed(0)}% OFF',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0D9759),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          // Always show Return Policy section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9), // Light Green 50
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF66BB6A), width: 1), // Green 400
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43A047).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9), // Green 100
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: Color(0xFF2E7D32), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Return Policy",
                        style: TextStyle(
                          color: Color(0xFF1B5E20), // Green 900
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                          textBaseline: TextBaseline.alphabetic
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getReturnPolicyText(_fullProductData),
                        style: const TextStyle(
                          color: Color(0xFF2E7D32), // Green 800
                          fontWeight: FontWeight.w700, 
                          fontSize: 15
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getReturnPolicyText(Map<String, dynamic> data) {
    String type = data['return_policy_type'] ?? 'No Return';
    int days = data['return_window_days'] ?? 0;
    
    if (type == 'No Return') return "No Returns Available";
    
    String dayText = (days == 0) ? "Same Day" : "$days Days";
    return "$dayText $type";
  }

  Widget _buildDetailsTableSection(String disclaimerText) {
    debugPrint('🔍 === RENDERING DETAILS SECTION ===');
    debugPrint('🔍 showProductDetailsTable: ${_settingsService.showProductDetailsTable}');
    debugPrint('🔍 _groupedSpecifications: $_groupedSpecifications');
    debugPrint('🔍 Sections: ${_groupedSpecifications.keys.toList()}');
    
    if (!_settingsService.showProductDetailsTable) {
      debugPrint('⚠️ Details table disabled in settings');
      return const SizedBox.shrink();
    }

    // Log specification rendering
    if (_groupedSpecifications.isNotEmpty) {
      debugPrint('✅ Rendering ${_groupedSpecifications.length} specification sections');
    }

    // Get sorted section keys to maintain order
    final sortedSections = _groupedSpecifications.keys.toList();
    final hasMultipleSections = sortedSections.length > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Expandable Specifications Container
          if (_groupedSpecifications.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ExpansionTile(
                title: const Text(
                  'Item Details',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                initiallyExpanded: true,
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                shape: const Border(),
                children: [
                  // Show first section by default
                  if (sortedSections.isNotEmpty) ...[
                    _buildSpecificationSection(
                      sortedSections.first,
                      _groupedSpecifications[sortedSections.first]!,
                      showHeader: hasMultipleSections,
                    ),
                    
                    // Show remaining sections in a nested expandable if there are more
                    if (hasMultipleSections && sortedSections.length > 1) ...[
                      const SizedBox(height: 12),
                      ExpansionTile(
                        title: Text(
                          'view more',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0D9759),
                          ),
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        initiallyExpanded: false,
                        backgroundColor: Colors.transparent,
                        collapsedBackgroundColor: Colors.transparent,
                        shape: const Border(),
                        children: [
                          ...sortedSections.skip(1).map((sectionName) {
                            return _buildSpecificationSection(
                              sectionName,
                              _groupedSpecifications[sectionName]!,
                              showHeader: true,
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Product specifications are not available yet',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Seller Information
          if (_settingsService.showSellerInfo && _sellerName != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ExpansionTile(
                title: const Text(
                  'Seller Information',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                initiallyExpanded: true,
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                shape: const Border(),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Sold by',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _sellerName!,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_sellerCity != null || _sellerState != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Sells from',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(
                              [_sellerCity, _sellerState]
                                  .where((e) => e != null && e.isNotEmpty)
                                  .join(', '),
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Disclaimer
          const SizedBox(height: 8),
          Text(
            'Disclaimer from Kirihat: $disclaimerText',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Helper method to build individual specification section
  Widget _buildSpecificationSection(
    String sectionName,
    Map<String, dynamic> fields,
    {bool showHeader = true}
  ) {
    // Filter empty fields
    final nonEmptyFields = Map<String, dynamic>.fromEntries(
      fields.entries.where((field) {
        if (_settingsService.excludedFields.contains(field.key)) return false;
        if (field.value == null) return false;
        
        final stringValue = field.value.toString().trim();
        if (stringValue.isEmpty || stringValue.toLowerCase() == 'null') return false;
        
        return true;
      })
    );
    
    if (nonEmptyFields.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header (only if showHeader is true)
        if (showHeader) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sectionName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF1C1C1C),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Section Fields
        ...nonEmptyFields.entries.map((field) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    field.key,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    field.value.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}