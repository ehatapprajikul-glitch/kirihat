import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing user wishlist (add, remove, check)
class WishlistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a product to user's wishlist
  Future<void> addToWishlist(String userId, String productId, {String? sourceVendorId}) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(productId)
          .set({
        'addedAt': FieldValue.serverTimestamp(),
        if (sourceVendorId != null) 'sourceVendorId': sourceVendorId,
      });
      print('✅ Added $productId to wishlist');
    } catch (e) {
      print('Error adding to wishlist: $e');
      rethrow;
    }
  }

  /// Remove a product from user's wishlist
  Future<void> removeFromWishlist(String userId, String productId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(productId)
          .delete();
      print('🗑️ Removed $productId from wishlist');
    } catch (e) {
      print('Error removing from wishlist: $e');
      rethrow;
    }
  }

  /// Check if a product is in user's wishlist
  Future<bool> isInWishlist(String userId, String productId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(productId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking wishlist: $e');
      return false;
    }
  }

  /// Get all wishlist product IDs for a user
  Future<List<String>> getWishlistProductIds(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .get();
      return snap.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error fetching wishlist: $e');
      return [];
    }
  }

  /// Stream of wishlist IDs as a Set for efficient checking (Broadcast)
  Stream<Set<String>> watchWishlistSet(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toSet())
        .asBroadcastStream();
  }

  /// Toggle wishlist status (add if not exists, remove if exists)
  Future<bool> toggleWishlist(String userId, String productId, {String? sourceVendorId}) async {
    final isInList = await isInWishlist(userId, productId);
    if (isInList) {
      await removeFromWishlist(userId, productId);
      return false; // Removed
    } else {
      await addToWishlist(userId, productId, sourceVendorId: sourceVendorId);
      return true; // Added
    }
  }
}
