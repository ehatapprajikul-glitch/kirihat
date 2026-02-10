import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import 'package:kirihat_core/services/product_display_settings_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'fullscreen_image_viewer.dart';
import 'widgets/collapsible_description.dart';
import 'widgets/product_details_table.dart';
import 'widgets/recommendation_card.dart';
import '../cart_screen.dart';
import 'package:kirihat_core/services/home_layout_service.dart';
import 'package:kirihat_core/services/wishlist_service.dart';
import '../widgets/draggable_cart_wrapper.dart';
import '../../services/recently_viewed_service.dart';
import '../widgets/product_search_delegate.dart'; // Import for search
import '../widgets/voice_search_screen.dart'; // Import for voice search
import '../wishlist_screen.dart'; 
import 'package:kirihat_core/utils/currency_helper.dart'; 

// Define colors locally as they are private in customer_header.dart
const _kGreenDeep    = Color(0xFF064E3B);
const _kGreenVibrant = Color(0xFF059669);

class EnhancedProductDetailScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic>? productData; // Made nullable

  const EnhancedProductDetailScreen({
    super.key,
    required this.productId,
    this.productData,
  });

  @override
  State<EnhancedProductDetailScreen> createState() => _EnhancedProductDetailScreenState();
}

class _EnhancedProductDetailScreenState extends State<EnhancedProductDetailScreen> {
  final HomeLayoutService _layoutService = HomeLayoutService();
  final WishlistService _wishlistService = WishlistService();
  final ProductDisplaySettingsService _settingsService = ProductDisplaySettingsService();
  
  // Scroll controller for collapsible header logic
  late ScrollController _scrollController;
  bool _showStickyHeader = false;

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
    // Initialize ScrollController
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Initialize with provided data or empty
    if (widget.productData != null) {
      _fullProductData = Map<String, dynamic>.from(widget.productData!);
    } else {
      _fullProductData = {};
      _fullProductData['id'] = widget.productId; // Ensure ID is present
    }

    _settingsService.initialize();
    _checkWishlistStatus();
    _initializeData();
    
    // Track this product view
    if (_fullProductData.isNotEmpty) {
      RecentlyViewedService.addProduct(_fullProductData);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Show sticky header when scrolled past a certain threshold (e.g., 280)
    // The customized header height is 350. We want the search bar to appear 
    // when the image is mostly collapsed.
    if (_scrollController.hasClients) {
      final offset = _scrollController.offset;
      final show = offset > 250; 
      if (show != _showStickyHeader) {
        setState(() {
          _showStickyHeader = show;
        });
      }
    }
  }

