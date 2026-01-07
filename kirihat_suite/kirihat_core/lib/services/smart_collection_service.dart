import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/collection_model.dart';

class SmartCollectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Dynamic Collection Generation (Customer) ---

  // Generate Wishlist Collection (user-specific, vendor-agnostic)
  Future<CollectionModel?> getWishlistCollection(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .get();

      final productIds = snap.docs.map((doc) => doc.id).toList();

      // Always return collection even if empty
      return CollectionModel(
        id: 'smart_wishlist',
        name: 'My Wishlist',
        productIds: productIds,
        isActive: true,
        sortOrder: -10,
      );
    } catch (e) {
      print('Error fetching wishlist: $e');
      return null;
    }
  }

  // Generate Buy Again Collection (user-specific, vendor-agnostic)
  Future<CollectionModel?> getBuyAgainCollection(String userId) async {
    try {
      // Fetch ALL user orders (not vendor-specific)
      final snap = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      if (snap.docs.isEmpty) {
        return CollectionModel(
          id: 'smart_buy_again',
          name: 'Buy Again',
          productIds: [],
          isActive: true,
          sortOrder: -9,
        );
      }

      final Map<String, int> frequencies = {};

      for (var doc in snap.docs) {
        final items = (doc.data()['items'] as List<dynamic>? ?? []);
        for (var item in items) {
          final pid = item['productId'];
          if (pid != null) {
            frequencies[pid] = (frequencies[pid] ?? 0) + 1;
          }
        }
      }

      final sortedIds = frequencies.keys.toList()
        ..sort((a, b) => frequencies[b]!.compareTo(frequencies[a]!));

      return CollectionModel(
        id: 'smart_buy_again',
        name: 'Buy Again',
        productIds: sortedIds.take(20).toList(),
        isActive: true,
        sortOrder: -9,
      );
    } catch (e) {
      print('Error fetching buy again: $e');
      return null;
    }
  }

  // Generate New Arrivals Collection (global, vendor-agnostic)
  Future<CollectionModel?> getNewArrivalsCollection() async {
    try {
      // Fetch recently added products across all vendors
      final snap = await _firestore
          .collection('master_products')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final productIds = snap.docs.map((doc) => doc.id).toList();

      return CollectionModel(
        id: 'smart_new_arrivals',
        name: 'New Arrivals',
        productIds: productIds,
        isActive: true,
        sortOrder: -8,
      );
    } catch (e) {
      print('Error fetching new arrivals: $e');
      // If no createdAt index, return empty collection
      return CollectionModel(
        id: 'smart_new_arrivals',
        name: 'New Arrivals',
        productIds: [],
        isActive: true,
        sortOrder: -8,
      );
    }
  }
}
