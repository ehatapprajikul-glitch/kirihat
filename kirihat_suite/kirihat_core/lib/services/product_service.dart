import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get new arrivals (recently added to vendor inventory)
  Future<List<Map<String, dynamic>>> getNewArrivals({
    required String vendorId,
    int limit = 10,
  }) async {
    try {
      final inventorySnap = await _firestore
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('isAvailable', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(limit * 2) // Fetch extra for enrichment
          .get();

      return await _enrichProducts(inventorySnap.docs, vendorId);
    } catch (e) {
      print('❌ Error fetching new arrivals: $e');
      return [];
    }
  }

  /// Get deals (highest discount percentage)
  Future<List<Map<String, dynamic>>> getDeals({
    required String vendorId,
    int limit = 10,
  }) async {
    try {
      final inventorySnap = await _firestore
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('isAvailable', isEqualTo: true)
          .limit(100) // Fetch more to filter for best deals
          .get();

      final products = await _enrichProducts(inventorySnap.docs, vendorId);
      
      // Calculate discount percentage and filter out products with no discount
      final dealsWithDiscount = products.where((product) {
        final mrp = (product['mrp'] ?? 0) as num;
        final price = (product['price'] ?? 0) as num;
        return mrp > 0 && price > 0 && mrp > price;
      }).toList();

      // Sort by discount percentage (highest first)
      dealsWithDiscount.sort((a, b) {
        final discountA = ((a['mrp'] ?? 0) as num) - ((a['price'] ?? 0) as num);
        final discountB = ((b['mrp'] ?? 0) as num) - ((b['price'] ?? 0) as num);
        final percentA = discountA / ((a['mrp'] ?? 1) as num);
        final percentB = discountB / ((b['mrp'] ?? 1) as num);
        return percentB.compareTo(percentA);
      });

      return dealsWithDiscount.take(limit).toList();
    } catch (e) {
      print('❌ Error fetching deals: $e');
      return [];
    }
  }

  /// Get trending products (placeholder - needs order data integration)
  /// For now, returns products sorted by stock quantity (more stock = more popular)
  Future<List<Map<String, dynamic>>> getTrendingProducts({
    required String vendorId,
    int limit = 10,
  }) async {
    try {
      final inventorySnap = await _firestore
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('isAvailable', isEqualTo: true)
          .orderBy('stock_quantity', descending: true)
          .limit(limit * 2)
          .get();

      return await _enrichProducts(inventorySnap.docs, vendorId);
    } catch (e) {
      print('❌ Error fetching trending products: $e');
      return [];
    }
  }

  /// Get featured products by specific product IDs
  Future<List<Map<String, dynamic>>> getFeaturedProducts({
    required String vendorId,
    required List<String> productIds,
  }) async {
    try {
      if (productIds.isEmpty) return [];

      final products = <Map<String, dynamic>>[];
      
      // Fetch in batches of 10 (Firestore 'in' limit)
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();
        
        final inventorySnap = await _firestore
            .collection('vendor_inventory')
            .where('vendor_id', isEqualTo: vendorId)
            .where('product_id', whereIn: batch)
            .where('isAvailable', isEqualTo: true)
            .get();

        products.addAll(await _enrichProducts(inventorySnap.docs, vendorId));
      }

      return products;
    } catch (e) {
      print('❌ Error fetching featured products: $e');
      return [];
    }
  }

  /// Enrich inventory documents with master product data
  Future<List<Map<String, dynamic>>> _enrichProducts(
    List<QueryDocumentSnapshot> inventoryDocs,
    String vendorId,
  ) async {
    // Extract product IDs
    final productIds = inventoryDocs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['product_id'] as String?;
        })
        .where((id) => id != null)
        .cast<String>()
        .toList();

    if (productIds.isEmpty) return [];

    final products = <Map<String, dynamic>>[];
    final inventoryMap = <String, Map<String, dynamic>>{};

    // Create inventory map for quick lookup
    for (var doc in inventoryDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final productId = data['product_id'];
      if (productId != null) {
        inventoryMap[productId] = data;
      }
    }

    // Fetch master products in batches of 10
    for (int i = 0; i < productIds.length; i += 10) {
      final batch = productIds.skip(i).take(10).toList();
      
      try {
        final productsSnap = await _firestore
            .collection('master_products')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in productsSnap.docs) {
          final productData = doc.data();
          final inventory = inventoryMap[doc.id];

          if (inventory != null) {
            products.add({
              ...productData,
              'id': doc.id,
              'price': inventory['selling_price'] ?? productData['price'],
              'stock_quantity': inventory['stock_quantity'] ?? 0,
              'vendor_id': vendorId,
              'isAvailable': inventory['isAvailable'] ?? true,
            });
          }
        }
      } catch (e) {
        print('❌ Error enriching product batch: $e');
      }
    }

    return products;
  }
}