  Future<void> _initializeData() async {
    try {
      debugPrint('🔍 === INITIALIZATION START ===');
      debugPrint('🔍 Product ID: ${widget.productId}');
      debugPrint('🔍 Initial productData keys: ${widget.productData?.keys.toList() ?? "[]"}');
      
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
          
          // Merge master data with widget data (if any)
          // Keep existing _fullProductData as base (so we don't lose the id set in initState)
          _fullProductData.addAll(masterData);
          
          // Re-ensure id is set (masterData might not have 'id' key)
          _fullProductData['id'] ??= widget.productId;
          
          debugPrint('🔍 Merged data keys: ${_fullProductData.keys.toList()}');
        } else {
          debugPrint('⚠️ Master product document not found!');
          // Keep whatever we had, ensure id is still present
          _fullProductData['id'] ??= widget.productId;
        }
      } catch (e, stack) {
        debugPrint('❌ Error fetching master product: $e');
        debugPrintStack(stackTrace: stack);
        // Ensure id is still present on error
        _fullProductData['id'] ??= widget.productId;
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
          if (data.containsKey('is_available')) {
             _fullProductData['is_available'] = data['is_available'];
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
        sourceVendorId: _fullProductData['vendor_id'],
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

      debugPrint('🔍 _loadRelatedProducts: category=$category, vendorId=$vendorId, brand=$brand');

      if (category == null || vendorId == null) {
        debugPrint('⚠️ _loadRelatedProducts: SKIPPED - category or vendorId is null');
        return;
      }

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
    if (_fullProductData['images'] != null && 
        (_fullProductData['images'] as List).isNotEmpty) {
      return List<String>.from(_fullProductData['images']);
    }
    if (_fullProductData['imageUrl'] != null && 
        _fullProductData['imageUrl'].toString().isNotEmpty) {
      return [_fullProductData['imageUrl']];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    // Show loader if we rely on fetching and don't have data yet
    if (_isLoading && (_fullProductData.isEmpty || _fullProductData.length <= 1)) {
       return const Scaffold(
         body: Center(child: CircularProgressIndicator()),
       );
    }

    final name = _fullProductData['name'] ?? 'Product';
    final category = _fullProductData['category'] ?? '';
    final subcategory = _fullProductData['subcategory'];
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
      bottomNavigationBar: _buildStickyBottomBar(),
      body: DraggableCartWrapper(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 350.0,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: _showStickyHeader ? 1 : 0,
              leading: _buildCircleButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
                isSticky: _showStickyHeader,
              ),
              // Search Bar in Title - transitions with opacity
              titleSpacing: 0,
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showStickyHeader ? 1.0 : 0.0,
                child: _showStickyHeader
                    ? Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _buildStickySearchBar(),
                      )
                    : const SizedBox.shrink(),
              ),
              actions: [
                 // Wishlist Button - shows in both states but styling changes?
                 // We'll keep it simple: circle button always, but background might change if needed.
                 // For now, same style works.
                 if (!_showStickyHeader) ...[
                   _buildCircleButton(
                     icon: _isInWishlist ? Icons.favorite : Icons.favorite_border,
                     color: _isInWishlist ? Colors.red : null,
                     onTap: _toggleWishlist,
                     isSticky: false,
                   ),
                   const SizedBox(width: 8),
                   _buildCircleButton(
                     icon: Icons.share,
                     onTap: _shareProduct,
                     isSticky: false,
                   ),
                   const SizedBox(width: 16),
                 ] else ...[
                   // When sticky, we might want fewer actions or different style.
                   // User asked for "icon and search bar". 
                   // Let's hide actions in sticky mode to make room for search bar, 
                   // OR keep them if space permits. 
                   // If broad search bar is needed, maybe Actions are too much?
                   // User said "shows only icon and search bar". 
                   // I assume "icon" means back icon. 
                   // So I can hide actions in sticky mode.
                 ]
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildImageCarousel(images),
                collapseMode: CollapseMode.parallax,
              ),
            ),
            
            // Product Info
            SliverToBoxAdapter(
              child: _buildProductInfo(),
            ),
            
            // Details Table
            SliverToBoxAdapter(
              child: _buildDetailsTableSection(disclaimerText),
            ),
            
            // Related Products
            SliverToBoxAdapter(
              child: _buildRelatedProducts(),
            ),
            
