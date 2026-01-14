import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/draggable_cart_wrapper.dart';
import 'widgets/customer_header.dart';
import 'widgets/global_search_bar.dart';
import '../widgets/product_card.dart';
import 'package:kirihat_core/models/collection_model.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:kirihat_core/services/smart_collection_service.dart';
import 'package:kirihat_core/services/wishlist_service.dart';
import 'dart:async';
import 'onboarding/change_location_screen.dart';
import 'cart_screen.dart';
import 'product/enhanced_product_detail.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import 'widgets/product_search_delegate.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryName; // "All Products" by default usually

  const CategoryProductsScreen({super.key, required this.categoryName});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final SmartCollectionService _smartCollectionService = SmartCollectionService();
  final WishlistService _wishlistService = WishlistService();
  StreamSubscription? _wishlistSub;

  String? _userId;
  String? _vendorId;
  String? _selectedArea;
  bool _isLoading = true;
  bool _isProductLoading = false; // Dedicated loading state for lists

  // Data
  List<CollectionModel> _collections = [];
  Map<String, Map<String, dynamic>> _inventoryMap = {}; // productId -> {price, stock, isAvailable...}
  List<Map<String, dynamic>> _adminCategories = [];
  List<Map<String, dynamic>> _displayProducts = []; // Final merged products to show

  // Selection
  String _selectedType = 'All'; // 'All', 'Collection', 'Category'
  String _selectedId = 'all'; // 'all', collectionId, or categoryName

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _wishlistSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _vendorId = prefs.getString('assigned_vendor_id');
      _selectedArea = prefs.getString('current_area');
      _userId = FirebaseAuth.instance.currentUser?.uid;

      // Setup wishlist stream
      if (_userId != null) {
        _wishlistSub?.cancel();
        _wishlistSub = _wishlistService.watchWishlistSet(_userId!).listen((_) {
            if (mounted && _selectedType == 'Collection' && _selectedId == 'smart_wishlist') {
               debugPrint("Real-time Wishlist Update Triggered");
               _updateDisplayProducts();
            }
        });
      }

      print('DEBUG _loadData:');
      print('  - vendorId from assigned_vendor_id: $_vendorId');
      print('  - selectedArea: $_selectedArea');

      if (_vendorId == null) {
        _vendorId = prefs.getString('vendorId');
        print('  - Fallback vendorId from vendorId key: $_vendorId');
      }
      
      // Final fallback: Try loading from session service
      if (_vendorId == null) {
        print('  - Attempting to load from SessionService...');
        final sessionService = SessionService();
        final session = await sessionService.getSession();
        _vendorId = session['vendorId'] as String?;
        print('  - SessionService vendorId: $_vendorId');
        
        // Last resort: Try loading from Firestore
        if (_vendorId == null) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            print('  - Attempting Firestore restore...');
            final restored = await sessionService.loadSessionFromFirestore(user.uid);
            if (restored) {
              _vendorId = prefs.getString('assigned_vendor_id');
              _selectedArea = prefs.getString('current_area');
              print('  - Firestore restore successful! vendorId: $_vendorId');
            }
          }
        }
      }
      
      print('  - Final vendorId to use: $_vendorId');

      if (_vendorId != null) {
        // 1. Fetch Structural Data (Admin)
        await Future.wait([
          _fetchCollections(),
          _fetchCategoriesFromAdmin(),
        ]);
        
        // 2. Fetch Availability Data (Vendor)
        await _fetchVendorInventory();
        
        // 3. Compute Initial Display (All Products)
        await _updateDisplayProducts();
      } else {
        print('ERROR: No vendor ID found! User might not be logged in or assigned to a vendor.');
      }
    } catch (e) {
      print('Error in _loadData: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCollections() async {
    try {
      // 1. Fetch Standard Collections
      final snap = await FirebaseFirestore.instance
          .collection('product_collections')
          .orderBy('sort_order')
          .get();
    
      var standardCollections = snap.docs
          .map((doc) => CollectionModel.fromMap(doc.data(), doc.id))
          .where((collection) => collection.isActive)
          .toList();

      // 2. Fetch Smart Collections (filtered by admin visibility settings)
      List<CollectionModel> smartCollections = [];
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId != null) {
        try {
          // Load visibility settings from Firestore
          final settingsDoc = await FirebaseFirestore.instance
              .collection('settings')
              .doc('smart_collections')
              .get();

          // Default to enabled if settings don't exist
          final settings = settingsDoc.exists ? settingsDoc.data()! : {
            'wishlist_enabled': true,
            'buy_again_enabled': true,
            'new_arrivals_enabled': true,
          };

          final smartService = SmartCollectionService();

          // Conditionally fetch based on admin settings
          if (settings['wishlist_enabled'] == true) {
            final wishlist = await smartService.getWishlistCollection(userId);
            if (wishlist != null) smartCollections.add(wishlist);
          }

          if (settings['buy_again_enabled'] == true) {
            final buyAgain = await smartService.getBuyAgainCollection(userId);
            if (buyAgain != null) smartCollections.add(buyAgain);
          }

          if (settings['new_arrivals_enabled'] == true) {
            final newArrivals = await smartService.getNewArrivalsCollection();
            if (newArrivals != null) smartCollections.add(newArrivals);
          }

          print('🎯 Loaded ${smartCollections.length} smart collections (based on admin settings)');
        } catch (e) {
          print('Error loading smart collections: $e');
        }
      } else {
        print('⚠️ Skipped Smart Collections (User not logged in)');
      }
          
      _collections = [...smartCollections, ...standardCollections];
          
      print('DEBUG: Loaded ${_collections.length} active collections (${smartCollections.length} smart)');
    } catch (e) {
      print('Error fetching collections: $e');
    }
  }

  Future<void> _fetchCategoriesFromAdmin() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          // Removed orderBy('sort_order') to avoid hiding docs without the field
          .get();

      setState(() {
        _adminCategories = snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).where((cat) {
          // Filter active categories locally
          return cat['is_active'] != false; 
        }).toList();

        // Sort client-side safely
        _adminCategories.sort((a, b) {
           final sortA = a['sort_order'] as num? ?? 999;
           final sortB = b['sort_order'] as num? ?? 999;
           return sortA.compareTo(sortB);
        });
      });
    } catch (e) {
      print('Error fetching admin categories: $e');
    }
  }

  Future<void> _fetchVendorInventory() async {
    print('DEBUG: Fetching vendor inventory for vendorId: $_vendorId');
    
    if (_vendorId == null || _vendorId!.isEmpty) {
      print('DEBUG: ERROR - vendorId is null or empty! Cannot fetch inventory.');
      print('DEBUG: Please ensure you are logged in as a customer with an assigned vendor.');
      return;
    }
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: _vendorId)
          .get();

      print('DEBUG: Found ${snap.docs.length} inventory items');
      
      if (snap.docs.isEmpty) {
        print('DEBUG: No inventory found for vendor: $_vendorId');
        print('DEBUG: Check if this vendor_id exists in your vendor_inventory collection');
      }
      
      _inventoryMap = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        final pid = data['product_id'];
        final isAvailable = data['isAvailable'] ?? true;
        
        print('DEBUG: Processing inventory doc ${doc.id}: product_id=$pid, isAvailable=$isAvailable');
        
        if (pid != null && isAvailable == true) {
          _inventoryMap[pid] = {
             'inventoryId': doc.id,
             'price': data['selling_price'],
             'stock_quantity': data['stock_quantity'],
             'isAvailable': data['isAvailable'],
          };
        }
      }
      print('DEBUG: Inventory map has ${_inventoryMap.length} products after filtering');
    } catch (e) {
      print('DEBUG: ERROR fetching vendor inventory: $e');
    }
  }

  // Core merging logic
  Future<void> _updateDisplayProducts() async {
     if (!mounted) return;
     
     // Set specific loading state for grid only (not full screen)
     setState(() => _isProductLoading = true); 

     List<Map<String, dynamic>> merged = [];
     List<String> targetProductIds = [];
     bool isSmartCollection = false; // Track if viewing smart collection

     print('DEBUG: _updateDisplayProducts called - type: $_selectedType, id: $_selectedId');
     print('DEBUG: inventoryMap size: ${_inventoryMap.length}');
     print('DEBUG: collections count: ${_collections.length}');
     print('DEBUG: categories count: ${_adminCategories.length}');

     // A. Determine which Product IDs we are interested in
     if (_selectedType == 'Collection') {
        // Get collection definition
        final collection = _collections.firstWhere((c) => c.id == _selectedId, orElse: () => CollectionModel(id: '', name: '', productIds: []));
        isSmartCollection = collection.id.startsWith('smart_'); // Check if smart collection
        
        if (isSmartCollection) {
          // For smart collections: always fetch FRESH IDs to ensure sync with recent actions
          if (collection.id == 'smart_wishlist' && _userId != null) {
             final freshCollection = await _smartCollectionService.getWishlistCollection(_userId!);
             targetProductIds = freshCollection?.productIds ?? [];
             print('DEBUG: Refreshed Wishlist - ${targetProductIds.length} items');
          } else if (collection.id == 'smart_buy_again' && _userId != null) {
             final freshCollection = await _smartCollectionService.getBuyAgainCollection(_userId!);
             targetProductIds = freshCollection?.productIds ?? [];
             print('DEBUG: Refreshed Buy Again - ${targetProductIds.length} items');
          } else {
             targetProductIds = collection.productIds;
          }
          
          print('DEBUG: Smart Collection mode - ${targetProductIds.length} products (cross-vendor)');
        } else {
          // For regular collections: only show products in current vendor inventory
          targetProductIds = collection.productIds.where((id) => _inventoryMap.containsKey(id)).toList();
          print('DEBUG: Collection mode - ${collection.productIds.length} total, ${targetProductIds.length} in inventory');
        }
     } else {
        // 'All' or 'Category' -> Start with everything in inventory
        targetProductIds = _inventoryMap.keys.toList();
        print('DEBUG: All/Category mode - ${targetProductIds.length} products from inventory');
     }

     if (targetProductIds.isEmpty) {
        print('DEBUG: No target products found!');
        if (mounted) setState(() => _displayProducts = []);
        return;
     }

     // B. Batch-fetch master products (up to 10 at a time due to Firestore limitations)
     const int batchSize = 10;
     for (int i = 0; i < targetProductIds.length; i += batchSize) {
        final batchIds = targetProductIds.skip(i).take(batchSize).toList();
        print('DEBUG: Processing batch $i: fetching ${batchIds.length} products, IDs: $batchIds');
        try {
           final snap = await FirebaseFirestore.instance
               .collection('master_products')
               .where(FieldPath.documentId, whereIn: batchIds)
               .get();

           print('DEBUG: Fetched ${snap.docs.length} master products for batch ${i ~/ batchSize}');
           print('DEBUG: Found product IDs: ${snap.docs.map((d) => d.id).toList()}');
           
           for (var doc in snap.docs) {
              Map<String, dynamic> productData = doc.data();
              productData['id'] = doc.id;

              // C. Merge with vendor inventory data (if available)
              final isInInventory = _inventoryMap.containsKey(doc.id);
              
              if (isInInventory) {
                final inv = _inventoryMap[doc.id]!;
                productData['price'] = inv['price'] ?? productData['price'];
                productData['stock_quantity'] = inv['stock_quantity'] ?? 0;
                productData['isAvailable'] = inv['isAvailable'] ?? true;
                productData['vendor_id'] = _vendorId;
                productData['isAvailableInCurrentVendor'] = true; // NEW FLAG
              } else {
                // Product NOT in current vendor (only for smart collections)
                productData['stock_quantity'] = 0;
                productData['isAvailable'] = false;
                productData['isAvailableInCurrentVendor'] = false; // NEW FLAG
                productData['vendor_id'] = _vendorId;
              }

              // D. Category filter (if applicable)
              if (_selectedType == 'Category') {
                 String productCategory = productData['category'] ?? '';
                 if (productCategory.toLowerCase() == _selectedId.toLowerCase()) {
                    merged.add(productData);
                    print('DEBUG: Added product ${doc.id} to display (category match)');
                 }
              } else {
                 merged.add(productData);
                 print('DEBUG: Added product ${doc.id} to display');
              }
           }
        } catch (e) {
           print('DEBUG: Error fetching batch $i: $e');
        }
     }
     
     print('DEBUG: Final merged products: ${merged.length}');
     
     // Sorting
     if (_selectedType == 'Collection') {
         final collection = _collections.firstWhere((c) => c.id == _selectedId, orElse: () => CollectionModel(id: '', name: '', productIds: []));
         final orderMap = {for (var v in collection.productIds.asMap().entries) v.value: v.key};
         merged.sort((a, b) {
           final idxA = orderMap[a['id']] ?? 9999;
           final idxB = orderMap[b['id']] ?? 9999;
           return idxA.compareTo(idxB);
         });
     }

     if (mounted) {
       setState(() {
         _displayProducts = merged;
         _isLoading = false;
         _isProductLoading = false;
       });
     }
  }

  // ... (Filtering Logic removed, replaced by _updateDisplayProducts)


  @override
  Widget build(BuildContext context) {
    if (_vendorId == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const Text('Please select a location first'),
               ElevatedButton(
                 onPressed: () async {
                   await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeLocationScreen()));
                   _loadData();
                 },
                 child: const Text('Select Location'),
               )
            ],
          ),
        ),
      );
    }

    // final filteredProducts = _getFilteredProducts(); // Replaced by _displayProducts state

    return Scaffold(
      backgroundColor: Colors.white,
      body: DraggableCartWrapper(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              CustomerHeader(
                selectedArea: _selectedArea ?? 'Location',
                onLocationTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeLocationScreen()));
                  _loadData(); // Full reload
                },
                onCartTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              ),

              // Search
              GlobalSearchBar(
                onTap: () {
                  showSearch(
                    context: context,
                    delegate: ProductSearchDelegate(
                      products: _displayProducts, // Search within currently filtered/loaded products
                      categoryName: _selectedType == 'All' ? null : _selectedId, // Show context in search UI
                    ),
                  );
                },
              ),

              // Body
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmallMobile = constraints.maxWidth < 380;
                        final sidebarWidth = isSmallMobile ? 70.0 : 90.0;
                        
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Sidebar
                            SizedBox(
                              width: sidebarWidth,
                              child: Container(
                                color: Colors.grey[50],
                                child: ListView(
                                  // Added bottom padding (100)
                                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                                  children: [
                                    _buildSidebarItem('All', 'All', 'all', Icons.grid_view_rounded),
                                    
                                    // Collections
                                    if (_collections.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('Collections', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      ),
                                      ..._collections.map((c) {
                                        IconData icon = Icons.star_outline;
                                        if (c.id == 'smart_wishlist') icon = Icons.favorite_rounded;
                                        if (c.id == 'smart_buy_again') icon = Icons.history_rounded;
                                        if (c.id == 'smart_new_arrivals') icon = Icons.new_releases_rounded;
                                        
                                        return _buildSidebarItem(c.name, 'Collection', c.id, icon, imageUrl: c.icon);
                                      }),
                                    ],

                                    // Categories (Admin Managed)
                                    if (_adminCategories.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('Categories', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      ),
                                      ..._adminCategories.map((c) {
                                        return _buildSidebarItem(
                                          c['name'] ?? 'Unnamed', 
                                          'Category', 
                                          c['name'] ?? 'Unnamed', 
                                          Icons.category_outlined,
                                          imageUrl: c['icon'], 
                                        );
                                      }),
                                    ]
                                  ],
                                ),
                              ),
                            ),

                        // Right Product Grid
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dynamic Header
                              if (_selectedType != 'All' && _selectedType != 'Category')
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  child: Row(
                                    children: [
                                      if (_selectedType == 'Collection' && _selectedId == 'smart_wishlist')
                                        const Icon(Icons.favorite, color: Colors.pink, size: 20)
                                      else if (_selectedType == 'Collection' && _selectedId == 'smart_buy_again')
                                        const Icon(Icons.history, color: Colors.blue, size: 20)
                                      else if (_selectedType == 'Collection' && _selectedId == 'smart_new_arrivals')
                                        const Icon(Icons.new_releases, color: Colors.orange, size: 20),
                                      
                                      if (_selectedType == 'Collection')
                                         const SizedBox(width: 8),

                                      Text(
                                        _selectedType == 'Collection' 
                                            ? (_collections.firstWhere((c) => c.id == _selectedId, orElse: () => CollectionModel(id: '', name: 'Collection', productIds: [])).name)
                                            : _selectedId,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                              Expanded(
                                child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate responsive columns
                              int crossAxisCount = (constraints.maxWidth / 140).floor();
                              if (constraints.maxWidth > 280 && crossAxisCount < 2) crossAxisCount = 2;
                              if (crossAxisCount < 1) crossAxisCount = 1;
                              
                              double spacing = 8.0;
                              double cardWidth = (constraints.maxWidth - (spacing * 2) - ((crossAxisCount - 1) * spacing)) / crossAxisCount;
                              
                              // Increase height to prevent overflow
                              double desiredHeight = 270.0; 
                              double childAspectRatio = cardWidth / desiredHeight;
                              
                              // Clamp aspect ratio
                              if (childAspectRatio < 0.5) childAspectRatio = 0.5;
                              if (childAspectRatio > 0.8) childAspectRatio = 0.8;
                              
                                return Container(
                                  color: Colors.white,
                                  child: _isProductLoading
                                      ? Center(child: CircularProgressIndicator(color: const Color(0xFF0D9759))) // Show immediate loader
                                      : _displayProducts.isEmpty 
                                    ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                                          const SizedBox(height: 8),
                                          const Text('No products found', style: TextStyle(color: Colors.grey)),
                                        ],
                                      )
                                    )
                                  : GridView.builder(
                                      // Added bottom padding (100)
                                      padding: EdgeInsets.fromLTRB(spacing, spacing, spacing, 100),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        childAspectRatio: childAspectRatio,
                                        crossAxisSpacing: spacing,
                                        mainAxisSpacing: spacing,
                                      ),
                                      itemCount: _displayProducts.length,
                                      itemBuilder: (context, index) {
                                        final product = _displayProducts[index];
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
                                          onAdd: () async {
                                            bool success = await CartHelper.addToCart(context, product);
                                            // Snackbar is already handled inside addToCart failure, 
                                            // but for success we can show one or rely on the UI update.
                                            // Let's rely on the UI update or a simple optional snack bar.
                                            if (success && context.mounted) {
                                               ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Added to cart'),
                                                  duration: Duration(seconds: 1),
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                          ],
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(String label, String type, String id, IconData icon, {String? imageUrl}) {
    final bool isSelected = (_selectedType == type && _selectedId == id);
    final bool isSmallMobile = MediaQuery.of(context).size.width < 380;

    return GestureDetector(
      onTap: () {
        print('DEBUG: Sidebar item clicked - label: $label, type: $type, id: $id');
        setState(() {
          _selectedType = type;
          _selectedId = id;
        });
        print('DEBUG: Selection updated - _selectedType: $_selectedType, _selectedId: $_selectedId');
        _updateDisplayProducts();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: const Color(0xFF0D9759), width: 1.5)
              : null,
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Container - Rounded Square
            Container(
              width: isSmallMobile ? 40 : 48, // Increased size
              height: isSmallMobile ? 40 : 48,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0D9759).withOpacity(0.1) : Colors.white,
                shape: BoxShape.rectangle, // Rectangle
                borderRadius: BorderRadius.circular(8), // Rounded corners
                border: Border.all(color: Colors.grey.shade200),
                image: (imageUrl != null && imageUrl.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.contain, // Show full icon
                      )
                    : null,
              ),
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? Center(
                      child: Icon(
                        icon,
                        color: isSelected ? const Color(0xFF0D9759) : Colors.grey,
                        size: isSmallMobile ? 24 : 28, // Increased icon size
                      ),
                    )
                  : null, // Image handled by DecorationImage
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSmallMobile ? 9 : 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0D9759) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
