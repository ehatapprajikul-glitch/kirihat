import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for tracking and retrieving recently viewed products
class RecentlyViewedService {
  static const String _key = 'recently_viewed';
  static const int _maxItems = 20;

  /// Add a product to recently viewed list
  static Future<void> addProduct(Map<String, dynamic> product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentJson = prefs.getStringList(_key) ?? [];
      
      // Decode existing products
      List<Map<String, dynamic>> recent = recentJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      
      // Remove if already exists (to move to front)
      recent.removeWhere((p) => p['id'] == product['id']);
      
      // Add to front with minimal data
      recent.insert(0, {
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'imageUrl': product['imageUrl'] ?? 
                   (product['images'] != null && (product['images'] as List).isNotEmpty 
                       ? product['images'][0] 
                       : ''),
        'vendor_id': product['vendor_id'],
        'category': product['category'],
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Limit size
      if (recent.length > _maxItems) {
        recent = recent.sublist(0, _maxItems);
      }
      
      // Save back
      recentJson = recent.map((p) => jsonEncode(p)).toList();
      await prefs.setStringList(_key, recentJson);
      
      print('✅ Added to recently viewed: ${product['name']}');
    } catch (e) {
      print('❌ Error adding to recently viewed: $e');
    }
  }

  /// Get list of recently viewed products
  static Future<List<Map<String, dynamic>>> getRecentlyViewed({int? limit}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentJson = prefs.getStringList(_key) ?? [];
      
      var recent = recentJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      
      // Apply limit if specified
      if (limit != null && recent.length > limit) {
        recent = recent.sublist(0, limit);
      }
      
      return recent;
    } catch (e) {
      print('❌ Error getting recently viewed: $e');
      return [];
    }
  }

  /// Clear all recently viewed products
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      print('🗑️ Cleared recently viewed');
    } catch (e) {
      print('❌ Error clearing recently viewed: $e');
    }
  }

  /// Remove a specific product from recently viewed
  static Future<void> removeProduct(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentJson = prefs.getStringList(_key) ?? [];
      
      var recent = recentJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      
      recent.removeWhere((p) => p['id'] == productId);
      
      recentJson = recent.map((p) => jsonEncode(p)).toList();
      await prefs.setStringList(_key, recentJson);
      
      print('🗑️ Removed from recently viewed: $productId');
    } catch (e) {
      print('❌ Error removing from recently viewed: $e');
    }
  }

  /// Get count of recently viewed products
  static Future<int> getCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentJson = prefs.getStringList(_key) ?? [];
      return recentJson.length;
    } catch (e) {
      print('❌ Error getting recently viewed count: $e');
      return 0;
    }
  }
}
