import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service class for inventory management operations
class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current vendor ID
  String? get _vendorId => _auth.currentUser?.uid;

  /// Calculate comprehensive inventory metrics for a vendor
  Future<Map<String, dynamic>> calculateMetrics(String vendorId) async {
    try {
      final products = await _firestore
          .collection('products')
          .where('vendor_id', isEqualTo: vendorId)
          .get();

      final docs = products.docs;
      final total = docs.length;

      // Count by stock status
      int inStock = 0;
      int lowStock = 0;
      int outOfStock = 0;
      double totalValue = 0.0;
      final categoryCount = <String>{};

      for (var doc in docs) {
        final data = doc.data();
        final stock = data['stock_quantity'] ?? 0;
        final price = (data['price'] ?? 0).toDouble();

        if (stock == 0) {
          outOfStock++;
        } else if (stock < 5) {
          lowStock++;
          inStock++;
        } else {
          inStock++;
        }

        totalValue += stock * price;

        final category = data['category'];
        if (category != null) {
          categoryCount.add(category.toString());
        }
      }

      // Calculate products added this month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      int productsThisMonth = 0;

      for (var doc in docs) {
        final data = doc.data();
        if (data['created_at'] != null) {
          final createdAt = (data['created_at'] as Timestamp).toDate();
          if (createdAt.isAfter(startOfMonth)) {
            productsThisMonth++;
          }
        }
      }

      // Calculate average stock level
      final avgStock = total > 0
          ? docs.fold<int>(0, (sum, doc) {
                final data = doc.data();
                return sum + (data['stock_quantity'] ?? 0) as int;
              }) /
              total
          : 0.0;

      return {
        'total': total,
        'inStock': inStock,
        'lowStock': lowStock,
        'outOfStock': outOfStock,
        'totalValue': totalValue,
        'categoriesCount': categoryCount.length,
        'productsThisMonth': productsThisMonth,
        'averageStock': avgStock.round(),
      };
    } catch (e) {
      throw Exception('Failed to calculate metrics: $e');
    }
  }

  /// Bulk delete products (with vendor verification)
  Future<void> bulkDelete(List<String> productIds, String vendorId) async {
    try {
      final batch = _firestore.batch();

      for (var id in productIds) {
        // Verify ownership before deleting
        final doc = await _firestore.collection('products').doc(id).get();
        if (doc.exists && doc.data()?['vendor_id'] == vendorId) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk delete: $e');
    }
  }

  /// Bulk update category for multiple products
  Future<void> bulkUpdateCategory(
    List<String> productIds,
    String newCategory,
    String vendorId,
  ) async {
    try {
      final batch = _firestore.batch();

      for (var id in productIds) {
        final doc = await _firestore.collection('products').doc(id).get();
        if (doc.exists && doc.data()?['vendor_id'] == vendorId) {
          batch.update(doc.reference, {
            'category': newCategory,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk update category: $e');
    }
  }

  /// Adjust stock quantity for a product (using transaction for safety)
  Future<void> adjustStock(
    String productId,
    int adjustment, {
    String? reason,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('products').doc(productId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw Exception('Product not found');
        }

        final currentStock = doc.data()?['stock_quantity'] ?? 0;
        final newStock = (currentStock + adjustment).clamp(0, 999999);

        transaction.update(docRef, {
          'stock_quantity': newStock,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Log stock history
        transaction.set(_firestore.collection('stock_history').doc(), {
          'product_id': productId,
          'vendor_id': doc.data()?['vendor_id'],
          'previous_stock': currentStock,
          'new_stock': newStock,
          'adjustment': adjustment,
          'reason': reason ?? 'Manual adjustment',
          'adjusted_by': _vendorId,
          'adjusted_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to adjust stock: $e');
    }
  }

  /// Bulk adjust stock for multiple products
  Future<void> bulkAdjustStock(
    Map<String, int> productAdjustments,
    String vendorId,
  ) async {
    try {
      final batch = _firestore.batch();

      for (var entry in productAdjustments.entries) {
        final productId = entry.key;
        final adjustment = entry.value;

        final doc = await _firestore.collection('products').doc(productId).get();
        if (doc.exists && doc.data()?['vendor_id'] == vendorId) {
          final currentStock = doc.data()?['stock_quantity'] ?? 0;
          final newStock = (currentStock + adjustment).clamp(0, 999999);

          batch.update(doc.reference, {
            'stock_quantity': newStock,
            'updated_at': FieldValue.serverTimestamp(),
          });

          // Log to history
          batch.set(_firestore.collection('stock_history').doc(), {
            'product_id': productId,
            'vendor_id': vendorId,
            'previous_stock': currentStock,
            'new_stock': newStock,
            'adjustment': adjustment,
            'reason': 'Bulk adjustment',
            'adjusted_by': _vendorId,
            'adjusted_at': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk adjust stock: $e');
    }
  }

  /// Generate SKU code for a product
  String generateSKU({
    required String vendorId,
    required String categoryName,
    int? productCount,
  }) {
    // Format: VEND-CAT-001
    final vendorPrefix = vendorId.substring(0, 4).toUpperCase();
    final categoryPrefix = categoryName.substring(0, 3).toUpperCase();
    final number = (productCount ?? 0 + 1).toString().padLeft(3, '0');

    return '$vendorPrefix-$categoryPrefix-$number';
  }

  /// Get low stock products for a vendor
  Future<List<DocumentSnapshot>> getLowStockProducts(
    String vendorId, {
    int threshold = 5,
  }) async {
    try {
      final query = await _firestore
          .collection('products')
          .where('vendor_id', isEqualTo: vendorId)
          .get();

      return query.docs
          .where((doc) {
            final stock = doc.data()['stock_quantity'] ?? 0;
            return stock > 0 && stock < threshold;
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to get low stock products: $e');
    }
  }

  /// Get stock history for a product
  Future<List<Map<String, dynamic>>> getStockHistory(String productId) async {
    try {
      final history = await _firestore
          .collection('stock_history')
          .where('product_id', isEqualTo: productId)
          .orderBy('adjusted_at', descending: true)
          .limit(50)
          .get();

      return history.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get stock history: $e');
    }
  }

  /// Get category performance metrics
  Future<Map<String, dynamic>> getCategoryMetrics(
    String vendorId,
    String category,
  ) async {
    try {
      final products = await _firestore
          .collection('products')
          .where('vendor_id', isEqualTo: vendorId)
          .where('category', isEqualTo: category)
          .get();

      final total = products.docs.length;
      final totalStock = products.docs.fold<int>(
        0,
        (sum, doc) => sum + (doc.data()['stock_quantity'] ?? 0) as int,
      );
      final totalValue = products.docs.fold<double>(
        0.0,
        (sum, doc) {
          final stock = doc.data()['stock_quantity'] ?? 0;
          final price = (doc.data()['price'] ?? 0).toDouble();
          return sum + (stock * price);
        },
      );

      return {
        'productCount': total,
        'totalStock': totalStock,
        'totalValue': totalValue,
        'averagePrice': total > 0
            ? products.docs.fold<double>(
                  0.0,
                  (sum, doc) => sum + (doc.data()['price'] ?? 0).toDouble(),
                ) /
                total
            : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get category metrics: $e');
    }
  }
}
