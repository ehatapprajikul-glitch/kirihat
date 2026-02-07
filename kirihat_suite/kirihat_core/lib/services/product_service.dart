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

  /// Get products by collection ID
  Future<List<Map<String, dynamic>>> getProductsByCollection({
    required String vendorId,
    required String collectionId,
    int limit = 10,
  }) async {
    try {
      // 1. Fetch collection doc to get product IDs
      final collectionDoc = await _firestore
          .collection('product_collections')
          .doc(collectionId)
          .get();

      if (!collectionDoc.exists) {
        print('❌ Collection not found: $collectionId');
        return [];
      }

      final data = collectionDoc.data();
      final productIds = List<String>.from(data?['product_ids'] ?? []);

      if (productIds.isEmpty) return [];

      // 2. Fetch products using existing helper, respecting limit
      // We take more than limit initially because some might not be available in this vendor's inventory
      final limitedIds = productIds.take(limit * 2).toList(); 
      
      final products = await getFeaturedProducts(
        vendorId: vendorId,
        productIds: limitedIds,
      );

      return products.take(limit).toList();

    } catch (e) {
      print('❌ Error fetching collection products: $e');
      return [];
    }
  }

  /// Get products by category name
  Future<List<Map<String, dynamic>>> getProductsByCategory({
    required String vendorId,
    required String category,
    int limit = 10,
  }) async {
    try {
      // 1. Fetch products from master catalog by category
      final productsSnap = await _firestore
          .collection('master_products')
          .where('category', isEqualTo: category)
          .limit(limit * 3) // Fetch extra to ensure inventory availability
          .get();

      if (productsSnap.docs.isEmpty) return [];

      // 2. Enrich with vendor inventory
      // Since we can't easily join, we check inventory for these products
      final products = await _enrichProducts(productsSnap.docs, vendorId, isMasterDocs: true);
      
      return products.take(limit).toList();
    } catch (e) {
      print('❌ Error fetching category products: $e');
      return [];
    }
  }

  /// Enrich inventory documents OR master product documents with inventory data
  Future<List<Map<String, dynamic>>> _enrichProducts(
    List<QueryDocumentSnapshot> docs,
    String vendorId, {
    bool isMasterDocs = false,
  }) async {
    if (docs.isEmpty) return [];

    // If docs are from master_products, we need to check vendor_inventory for these IDs
    if (isMasterDocs) {
      final productIds = docs.map((doc) => doc.id).toList();
      final products = <Map<String, dynamic>>[];

      // Fetch inventory in batches
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();
        
        try {
          final inventorySnap = await _firestore
              .collection('vendor_inventory')
              .where('vendor_id', isEqualTo: vendorId)
              .where('product_id', whereIn: batch)
              .where('isAvailable', isEqualTo: true)
              .get();

          final inventoryMap = {
            for (var doc in inventorySnap.docs)
              (doc.data()['product_id'] as String): doc.data()
          };

          // Only return products that exist in inventory
          for (var masterDoc in docs) {
            if (masterDoc.id != batch.firstWhere((id) => id == masterDoc.id, orElse: () => '')) continue;
            
            if (inventoryMap.containsKey(masterDoc.id)) {
              final inventory = inventoryMap[masterDoc.id]!;
              final productData = masterDoc.data() as Map<String, dynamic>;
              
              products.add({
                ...productData,
                'id': masterDoc.id,
                'price': inventory['selling_price'] ?? productData['price'],
                'stock_quantity': inventory['stock_quantity'] ?? 0,
                'vendor_id': vendorId,
                'isAvailable': true,
              });
            }
          }
        } catch (e) {
          print('Error enriching batch: $e');
        }
      }
      return products;
    }

    // Original logic: docs are inventory documents
    // Extract product IDs
    final productIds = docs
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
    for (var doc in docs) {
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
