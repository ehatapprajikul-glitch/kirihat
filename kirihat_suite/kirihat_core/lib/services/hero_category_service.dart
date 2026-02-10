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
      print('❌ Error fetching vendor hero categories: $e');
      return [];
    }
  }

  /// Get ALL hero categories (admin-controlled, shown to all customers)
  Future<List<Map<String, dynamic>>> getAdminHeroCategories() async {
    try {
      final snapshot = await _firestore
          .collection('hero_categories')
          .orderBy('position')
          .get();

      List<Map<String, dynamic>> heroCategories = [];
      for (var doc in snapshot.docs) {
        final heroData = doc.data();
        heroData['id'] = doc.id;
        heroCategories.add(heroData);
      }

      print('✅ Fetched ${heroCategories.length} admin hero categories');
      return heroCategories;
    } catch (e) {
      print('❌ Error fetching admin hero categories: $e');
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

      // 1. Get all available product IDs from vendor inventory
      final inventorySnapshot = await _firestore
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('isAvailable', isEqualTo: true)
          .limit(500) // Reasonable limit for a single vendor
          .get();

      if (inventorySnapshot.docs.isEmpty) {
        print('⚠️ No inventory found for vendor: $vendorId');
        return [];
      }

      final productIds = inventorySnapshot.docs
          .map((doc) => doc.data()['product_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (productIds.isEmpty) return [];

      // 2. Get categories present in these products
      final Set<String> availableCategoryNames = {};
      
      // Batch fetch master products to check their categories
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();
        try {
          final productsSnapshot = await _firestore
              .collection('master_products')
              .where(FieldPath.documentId, whereIn: batch)
              // .select() not supported in Flutter client SDK, fetching full docs
              .get();

          for (var doc in productsSnapshot.docs) {
            final data = doc.data();
            if (data['category'] != null) availableCategoryNames.add(data['category'].toString());
            // Optionally check subcategories too if needed, but usually we filter by root category content
          }
        } catch (e) {
          print('Error fetching product batch: $e');
        }
      }

      print('✅ Vendor has products in ${availableCategoryNames.length} categories');

      // 3. Fetch requested categories and filter
      List<Map<String, dynamic>> availableCategories = [];
      
      for (int i = 0; i < categoryIds.length; i += 10) {
        final batch = categoryIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('categories')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in snapshot.docs) {
          final categoryData = doc.data();
          final categoryName = categoryData['name'] as String?;
          
          // Check if this category name exists in our available set
          if (categoryName != null && availableCategoryNames.contains(categoryName)) {
             categoryData['id'] = doc.id;
             availableCategories.add(categoryData);
          }
        }
      }

      print('✅ Found ${availableCategories.length} available hero categories for display');
      return availableCategories;
    } catch (e) {
      print('❌ Error fetching categories with inventory: $e');
      return []; // Return empty list on error instead of throwing
    }
  }

  /// Get subcategories for a category (from same categories collection)
  Future<List<Map<String, dynamic>>> getSubcategories(String categoryId) async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('parent_id', isEqualTo: categoryId)
          .where('isActive', isEqualTo: true)
          .orderBy('sort_order')
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
