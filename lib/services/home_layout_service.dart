import 'package:cloud_firestore/cloud_firestore.dart';

class HomeLayoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get home layouts for a specific vendor (Single Vendor Mode)
  Stream<List<Map<String, dynamic>>> getVendorLayouts(String vendorId) {
    return _firestore
        .collection('home_layouts')
        .where('vendor_id', isEqualTo: vendorId)
        .where('active', isEqualTo: true)
        .orderBy('position')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'product_row',
          'position': data['position'] ?? 0,
          'title': data['title'] ?? '',
          'data': data['data'] ?? {},
          'vendor_id': data['vendor_id'],
        };
      }).toList();
    });
  }

  /// Get products for a specific layout - JOINS vendor_inventory + products (master catalog)
  Stream<QuerySnapshot> getAggregatedProducts({
    required List<String> vendorIds,
    String? filter,
    int limit = 10,
  }) {
    // Safety check for Firestore limit
    final safeVendorIds = vendorIds.take(10).toList();
    if (safeVendorIds.isEmpty) {
      print('⚠️ No vendor IDs provided');
      return const Stream.empty();
    }

    print('🔍 Fetching inventory for vendors: $safeVendorIds');

    // Query vendor_inventory filtered by vendor
    Query query = _firestore
        .collection('vendor_inventory')
        .where('vendor_id', whereIn: safeVendorIds)
        .where('isAvailable', isEqualTo: true); // Only show available items

    // Apply filter if provided (will need to filter client-side after merge)
    // For now, just return the base query
    return query.limit(limit * 2).snapshots(); // Fetch more since we'll enrich
  }

  /// Enrich vendor inventory with product details from master catalog
  Future<Map<String, dynamic>> enrichInventoryWithProduct(Map<String, dynamic> inventoryData) async {
    try {
      String? productId = inventoryData['product_id'];
      print('📦 Enriching inventory: productId=$productId');
      
      if (productId == null) {
        print('⚠️ No product_id found in inventory data');
        return inventoryData;
      }

      // Fetch product details from master catalog
      DocumentSnapshot productDoc = await _firestore
          .collection('master_products')
          .doc(productId)
          .get();

      if (!productDoc.exists) {
        print('⚠️ Product not found: $productId');
        return inventoryData;
      }

      Map<String, dynamic> productData = productDoc.data() as Map<String, dynamic>;
      print('✅ Enriched product: ${productData['name']}');

      // Merge: Start with product details, then override with vendor-specific data
      return {
        ...productData, // Name, image, description, category, etc.
        'price': inventoryData['selling_price'] ?? productData['price'], // Vendor's price
        'stock_quantity': inventoryData['stock_quantity'] ?? 0, // Vendor's stock
        'vendor_id': inventoryData['vendor_id'], // Keep vendor reference
        'product_id': productId, // Keep product reference
        'isAvailable': inventoryData['isAvailable'] ?? true,
      };
    } catch (e) {
      print('❌ Error enriching inventory: $e');
      return inventoryData;
    }
  }

  /// Get categories dynamically from products in vendor's inventory
  Future<List<Map<String, dynamic>>> getVendorCategories(String vendorId) async {
    try {
      // 1. Fetch inventory items for this vendor
      final inventorySnapshot = await _firestore
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('isAvailable', isEqualTo: true)
          .get();

      // 2. Extract product IDs
      final productIds = inventorySnapshot.docs
          .map((doc) => doc.data()['product_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (productIds.isEmpty) return [];

      // 3. Fetch products in batches (Firestore 'in' limit is 10)
      final Map<String, int> categoryCounts = {};
      final Map<String, String?> categoryImages = {};

      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();
        final productsSnapshot = await _firestore
            .collection('master_products')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in productsSnapshot.docs) {
          final data = doc.data();
          String? category = data['category'];
          if (category != null && category.isNotEmpty) {
            categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
            categoryImages[category] ??= data['imageUrl']; // First product image
          }
        }
      }

      // 4. Convert to list
      return categoryCounts.entries.map((entry) {
        return {
          'name': entry.key,
          'count': entry.value,
          'image_url': categoryImages[entry.key],
        };
      }).toList();
    } catch (e) {
      print('Error fetching vendor categories: $e');
      return [];
    }
  }

  /// Get banners for multiple vendors
  Stream<QuerySnapshot> getAggregatedBanners(List<String> vendorIds) {
    final safeVendorIds = vendorIds.take(10).toList();
    if (safeVendorIds.isEmpty) return const Stream.empty();

    return _firestore
        .collection('banners')
        .where('vendor_id', whereIn: safeVendorIds)
        .where('active', isEqualTo: true)
        .snapshots();
  }

  // --- Legacy / Single Vendor Support (Keeping for safe refactor) ---

  Stream<QuerySnapshot> getProductsForLayout({
    required String vendorId,
    String? filter,
    int limit = 10,
  }) {
    return getAggregatedProducts(vendorIds: [vendorId], filter: filter, limit: limit);
  }



  Stream<QuerySnapshot> getBannersForVendor(String vendorId) {
    return getAggregatedBanners([vendorId]);
  }

  /// Check vendor status (Single)
  Stream<DocumentSnapshot> getVendorStatus(String vendorId) {
    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .snapshots();
  }
}
