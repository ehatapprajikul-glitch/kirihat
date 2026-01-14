import 'package:cloud_firestore/cloud_firestore.dart';

class PriceSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sync seller price to all vendors carrying this product
  Future<void> syncPriceToVendors(
    String productId,
    double newPrice,
    String sellerId,
  ) async {
    try {
      // Find all vendor inventory entries for this product
      var vendorInventory = await _firestore
          .collection('vendor_inventory')
          .where('product_id', isEqualTo: productId)
          .where('price_synced', isEqualTo: true) // Only sync for auto-synced vendors
          .get();

      // Batch update all vendor prices
      WriteBatch batch = _firestore.batch();
      
      for (var doc in vendorInventory.docs) {
        batch.update(doc.reference, {
          'selling_price': newPrice,
          'last_price_sync': FieldValue.serverTimestamp(),
        });

        // Create notification for vendor
        var vendorId = doc.data()['vendor_id'];
        var notificationRef = _firestore.collection('vendor_notifications').doc();
        batch.set(notificationRef, {
          'vendor_id': vendorId,
          'type': 'price_change',
          'product_id': productId,
          'old_price': doc.data()['selling_price'],
          'new_price': newPrice,
          'read': false,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      // Create audit trail
      var auditRef = _firestore.collection('price_sync_audit').doc();
      batch.set(auditRef, {
        'product_id': productId,
        'seller_id': sellerId,
        'new_price': newPrice,
        'vendors_affected': vendorInventory.docs.length,
        'sync_type': 'automatic',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('Price synced to ${vendorInventory.docs.length} vendors');
    } catch (e) {
      print('Error syncing price to vendors: $e');
      rethrow;
    }
  }

  /// Create a price override request from vendor
  Future<String?> createPriceOverrideRequest({
    required String vendorId,
    required String productId,
    required double currentPrice,
    required double proposedPrice,
    required String reason,
    required String justification,
  }) async {
    try {
      // Get vendor and product details
      var vendorDoc = await _firestore.collection('vendors').doc(vendorId).get();
      var productDoc = await _firestore.collection('master_products').doc(productId).get();

      var requestData = {
        'vendor_id': vendorId,
        'vendor_name': vendorDoc.data()?['businessName'] ?? 'Unknown',
        'product_id': productId,
        'product_name': productDoc.data()?['name'] ?? 'Unknown',
        'current_price': currentPrice,
        'proposed_price': proposedPrice,
        'reason': reason,
        'justification': justification,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      };

      var docRef = await _firestore
          .collection('price_override_requests')
          .add(requestData);

      return docRef.id;
    } catch (e) {
      print('Error creating price override request: $e');
      return null;
    }
  }

  /// Approve price override request (Admin only)
  Future<void> approvePriceOverride(
    String requestId,
    String adminId,
    {String? adminNotes, double? revisedPrice}
  ) async {
    try {
      var requestDoc = await _firestore
          .collection('price_override_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      var data = requestDoc.data()!;
      String vendorId = data['vendor_id'];
      String productId = data['product_id'];
      double finalPrice = revisedPrice ?? data['proposed_price']; // Use revised price if provided

      WriteBatch batch = _firestore.batch();

      // Update vendor inventory with custom price
      var inventoryQuery = await _firestore
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('product_id', isEqualTo: productId)
          .limit(1)
          .get();

      if (inventoryQuery.docs.isNotEmpty) {
        batch.update(inventoryQuery.docs.first.reference, {
          'selling_price': finalPrice,
          'price_synced': false, // Disable auto-sync for this vendor
          'price_override_active': true,
          'last_updated': FieldValue.serverTimestamp(),
        });
      }

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'approved',
        'reviewed_by': adminId,
        'reviewed_at': FieldValue.serverTimestamp(),
        'admin_notes': adminNotes,
        if (revisedPrice != null) 'proposed_price': revisedPrice, // Update doc with actual approved price
        if (revisedPrice != null) 'original_proposed_price': data['proposed_price'], // Keep track of original
      });

      // Create audit trail
      var auditRef = _firestore.collection('price_sync_audit').doc();
      batch.set(auditRef, {
        'product_id': productId,
        'vendor_id': vendorId,
        'new_price': finalPrice,
        'sync_type': 'manual_override',
        'approved_by': adminId,
        'timestamp': FieldValue.serverTimestamp(),
        'notes': adminNotes,
      });

      await batch.commit();
    } catch (e) {
      print('Error approving price override: $e');
      rethrow;
    }
  }

  /// Reject price override request (Admin only)
  Future<void> rejectPriceOverride(
    String requestId,
    String adminId,
    String reason,
  ) async {
    try {
      await _firestore
          .collection('price_override_requests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'reviewed_by': adminId,
        'reviewed_at': FieldValue.serverTimestamp(),
        'admin_notes': reason,
      });
    } catch (e) {
      print('Error rejecting price override: $e');
      rethrow;
    }
  }

  /// Get price change audit trail
  Stream<List<Map<String, dynamic>>> getPriceSyncAuditTrail({
    String? productId,
    String? vendorId,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('price_sync_audit')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (productId != null) {
      query = query.where('product_id', isEqualTo: productId);
    }

    if (vendorId != null) {
      query = query.where('vendor_id', isEqualTo: vendorId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList());
  }

  /// Get pending price override requests (Admin)
  Stream<List<Map<String, dynamic>>> getPendingPriceOverrideRequests() {
    return _firestore
        .collection('price_override_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }
  
  /// Get history of price override requests (Approved/Rejected)
  Stream<List<Map<String, dynamic>>> getHistoryPriceOverrideRequests({int limit = 20}) {
    return _firestore
        .collection('price_override_requests')
        .where('status', whereIn: ['approved', 'rejected'])
        .orderBy('reviewed_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  /// Get vendor's price override requests
  Stream<List<Map<String, dynamic>>> getVendorPriceOverrideRequests(String vendorId) {
    return _firestore
        .collection('price_override_requests')
        .where('vendor_id', isEqualTo: vendorId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }
}
