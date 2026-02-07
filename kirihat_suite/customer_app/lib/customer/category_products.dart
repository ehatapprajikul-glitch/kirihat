import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/draggable_cart_wrapper.dart';
import 'widgets/customer_header.dart';
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
  
  // Category Hierarchy Data
  List<Map<String, dynamic>> _allCategories = []; // All raw categories
  List<Map<String, dynamic>> _rootCategories = []; // Level 0
  Map<String, List<Map<String, dynamic>>> _subCategoriesMap = {}; // ParentID -> List<Level 1>
  
  List<Map<String, dynamic>> _displayProducts = []; // Final merged products to show

  // Selection
  String _selectedType = 'All'; // 'All', 'Collection', 'Category'
  String _selectedId = 'all'; // 'all', collectionId, or categoryName (Root ID)
  String _selectedSubId = 'all_sub'; // 'all_sub' or subcategoryName/ID

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

      final allCats = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).where((cat) {
        // Filter active categories locally
        return cat['is_active'] != false; 
      }).toList();

      // Sort client-side safely
      allCats.sort((a, b) {
         final sortA = a['sort_order'] as num? ?? 999;
         final sortB = b['sort_order'] as num? ?? 999;
         return sortA.compareTo(sortB);
      });

      // Split into Root and Sub data
      List<Map<String, dynamic>> roots = [];
      Map<String, List<Map<String, dynamic>>> subs = {};

      for (var cat in allCats) {
        final parentId = cat['parent_id'] as String?;
        if (parentId == null || parentId.isEmpty || parentId == 'null') {
          roots.add(cat);
        } else {
           if (!subs.containsKey(parentId)) subs[parentId] = [];
           subs[parentId]!.add(cat);
        }
      }
      
      setState(() {
        _allCategories = allCats;
        _rootCategories = roots;
        _subCategoriesMap = subs;
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
     
     setState(() => _isProductLoading = true); 

     List<Map<String, dynamic>> merged = [];
     List<String> targetProductIds = [];
     bool isSmartCollection = false; 

     print('DEBUG: _updateDisplayProducts called - type: $_selectedType, id: $_selectedId');
     print('DEBUG: inventoryMap size: ${_inventoryMap.length}');
     print('DEBUG: collections count: ${_collections.length}');
     print('DEBUG: root categories count: ${_rootCategories.length}');

     // A. Determine which Product IDs we are interested in.
     // For 'Category' type, we generally want to search ALL inventory, and filter by field text.
     // For 'Collection', we have specific IDs.
     if (_selectedType == 'Collection') {
        final collection = _collections.firstWhere((c) => c.id == _selectedId, orElse: () => CollectionModel(id: '', name: '', productIds: []));
        isSmartCollection = collection.id.startsWith('smart_');
        
        if (isSmartCollection) {
          if (collection.id == 'smart_wishlist' && _userId != null) {
             final freshCollection = await _smartCollectionService.getWishlistCollection(_userId!);
             targetProductIds = freshCollection?.productIds ?? [];
          } else if (collection.id == 'smart_buy_again' && _userId != null) {
             final freshCollection = await _smartCollectionService.getBuyAgainCollection(_userId!);
             targetProductIds = freshCollection?.productIds ?? [];
          } else {
             targetProductIds = collection.productIds;
          }
        } else {
          targetProductIds = collection.productIds.where((id) => _inventoryMap.containsKey(id)).toList();
        }
     } else {
        // 'All' or 'Category' -> Start with everything in inventory
        targetProductIds = _inventoryMap.keys.toList();
     }

     if (targetProductIds.isEmpty) {
        if (mounted) setState(() {
          _displayProducts = [];
          _isProductLoading = false;
        });
        return;
     }

     // B. Batch-fetch master products
     const int batchSize = 10;
     for (int i = 0; i < targetProductIds.length; i += batchSize) {
        final batchIds = targetProductIds.skip(i).take(batchSize).toList();
        try {
           final snap = await FirebaseFirestore.instance
               .collection('master_products')
               .where(FieldPath.documentId, whereIn: batchIds)
               .get();

           for (var doc in snap.docs) {
              Map<String, dynamic> productData = doc.data();
              productData['id'] = doc.id;

              // C. Merge with vendor inventory (if applicable)
              final isInInventory = _inventoryMap.containsKey(doc.id);
              if (isInInventory) {
                final inv = _inventoryMap[doc.id]!;
                productData['price'] = inv['price'] ?? productData['price'];
                productData['stock_quantity'] = inv['stock_quantity'] ?? 0;
                productData['isAvailable'] = inv['isAvailable'] ?? true;
                productData['vendor_id'] = _vendorId;
                productData['isAvailableInCurrentVendor'] = true;
              } else {
                productData['stock_quantity'] = 0;
                productData['isAvailable'] = false;
                productData['isAvailableInCurrentVendor'] = false;
                productData['vendor_id'] = _vendorId;
              }

              // D. Category filtering
              if (_selectedType == 'Category') {
                 String productCategory = productData['category'] ?? '';
                 String productSub = productData['subcategory'] ?? '';
                 
                 // 1. Resolve Root Category
                 String selectedRootName = '';
                 final rootCat = _rootCategories.firstWhere((r) => r['id'] == _selectedId || r['name'] == _selectedId, orElse: () => {});
                 
                 Set<String> validNames = {};
                 
                 if (rootCat.isNotEmpty) {
                    selectedRootName = rootCat['name'];
                    validNames.add(selectedRootName.toLowerCase());
                    
                    // Add all subcategories of this root to valid matches
                    // Logic: If product has 'category': 'Saag' (which is a sub of 'Vegetables'), it should show up under 'Vegetables'
                    final subs = _subCategoriesMap[rootCat['id']] ?? [];
                    for (var s in subs) {
                      if (s['name'] != null) validNames.add(s['name'].toString().toLowerCase());
                    }
                 } else {
                    selectedRootName = _selectedId;
                    validNames.add(selectedRootName.toLowerCase());
                 }

                 // Debug
                 if (i == 0 && merged.length < 3) {
                    print('DEBUG FILTER: SelectedID=$_selectedId, Root=$selectedRootName, ValidNamesCount=${validNames.length}, ProdCat=$productCategory');
                 }

                 // 2. Initial Match (Is this product relevant to the Root Tree?)
                 // defined as: product.category IN [Root, Sub1, Sub2...] OR product.subcategory IN [Root, Sub1, Sub2...]
                 bool isMatch = validNames.contains(productCategory.toLowerCase()) || 
                                validNames.contains(productSub.toLowerCase());

                 if (isMatch) {
                    // 3. Subcategory Filter (Drill down)
                    if (_selectedSubId != 'all_sub') {
                        // Strict check: One of the product's fields must match the selected subcategory explicitly
                        bool subMatch = productCategory.toLowerCase() == _selectedSubId.toLowerCase() ||
                                        productSub.toLowerCase() == _selectedSubId.toLowerCase();
                        
                        if (subMatch) {
                             merged.add(productData);
                        }
                    } else {
                        // All subcategories selected -> Show everything in this Root Tree
                        merged.add(productData);
                    }
                 }
              } else {
                 merged.add(productData);
              }
           }
        } catch (e) {
           print('DEBUG: Error fetching batch $i: $e');
        }
     }
     
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
                products: _displayProducts,
                categoryName: _selectedType == 'Category' ? _selectedId : null,
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
                            // Left Sidebar (Level 0 Only)
                            SizedBox(
                              width: sidebarWidth,
                              child: Container(
                                color: Colors.grey[50], // Nice subtle background
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                                  children: [
                                    _buildSidebarItem('All', 'All', 'all', Icons.grid_view_rounded),
                                    
                                    // Collections
                                    if (_collections.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
                                        child: Text('COLLECTIONS', 
                                          style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      ),
                                      ..._collections.where((c) => c.id != 'smart_wishlist').map((c) {
                                        IconData icon = Icons.star_outline;
                                        // if (c.id == 'smart_wishlist') icon = Icons.favorite_rounded; // Handled in header now
                                        if (c.id == 'smart_buy_again') icon = Icons.history_rounded;
                                        if (c.id == 'smart_new_arrivals') icon = Icons.new_releases_rounded;
                                        
                                        return _buildSidebarItem(c.name, 'Collection', c.id, icon, imageUrl: c.icon);
                                      }),
                                    ],

                                    // Root Categories
                                    if (_rootCategories.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(8, 16, 8, 4),
                                        child: Text('CATEGORIES', 
                                          style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      ),
                                      ..._rootCategories.map((c) {
                                        return _buildSidebarItem(
                                          c['name'] ?? 'Unnamed', 
                                          'Category', 
                                          c['id'], // Use ID for selection tracking
                                          Icons.category_outlined,
                                          imageUrl: c['icon'], 
                                        );
                                      }),
                                    ]
                                  ],
                                ),
                              ),
                            ),

                        // Right Product Area
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Level 1 Categories (Subcategories) - Only if Category Selected
                              if (_selectedType == 'Category')
                                _buildSubcategoryHeader(),
                                
                              // 2. Title (For Collections/All)
                              if (_selectedType != 'Category' && _selectedType != 'All')
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
                                      
                                      if (_selectedType == 'Collection' && _collections.any((c) => c.id == _selectedId))
                                         const SizedBox(width: 8),

                                      Text(
                                        _getHeaderTitle(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                              // 3. Product Grid
                              Expanded(
                                child: LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount = (constraints.maxWidth / 140).floor();
                              if (constraints.maxWidth > 280 && crossAxisCount < 2) crossAxisCount = 2;
                              if (crossAxisCount < 1) crossAxisCount = 1;
                              
                              double spacing = 8.0;
                              double cardWidth = (constraints.maxWidth - (spacing * 2) - ((crossAxisCount - 1) * spacing)) / crossAxisCount;
                              double desiredHeight = 270.0; 
                              double childAspectRatio = cardWidth / desiredHeight;
                              
                              if (childAspectRatio < 0.5) childAspectRatio = 0.5;
                              if (childAspectRatio > 0.8) childAspectRatio = 0.8;
                              
                                return Container(
                                  color: Colors.white,
                                  child: _isProductLoading
                                      ? Center(child: CircularProgressIndicator(color: const Color(0xFF0D9759)))
                                      : _displayProducts.isEmpty 
                                    ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                                          const SizedBox(height: 8),
                                          const Text('No products found', style: TextStyle(color: Colors.grey)),
                                          if (_selectedType == 'Collection' && _selectedId == 'smart_wishlist')
                                            TextButton(
                                              onPressed: () {
                                                 setState(() {
                                                   _selectedType = 'All';
                                                   _selectedId = 'all';
                                                 });
                                                 _updateDisplayProducts();
                                              },
                                              child: const Text('Browse Products'),
                                            )
                                        ],
                                      )
                                    )
                                  : GridView.builder(
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
                                            if (success && context.mounted) {
                                               // ScaffoldMessenger.of(context).showSnackBar(
                                               //  const SnackBar(
                                               //    content: Text('Added to cart'),
                                               //    duration: Duration(seconds: 1),
                                               //  ),
                                              // );
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

  String _getHeaderTitle() {
    if (_selectedType == 'All') return 'All Products';
    if (_selectedType == 'Collection') {
      return _collections.firstWhere((c) => c.id == _selectedId, 
          orElse: () => CollectionModel(id: '', name: 'Collection', productIds: [])).name;
    }
    if (_selectedType == 'Category') {
      // Find name from ID
      final cat = _rootCategories.firstWhere((c) => c['id'] == _selectedId, orElse: () => {'name': _selectedId});
      return cat['name'];
    }
    return 'Products';
  }

  // New Widget: Horizontal Subcategory List
  Widget _buildSubcategoryHeader() {
    final rootId = _selectedId;
    final subcategories = _subCategoriesMap[rootId] ?? [];

    // Always show 'All' option
    // Map available subcategories to widgets
    
    return Container(
       height: 100, // Fixed height for the header
       width: double.infinity,
       color: Colors.white,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
              child: Text(
                _getHeaderTitle().toUpperCase(),
                style: const TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1.0,
                  color: Colors.black54
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                   // 1. 'All' Option
                   _buildSubCategoryItem(
                     label: 'All', 
                     icon: Icons.apps, 
                     id: 'all_sub',
                     isSelected: _selectedSubId == 'all_sub'
                   ),
                   
                   // 2. Dynamic Subs
                   ...subcategories.map((sub) {
                      return _buildSubCategoryItem(
                        label: sub['name'], 
                        icon: Icons.category, // Fallback
                        imageUrl: sub['icon'],
                        id: sub['name'], // Filtering by name for now, as products use name
                        isSelected: _selectedSubId == sub['name']
                      );
                   }),
                ],
              ),
            ),
            const Divider(height: 1),
         ],
       ),
    );
  }

  Widget _buildSubCategoryItem({
    required String label, 
    required String id, 
    required bool isSelected,
    IconData? icon,
    String? imageUrl
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubId = id;
        });
        _updateDisplayProducts();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             // Circle/Icon
             Container(
               width: 45,
               height: 45,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: isSelected ? const Color(0xFF0D9759) : Colors.grey[100],
                 border: Border.all(color: isSelected ? const Color(0xFF0D9759) : Colors.grey[300]!),
                 image: (imageUrl != null && imageUrl.isNotEmpty)
                     ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                     : null
               ),
               child: (imageUrl == null || imageUrl.isEmpty)
                   ? Icon(icon, color: isSelected ? Colors.white : Colors.grey[600], size: 20)
                   : null,
             ),
             const SizedBox(height: 4),
             Text(
               label,
               style: TextStyle(
                 fontSize: 10, 
                 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                 color: isSelected ? const Color(0xFF0D9759) : Colors.black87
               ),
             )
          ],
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
          _selectedSubId = 'all_sub'; // Reset subcategory when switching root
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
              width: isSmallMobile ? 40 : 48,
              height: isSmallMobile ? 40 : 48,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0D9759).withOpacity(0.1) : Colors.white,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
                image: (imageUrl != null && imageUrl.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? Center(
                      child: Icon(
                        icon,
                        color: isSelected ? const Color(0xFF0D9759) : Colors.grey,
                        size: isSmallMobile ? 24 : 28,
                      ),
                    )
                  : null, 
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