            // Bottom Padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // Space for bottom bar
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickySearchBar() {
    return GestureDetector(
      onTap: () {
         showSearch(
          context: context,
          delegate: ProductSearchDelegate(
            categoryName: _fullProductData['category'],
            // Pass related products as a hint of local products, or empty
            products: _relatedProducts, 
          ),
        );
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search, color: _kGreenVibrant, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search products...',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Mic icon
            GestureDetector(
               onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VoiceSearchScreen(),
                    ),
                  );
                  if (result != null && result is String && mounted) {
                     showSearch(
                        context: context,
                        delegate: ProductSearchDelegate(
                          initialQuery: result,
                        ),
                     );
                  }
               },
               child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.mic, color: _kGreenVibrant, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    required bool isSticky,
  }) {
    // Determine background: 
    // If sticky (white background), maybe transparent or light grey?
    // If not sticky (image background), semi-transparent white.
    // However, if sticky, the AppBar is white, so button should probably have no bg or light bg.
    // The "leading" widget in SliverAppBar has constrained width, so we wrap in Center/Container.
    
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSticky ? Colors.transparent : Colors.white.withOpacity(0.7),
            shape: BoxShape.circle,
            // Add custom visual if needed
          ),
          child: Icon(
            icon,
            color: color ?? (isSticky ? Colors.black : Colors.black),
            size: 22,
          ),
        ),
      ),
    );
  }

  Future<void> _shareProduct() async {
    final name = _fullProductData['name'] ?? 'Product';
    final price = _fullProductData['price'] ?? 0;
    
    // Get product image URL
    final images = _getAllImages();
    final imageUrl = images.isNotEmpty ? images.first : null;
    
    final shareText = 'Check out $name on Kirihat!\n\n'
        'Price: ₹$price\n\n'
        'View Product: https://kirihat.com/product?id=${widget.productId}\n\n'
        'Get the app: https://play.google.com/store/apps/details?id=com.kirihat.live_app';
    
    // Try to share with image, fallback to text-only
    if (imageUrl != null) {
      try {
        // Download image to temp file
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/share_product.jpg');
          await file.writeAsBytes(response.bodyBytes);
          
          await Share.shareXFiles(
            [XFile(file.path)],
            text: shareText,
            subject: 'Product Recommendation from Kirihat',
          );
          return;
        }
      } catch (e) {
        debugPrint('Error sharing with image: $e');
      }
    }
    
    // Fallback to text-only share
    await Share.share(
      shareText,
      subject: 'Product Recommendation from Kirihat',
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

    // Wrap in stack to show dots if needed, but FlexibleSpaceBar handles clipping.
    return Container(
      color: Colors.white,
      height: 350,
      child: Stack(
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
                  fit: BoxFit.contain, // Maintain aspect ratio
                  memCacheWidth: 1080,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image)),
                ),
              );
            }).toList(),
          ),
          
          if (images.length > 1 && _settingsService.showImageDots)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
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
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
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
    final productId = _fullProductData['id'];
    
    // Safety: If no ID, show disabled Add button
    if (productId == null) {
      return const SizedBox.shrink();
    }

    // Check stock availability
    final int stockQuantity = (_fullProductData['stock_quantity'] ?? 0) is int 
        ? _fullProductData['stock_quantity'] ?? 0
        : ((_fullProductData['stock_quantity'] ?? 0) as num).toInt();
    final bool isAvailable = _fullProductData['is_available'] ?? true;
    final bool isOutOfStock = stockQuantity <= 0 || !isAvailable;

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
      child: isOutOfStock
          // Out of Stock UI
          ? Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Out of Stock',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          // Normal Add to Cart / Buy Now UI
          : Row(
              children: [
                Expanded(
                  child: StreamBuilder<int>(
                    stream: CartHelper.watchCartItemQuantity(productId),
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
                                    _fullProductData['id'], 
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
                                  if (_settingsService.showStockCount) {
                                    if (quantity < stockQuantity) {
                                      CartHelper.updateCartItemQuantity(
                                        context, 
                                        _fullProductData['id'], 
                                        quantity + 1
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Max stock reached"), 
                                          duration: Duration(milliseconds: 500)
                                        ),
                                      );
                                    }
                                  } else {
                                     CartHelper.updateCartItemQuantity(
                                        context, 
                                        _fullProductData['id'], 
                                        quantity + 1
                                      );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      return ElevatedButton(
                        onPressed: () async {
                          if (_settingsService.showAddToCart) {
                            final success = await CartHelper.addToCart(context, _fullProductData);
                            if (success && mounted) {
                              // Success handled by helper
                            }
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
                      if (_settingsService.showAddToCart) {
                        final success = await CartHelper.addToCart(context, _fullProductData);
                        if (success && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CartScreen()),
                          );
                        }
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
    final name = _fullProductData['name'] ?? 'Product';
    final price = _fullProductData['price'] ?? 0;
    final mrp = _fullProductData['mrp'] ?? price;
    final unit = _fullProductData['unit'] ?? '';

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