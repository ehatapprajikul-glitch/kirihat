import 'package:cloud_firestore/cloud_firestore.dart';

class HeroCategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get hero categories selected by vendor
  Future<List<Map<String, dynamic>>> getVendorHeroCategories(String vendorId) async {
    try {
      // 1. Get vendor's selected hero category IDs
      final selectionDoc = await _firestore
          .collection('vendor_catalog_selections')
          .doc(vendorId)
          .get();

      if (!selectionDoc.exists) {
        print('⚠️ No catalog selection found for vendor: $vendorId');
        return [];
      }

      final data = selectionDoc.data() as Map<String, dynamic>;
      final heroIds = List<String>.from(data['hero_category_ids'] ?? []);

      if (heroIds.isEmpty) {
        print('⚠️ Vendor has not selected any hero categories');
        return [];
      }

      // 2. Fetch hero category details (in batches of 10 due to Firestore limit)
      List<Map<String, dynamic>> heroCategories = [];

      for (int i = 0; i < heroIds.length; i += 10) {
        final batch = heroIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('hero_categories')
            .where(FieldPath.documentId, whereIn: batch)
            .orderBy('position')
            .get();

        for (var doc in snapshot.docs) {
          final heroData = doc.data();
          heroData['id'] = doc.id;
          heroCategories.add(heroData);
        }
      }

      // Sort by position
      heroCategories.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));

      print('✅ Fetched ${heroCategories.length} hero categories for vendor');
      return heroCategories;
    } catch (e) {
      print('❌ Error fetching hero categories: $e');
      return [];
    }
  }

  /// Get categories under a hero category that have vendor inventory
  Future<List<Map<String, dynamic>>> getCategoriesWithInventory({
    required String vendorId,
    required List<String> categoryIds,
  }) async {
    try {
      if (categoryIds.isEmpty) return [];

      List<Map<String, dynamic>> availableCategories = [];

      // Fetch category details (in batches)
      for (int i = 0; i < categoryIds.length; i += 10) {
        final batch = categoryIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('categories')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in snapshot.docs) {
          final categoryId = doc.id;
          final categoryData = doc.data();

          // Check if vendor has inventory in this category
          final hasInventory = await _checkCategoryInventory(vendorId, categoryData['name']);

          if (hasInventory) {
            categoryData['id'] = categoryId;
            availableCategories.add(categoryData);
          }
        }
      }

      print('✅ Found ${availableCategories.length} categories with inventory');
      return availableCategories;
    } catch (e) {
      print('❌ Error fetching categories: $e');
      return [];
    }
  }

  /// Check if vendor has any products in a category
  Future<bool> _checkCategoryInventory(String vendorId, String categoryName) async {
    try {
      // Get product IDs from vendor inventory
      final inventorySnapshot = await _firestore
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('isAvailable', isEqualTo: true)
          .limit(100)
          .get();

      if (inventorySnapshot.docs.isEmpty) return false;

      // Extract product IDs
      final productIds = inventorySnapshot.docs
          .map((doc) => doc.data()['product_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (productIds.isEmpty) return false;

      // Check if any products are in this category (batched)
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();
        final productsSnapshot = await _firestore
            .collection('master_products')
            .where(FieldPath.documentId, whereIn: batch)
            .where('category', isEqualTo: categoryName)
            .limit(1)
            .get();

        if (productsSnapshot.docs.isNotEmpty) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking inventory: $e');
      return false;
    }
  }

  /// Get subcategories for a category
  Future<List<Map<String, dynamic>>> getSubcategories(String categoryId) async {
    try {
      final snapshot = await _firestore
          .collection('subcategories')
          .where('category_id', isEqualTo: categoryId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching subcategories: $e');
      return [];
    }
  }
}
