import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import 'dart:async';

/// Enhanced Home Layout Service with caching, error handling, and optimizations
class EnhancedHomeLayoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache management
  final Map<String, List<LayoutModel>> _layoutCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // Product cache
  final Map<String, Map<String, dynamic>> _productCache = {};
  final Map<String, DateTime> _productCacheTimestamps = {};
  
  // Stream controllers for better management
  final Map<String, StreamController<List<LayoutModel>>> _layoutControllers = {};

  /// Get admin global layouts (vendor_id = null) with caching
  Stream<List<LayoutModel>> getAdminLayouts() {
    final cacheKey = 'admin_layouts';
    
    // Check cache first
    if (_isCacheValid(cacheKey)) {
      return Stream.value(_layoutCache[cacheKey]!);
    }

    return _firestore
        .collection('home_layouts')
        .where('vendor_id', isEqualTo: null)
        .where('active', isEqualTo: true)
        .orderBy('position')
        .snapshots()
        .handleError((error) {
          print('❌ Error loading admin layouts: $error');
          return <QueryDocumentSnapshot>[];
        })
        .map((snapshot) {
          final layouts = snapshot.docs
              .map((doc) => _safeParseLayout(doc))
              .where((layout) => layout != null)
              .cast<LayoutModel>()
              .toList();
          
          // Update cache
          _updateCache(cacheKey, layouts);
          
          return layouts;
        });
  }

  /// Get merged layouts (admin + vendor override) with optimizations
  Stream<List<LayoutModel>> getMergedLayouts(String vendorId) {
    if (vendorId.isEmpty) {
      print('⚠️ Empty vendor ID provided');
      return Stream.value([]);
    }

    final cacheKey = 'merged_$vendorId';
    
    // Check cache first
    if (_isCacheValid(cacheKey)) {
      return Stream.value(_layoutCache[cacheKey]!);
    }

    // Get or create stream controller
    if (!_layoutControllers.containsKey(cacheKey)) {
      _layoutControllers[cacheKey] = StreamController<List<LayoutModel>>.broadcast();
    }

    return _firestore
        .collection('home_layouts')
        .where('active', isEqualTo: true)
        .orderBy('position')
        .snapshots()
        .handleError((error) {
          print('❌ Error loading merged layouts: $error');
          _layoutControllers[cacheKey]?.addError(error);
        })
        .map((snapshot) {
          try {
            final layouts = snapshot.docs
                .map((doc) => _safeParseLayout(doc))
                .where((layout) => layout != null)
                .cast<LayoutModel>()
                .where((layout) => 
                    layout.vendorId == null || 
                    layout.vendorId == vendorId)
                .toList();
            
            // Sort by position
            layouts.sort((a, b) => a.position.compareTo(b.position));
            
            // Update cache
            _updateCache(cacheKey, layouts);
            
            return layouts;
          } catch (e) {
            print('❌ Error processing layouts: $e');
            return <LayoutModel>[];
          }
        });
  }

  /// Get vendor-specific layouts only
  Stream<List<LayoutModel>> getVendorLayouts(String vendorId) {
    if (vendorId.isEmpty) {
      return Stream.value([]);
    }

    final cacheKey = 'vendor_$vendorId';
    
    if (_isCacheValid(cacheKey)) {
      return Stream.value(_layoutCache[cacheKey]!);
    }

    return _firestore
        .collection('home_layouts')
        .where('vendor_id', isEqualTo: vendorId)
        .where('active', isEqualTo: true)
        .orderBy('position')
        .snapshots()
        .handleError((error) {
          print('❌ Error loading vendor layouts: $error');
        })
        .map((snapshot) {
          final layouts = snapshot.docs
              .map((doc) => _safeParseLayout(doc))
              .where((layout) => layout != null)
              .cast<LayoutModel>()
              .toList();
          
          _updateCache(cacheKey, layouts);
          return layouts;
        });
  }

  /// Enrich vendor inventory with product details (with caching)
  Future<Map<String, dynamic>> enrichInventoryWithProduct(
    Map<String, dynamic> inventoryData,
  ) async {
    try {
      String? productId = inventoryData['product_id'];
      
      if (productId == null || productId.isEmpty) {
        print('⚠️ No product_id in inventory data');
        return inventoryData;
      }

      // Check product cache
      if (_isProductCacheValid(productId)) {
        final cachedProduct = _productCache[productId]!;
        return _mergeInventoryWithProduct(inventoryData, cachedProduct);
      }

      // Fetch from Firestore
      final productDoc = await _firestore
          .collection('master_products')
          .doc(productId)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⏰ Product fetch timeout for: $productId');
              throw TimeoutException('Product fetch timeout');
            },
          );

      if (!productDoc.exists) {
        print('⚠️ Product not found: $productId');
        return inventoryData;
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      
      // Update cache
      _productCache[productId] = productData;
      _productCacheTimestamps[productId] = DateTime.now();

      return _mergeInventoryWithProduct(inventoryData, productData);
    } catch (e) {
      print('❌ Error enriching inventory: $e');
      return inventoryData;
    }
  }

  /// Batch enrich multiple inventory items (optimized)
  Future<List<Map<String, dynamic>>> batchEnrichInventory(
    List<Map<String, dynamic>> inventoryItems,
  ) async {
    if (inventoryItems.isEmpty) return [];

    final enrichedItems = <Map<String, dynamic>>[];
    final productIds = <String>[];
    final uncachedItems = <Map<String, dynamic>>[];

    // Separate cached and uncached items
    for (var item in inventoryItems) {
      final productId = item['product_id'] as String?;
      
      if (productId == null) {
        enrichedItems.add(item);
        continue;
      }

      if (_isProductCacheValid(productId)) {
        // Use cached data
        enrichedItems.add(
          _mergeInventoryWithProduct(item, _productCache[productId]!),
        );
      } else {
        productIds.add(productId);
        uncachedItems.add(item);
      }
    }

    if (productIds.isEmpty) return enrichedItems;

    // Batch fetch uncached products (Firestore limit is 10)
    for (int i = 0; i < productIds.length; i += 10) {
      final batch = productIds.skip(i).take(10).toList();
      
      try {
        final snapshot = await _firestore
            .collection('master_products')
            .where(FieldPath.documentId, whereIn: batch)
            .get()
            .timeout(const Duration(seconds: 10));

        // Cache and merge
        for (var doc in snapshot.docs) {
          final productData = doc.data();
          _productCache[doc.id] = productData;
          _productCacheTimestamps[doc.id] = DateTime.now();

          // Find corresponding inventory item
          final inventoryItem = uncachedItems.firstWhere(
            (item) => item['product_id'] == doc.id,
            orElse: () => <String, dynamic>{},
          );

          if (inventoryItem.isNotEmpty) {
            enrichedItems.add(_mergeInventoryWithProduct(inventoryItem, productData));
          }
        }
      } catch (e) {
        print('❌ Error in batch fetch: $e');
        // Add uncached items as-is
        enrichedItems.addAll(uncachedItems.where(
          (item) => batch.contains(item['product_id']),
        ));
      }
    }

    return enrichedItems;
  }

  /// Get vendor categories with inventory (optimized)
  Future<List<Map<String, dynamic>>> getVendorCategories(String vendorId) async {
    if (vendorId.isEmpty) return [];

    try {
      // Fetch inventory
      final inventorySnapshot = await _firestore
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('isAvailable', isEqualTo: true)
          .limit(500) // Limit for performance
          .get()
          .timeout(const Duration(seconds: 15));

      final productIds = inventorySnapshot.docs
          .map((doc) => doc.data()['product_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet() // Remove duplicates
          .toList();

      if (productIds.isEmpty) return [];

      // Fetch products in batches
      final Map<String, int> categoryCounts = {};
      final Map<String, String?> categoryImages = {};
      final Map<String, String?> categoryIcons = {};

      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();
        
        try {
          final productsSnapshot = await _firestore
              .collection('master_products')
              .where(FieldPath.documentId, whereIn: batch)
              .get()
              .timeout(const Duration(seconds: 10));

          for (var doc in productsSnapshot.docs) {
            final data = doc.data();
            final category = data['category'] as String?;
            
            if (category != null && category.isNotEmpty) {
              categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
              categoryImages[category] ??= data['imageUrl'] as String?;
              categoryIcons[category] ??= data['category_icon'] as String?;
            }
          }
        } catch (e) {
          print('❌ Error fetching product batch: $e');
          continue;
        }
      }

      // Convert to list and sort by count
      final categories = categoryCounts.entries.map((entry) {
        return {
          'name': entry.key,
          'count': entry.value,
          'image_url': categoryImages[entry.key],
          'icon': categoryIcons[entry.key],
        };
      }).toList();

      categories.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return categories;
    } catch (e) {
      print('❌ Error fetching vendor categories: $e');
      return [];
    }
  }

  /// Get vendor status with error handling
  Stream<DocumentSnapshot?> getVendorStatus(String vendorId) {
    if (vendorId.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .snapshots()
        .handleError((error) {
          print('❌ Error loading vendor status: $error');
          return null;
        });
  }

  /// Check if vendor is active and operational
  Future<bool> isVendorActive(String vendorId) async {
    try {
      final doc = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!doc.exists) return false;

      final data = doc.data();
      return data?['isActive'] == true && data?['status'] == 'active';
    } catch (e) {
      print('❌ Error checking vendor status: $e');
      return false;
    }
  }

  // Private helper methods

  LayoutModel? _safeParseLayout(DocumentSnapshot doc) {
    try {
      return LayoutModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Error parsing layout ${doc.id}: $e');
      return null;
    }
  }

  Map<String, dynamic> _mergeInventoryWithProduct(
    Map<String, dynamic> inventory,
    Map<String, dynamic> product,
  ) {
    return {
      ...product,
      'id': inventory['product_id'] ?? product['id'],
      'price': inventory['selling_price'] ?? product['price'],
      'stock_quantity': inventory['stock_quantity'] ?? 0,
      'vendor_id': inventory['vendor_id'],
      'product_id': inventory['product_id'],
      'isAvailable': inventory['isAvailable'] ?? true,
      'vendor_price': inventory['selling_price'],
      'original_price': product['price'],
    };
  }

  bool _isCacheValid(String key) {
    if (!_layoutCache.containsKey(key)) return false;
    
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  bool _isProductCacheValid(String productId) {
    if (!_productCache.containsKey(productId)) return false;
    
    final timestamp = _productCacheTimestamps[productId];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  void _updateCache(String key, List<LayoutModel> layouts) {
    _layoutCache[key] = layouts;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Clear all caches
  void clearCache() {
    _layoutCache.clear();
    _cacheTimestamps.clear();
    _productCache.clear();
    _productCacheTimestamps.clear();
    print('✅ All caches cleared');
  }

  /// Clear specific vendor cache
  void clearVendorCache(String vendorId) {
    _layoutCache.remove('merged_$vendorId');
    _layoutCache.remove('vendor_$vendorId');
    _cacheTimestamps.remove('merged_$vendorId');
    _cacheTimestamps.remove('vendor_$vendorId');
    print('✅ Vendor cache cleared: $vendorId');
  }

  /// Dispose stream controllers
  void dispose() {
    for (var controller in _layoutControllers.values) {
      controller.close();
    }
    _layoutControllers.clear();
  }
}