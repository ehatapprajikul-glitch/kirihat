import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchService {
  static const String _historyKey = 'search_history';
  static const String _vendorKey = 'assigned_vendor_id';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves a search query to local history (no duplicates, max 10 items)
  Future<void> saveSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    
    // Remove if exists to move to top
    history.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    
    // Add to top
    history.insert(0, query.trim());
    
    // Keep max 10
    if (history.length > 10) {
      history = history.sublist(0, 10);
    }
    
    await prefs.setStringList(_historyKey, history);
  }

  /// Retrieves recent searches from local storage
  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  /// Clears search history
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  /// Comprehensive search across multiple fields:
  /// - Product name
  /// - Keywords (SEO keywords array)
  /// - SEO title
  /// - Tags
  /// - Category
  /// - Subcategory
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.length < 2) return [];

    final searchLower = query.toLowerCase();
    
    // Get current vendor ID
    final prefs = await SharedPreferences.getInstance();
    final vendorId = prefs.getString(_vendorKey);
    
    if (vendorId == null) {
      print('⚠️ No vendor ID found, search may show out-of-stock products');
    }
    
    try {
      // Fetch a broader set of products and filter client-side
      // This is more reliable than Firestore's limited text search
      final snapshot = await _firestore
          .collection('master_products')
          .limit(100) // Fetch more products for better client-side filtering
          .get();

      final List<Map<String, dynamic>> matchedProducts = [];
      final Set<String> seenIds = {};

      for (var doc in snapshot.docs) {
        if (seenIds.contains(doc.id)) continue;

        final data = doc.data();
        data['id'] = doc.id;

        // Check if query matches any searchable field
        if (_matchesSearch(data, searchLower)) {
          matchedProducts.add(data);
          seenIds.add(doc.id);
        }

        // Limit results to 20
        if (matchedProducts.length >= 20) break;
      }

      // Sort by relevance (exact matches first)
      matchedProducts.sort((a, b) {
        final aScore = _calculateRelevanceScore(a, searchLower);
        final bScore = _calculateRelevanceScore(b, searchLower);
        return bScore.compareTo(aScore);
      });

      // Enrich with vendor inventory data if vendor ID is available
      final enrichedProducts = vendorId != null 
          ? await _enrichWithVendorInventory(matchedProducts, vendorId)
          : matchedProducts;

      print('🔍 Search for "$query" found ${enrichedProducts.length} products');
      return enrichedProducts;
    } catch (e) {
      print('❌ Search error: $e');
      return [];
    }
  }

  /// Enrich products with vendor inventory data (stock, price, availability)
  Future<List<Map<String, dynamic>>> _enrichWithVendorInventory(
    List<Map<String, dynamic>> products,
    String vendorId,
  ) async {
    if (products.isEmpty) return [];

    final productIds = products.map((p) => p['id'] as String).toList();
    final enrichedProducts = <Map<String, dynamic>>[];

    try {
      // Fetch vendor inventory in batches of 10 (Firestore limit)
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();
        
        final inventorySnap = await _firestore
            .collection('vendor_inventory')
            .where('vendor_id', isEqualTo: vendorId)
            .where('product_id', whereIn: batch)
            .get();

        // Create inventory map for quick lookup
        final inventoryMap = <String, Map<String, dynamic>>{};
        for (var doc in inventorySnap.docs) {
          final data = doc.data();
          final productId = data['product_id'];
          if (productId != null) {
            inventoryMap[productId] = data;
          }
        }

        // Enrich products with inventory data
        for (var product in products.skip(i).take(10)) {
          final productId = product['id'];
          final inventory = inventoryMap[productId];

          if (inventory != null) {
            // Product exists in vendor inventory
            enrichedProducts.add({
              ...product,
              'price': inventory['selling_price'] ?? product['price'],
              'stock_quantity': inventory['stock_quantity'] ?? 0,
              'vendor_id': vendorId,
              'isAvailable': inventory['isAvailable'] ?? true,
              'isAvailableInCurrentVendor': true,
            });
          } else {
            // Product not in vendor inventory - mark as unavailable
            enrichedProducts.add({
              ...product,
              'vendor_id': vendorId,
              'stock_quantity': 0,
              'isAvailable': false,
              'isAvailableInCurrentVendor': false,
            });
          }
        }
      }

      print('✅ Enriched ${enrichedProducts.length} products with vendor inventory');
      return enrichedProducts;
    } catch (e) {
      print('❌ Error enriching with vendor inventory: $e');
      // Return original products if enrichment fails
      return products.map((p) => {...p, 'vendor_id': vendorId}).toList();
    }
  }

  /// Check if product matches search query across multiple fields
  bool _matchesSearch(Map<String, dynamic> product, String searchLower) {
    // Product name
    final name = (product['name'] ?? '').toString().toLowerCase();
    if (name.contains(searchLower)) return true;

    // SEO title
    final seoTitle = (product['seo_title'] ?? '').toString().toLowerCase();
    if (seoTitle.contains(searchLower)) return true;

    // Category
    final category = (product['category'] ?? '').toString().toLowerCase();
    if (category.contains(searchLower)) return true;

    // Subcategory
    final subcategory = (product['subcategory'] ?? '').toString().toLowerCase();
    if (subcategory.contains(searchLower)) return true;

    // Keywords (array)
    final keywords = product['keywords'];
    if (keywords is List) {
      for (var keyword in keywords) {
        if (keyword.toString().toLowerCase().contains(searchLower)) {
          return true;
        }
      }
    }

    // Tags (array)
    final tags = product['tags'];
    if (tags is List) {
      for (var tag in tags) {
        if (tag.toString().toLowerCase().contains(searchLower)) {
          return true;
        }
      }
    }

    // Brand
    final brand = (product['brand'] ?? '').toString().toLowerCase();
    if (brand.contains(searchLower)) return true;

    return false;
  }

  /// Calculate relevance score for sorting
  /// Higher score = more relevant
  int _calculateRelevanceScore(Map<String, dynamic> product, String searchLower) {
    int score = 0;

    final name = (product['name'] ?? '').toString().toLowerCase();
    final seoTitle = (product['seo_title'] ?? '').toString().toLowerCase();
    final category = (product['category'] ?? '').toString().toLowerCase();

    // Exact name match (highest priority)
    if (name == searchLower) score += 100;
    // Name starts with query
    else if (name.startsWith(searchLower)) score += 50;
    // Name contains query
    else if (name.contains(searchLower)) score += 25;

    // SEO title match
    if (seoTitle.contains(searchLower)) score += 15;

    // Category match
    if (category == searchLower) score += 20;
    else if (category.contains(searchLower)) score += 10;

    // Keywords match
    final keywords = product['keywords'];
    if (keywords is List) {
      for (var keyword in keywords) {
        if (keyword.toString().toLowerCase() == searchLower) {
          score += 30;
          break;
        } else if (keyword.toString().toLowerCase().contains(searchLower)) {
          score += 15;
          break;
        }
      }
    }

    return score;
  }
}
