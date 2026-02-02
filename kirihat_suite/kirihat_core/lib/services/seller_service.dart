import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/seller_model.dart';
import '../models/seller_product_request.dart';
import '../models/warehouse_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/shipment_model.dart';

class SellerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get seller by user ID
  Future<SellerModel?> getSellerByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('sellers')
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return SellerModel.fromMap(
        querySnapshot.docs.first.data(),
        querySnapshot.docs.first.id,
      );
    } catch (e) {
      print('Error getting seller by user ID: $e');
      return null;
    }
  }

  // Get current seller
  Future<SellerModel?> getCurrentSeller() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    return getSellerByUserId(userId);
  }

  // --- Analytics & Billing ---

  // Get aggregated stats (Total Sales, Orders, etc.)
  Future<Map<String, dynamic>> getSellerStats(String sellerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('seller_ids', arrayContains: sellerId) // Updated query
          .where('status', isEqualTo: 'Delivered') // Only count delivered for revenue
          .get();

      double totalRevenue = 0;
      int totalOrders = querySnapshot.docs.length;
      
      for (var doc in querySnapshot.docs) {
        totalRevenue += (doc.data()['total_amount'] ?? 0).toDouble();
      }

      // Calculate Pending Orders count for badge
      final pendingSnapshot = await _firestore
          .collection('orders')
          .where('seller_ids', arrayContains: sellerId) // Updated query
          .where('status', isEqualTo: 'Pending')
          .count()
          .get();

      return {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'pendingOrders': pendingSnapshot.count,
      };
    } catch (e) {
      print('Error fetching stats: $e');
      return {'totalRevenue': 0.0, 'totalOrders': 0, 'pendingOrders': 0};
    }
  }

  // Get recent orders for the seller
  Stream<QuerySnapshot> getSellerOrders(String sellerId, {int limit = 10}) {
    return _firestore
        .collection('orders')
        .where('seller_ids', arrayContains: sellerId) // Updated query
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots();
  }

  // Get seller by ID
  Future<SellerModel?> getSellerById(String sellerId) async {
    try {
      final doc = await _firestore.collection('sellers').doc(sellerId).get();
      if (!doc.exists) return null;
      return SellerModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('Error getting seller: $e');
      return null;
    }
  }

  // Create new seller
  Future<String?> createSeller(SellerModel seller) async {
    try {
      final docRef = await _firestore.collection('sellers').add(seller.toMap());
      
      // Update user document with seller role
      await _firestore.collection('users').doc(seller.userId).update({
        'role': 'seller',
        'seller_id': docRef.id,
      });

      return docRef.id;
    } catch (e) {
      print('Error creating seller: $e');
      return null;
    }
  }

  // Update seller
  Future<bool> updateSeller(String sellerId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('sellers').doc(sellerId).update(updates);
      return true;
    } catch (e) {
      print('Error updating seller: $e');
      return false;
    }
  }

  // Get all sellers (for admin)
  Stream<List<SellerModel>> getAllSellers() {
    return _firestore
        .collection('sellers')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SellerModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Upload document
  Future<String?> uploadDocument(String sellerId, String docType, XFile file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('sellers')
          .child(sellerId)
          .child('documents')
          .child('${docType}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // For Web support use bytes
      final bytes = await file.readAsBytes();
      final task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading document: $e');
      return null;
    }
  }

  // Update seller documents
  Future<bool> updateSellerDocuments(String sellerId, Map<String, String> documents) async {
     try {
       await _firestore.collection('sellers').doc(sellerId).set({
         'documents': documents,
         // We might not want to reset verified immediately if just updating one, but for safety let's assume we do.
         // 'verified': false, 
       }, SetOptions(merge: true));
       return true;
     } catch (e) {
       print('Error updating seller documents: $e');
       return false;
     }
  }

  // Get sellers by status
  Stream<List<SellerModel>> getSellersByStatus(String status) {
    return _firestore
        .collection('sellers')
        .where('status', isEqualTo: status)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SellerModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Approve seller
  Future<bool> approveSeller(String sellerId, String adminUserId) async {
    try {
      await _firestore.collection('sellers').doc(sellerId).update({
        'status': 'active',
        'verified': true,
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': adminUserId,
      });
      return true;
    } catch (e) {
      print('Error approving seller: $e');
      return false;
    }
  }

  // Reject seller
  Future<bool> rejectSeller(String sellerId, String adminUserId, String reason) async {
    try {
      await _firestore.collection('sellers').doc(sellerId).update({
        'status': 'rejected',
        'rejected_at': FieldValue.serverTimestamp(),
        'rejected_by': adminUserId,
        'rejection_reason': reason,
      });
      return true;
    } catch (e) {
      print('Error rejecting seller: $e');
      return false;
    }
  }

  // Submit product request
  Future<String?> submitProductRequest(
    String sellerId,
    Map<String, dynamic> productData,
  ) async {
    try {
      final request = SellerProductRequest(
        id: '',
        sellerId: sellerId,
        productData: productData,
        submittedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('seller_product_requests')
          .add(request.toMap());

      return docRef.id;
    } catch (e) {
      print('Error submitting product request: $e');
      return null;
    }
  }

  // Get product requests for seller
  Stream<List<SellerProductRequest>> getSellerProductRequests(String sellerId) {
    return _firestore
        .collection('seller_product_requests')
        .where('seller_id', isEqualTo: sellerId)
        .orderBy('submitted_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SellerProductRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get pending product requests (for admin)
  Stream<List<SellerProductRequest>> getPendingProductRequests() {
    return _firestore
        .collection('seller_product_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('submitted_at', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SellerProductRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Approve product request
  Future<bool> approveProductRequest(
    String requestId,
    String adminUserId,
    String masterProductId,
  ) async {
    try {
      await _firestore.collection('seller_product_requests').doc(requestId).update({
        'status': 'approved',
        'reviewed_at': FieldValue.serverTimestamp(),
        'reviewed_by': adminUserId,
        'master_product_id': masterProductId,
      });
      return true;
    } catch (e) {
      print('Error approving product request: $e');
      return false;
    }
  }

  // Reject product request
  Future<bool> rejectProductRequest(
    String requestId,
    String adminUserId,
    String notes,
  ) async {
    try {
      await _firestore.collection('seller_product_requests').doc(requestId).update({
        'status': 'rejected',
        'reviewed_at': FieldValue.serverTimestamp(),
        'reviewed_by': adminUserId,
        'admin_notes': notes,
      });
      return true;
    } catch (e) {
      print('Error rejecting product request: $e');
      return false;
    }
  }

  // Request revision
  Future<bool> requestRevision(
    String requestId,
    String adminUserId,
    String notes,
  ) async {
    try {
      final doc = await _firestore
          .collection('seller_product_requests')
          .doc(requestId)
          .get();
      
      final currentRevisionCount = doc.data()?['revision_count'] ?? 0;

      await _firestore.collection('seller_product_requests').doc(requestId).update({
        'status': 'revision_needed',
        'reviewed_at': FieldValue.serverTimestamp(),
        'reviewed_by': adminUserId,
        'admin_notes': notes,
        'revision_count': currentRevisionCount + 1,
      });
      return true;
    } catch (e) {
      print('Error requesting revision: $e');
      return false;
    }
  }

  // Resubmit rejected/revision request
  Future<bool> resubmitProductRequest(
    String requestId,
    Map<String, dynamic> newData,
  ) async {
    try {
      // newData comes from EnhancedAddProductScreen and contains flattened structure + 'specifications' + 'keywords'.
      // However, the original structure has 'product_data' (map) and other root fields.
      // We must reconstruct the 'product_data' map and update it.
      
      // Extract root-level fields if they exist in newData (EnhancedAddProductScreen puts them there)
      final specifications = newData['specifications'];
      final keywords = newData['keywords'];
      
      // The rest is basically product_data, but EnhancedAddProductScreen sends a combined map.
      // Ideally, we should update the 'product_data' field with the full map.
      // And also update root fields 'specifications' and 'keywords' to ensure they are insync.
      
      // Note: Admin view reads from 'product_data'. Model reads 'product_data' and root 'specifications'.
      // Best approach: Update 'product_data' with the whole map (it's okay if it has duplicate top-level keys inside),
      // AND update root fields.
      
      await _firestore.collection('seller_product_requests').doc(requestId).update({
        'product_data': newData, // Update the nested map which admin sees
        'specifications': specifications, // Update root specs
        'keywords': keywords, // Update root keywords
        'status': 'pending',
        'submitted_at': FieldValue.serverTimestamp(),
        'admin_notes': FieldValue.delete(), // Clear rejection notes on resubmit
      });
      return true;
    } catch (e) {
      print('Error resubmitting request: $e');
      return false;
    }
  }

  // --- Product Draft Management (Multiple Drafts) ---

  // Save product draft (creates new or updates existing)
  Future<String?> saveProductDraft(
    String sellerId,
    Map<String, dynamic> draftData, {
    String? draftId, // If provided, updates existing draft
  }) async {
    try {
      // Generate title from product name or use "Untitled Draft"
      final draftTitle = (draftData['name'] != null && draftData['name'].toString().isNotEmpty)
          ? draftData['name'].toString()
          : 'Untitled Draft';

      if (draftId != null) {
        // Update existing draft
        await _firestore
            .collection('seller_product_drafts')
            .doc(draftId)
            .update({
          'draft_title': draftTitle,
          'draft_data': draftData,
          'updated_at': FieldValue.serverTimestamp(),
        });
        return draftId;
      } else {
        // Create new draft
        final docRef = await _firestore.collection('seller_product_drafts').add({
          'seller_id': sellerId,
          'draft_title': draftTitle,
          'draft_data': draftData,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        return docRef.id;
      }
    } catch (e) {
      print('Error saving product draft: $e');
      return null;
    }
  }

  // Get all product drafts for seller
  Stream<QuerySnapshot> getAllProductDrafts(String sellerId) {
    return _firestore
        .collection('seller_product_drafts')
        .where('seller_id', isEqualTo: sellerId)
        .orderBy('updated_at', descending: false) // Changed to match Firebase index
        .snapshots();
  }

  // Get specific product draft by ID
  Future<Map<String, dynamic>?> getProductDraftById(String draftId) async {
    try {
      final doc = await _firestore
          .collection('seller_product_drafts')
          .doc(draftId)
          .get();

      if (!doc.exists) return null;

      return {
        'id': doc.id,
        'draft_title': doc.data()?['draft_title'],
        'draft_data': doc.data()?['draft_data'],
        'created_at': doc.data()?['created_at'],
        'updated_at': doc.data()?['updated_at'],
      };
    } catch (e) {
      print('Error getting product draft: $e');
      return null;
    }
  }

  // Delete product draft
  Future<bool> deleteProductDraft(String draftId) async {
    try {
      await _firestore
          .collection('seller_product_drafts')
          .doc(draftId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting product draft: $e');
      return false;
    }
  }

  // Update seller stats
  Future<void> updateSellerStats(String sellerId) async {
    try {
      // Count products
      final productsSnapshot = await _firestore
          .collection('master_products')
          .where('seller_id', isEqualTo: sellerId)
          .get();

      final totalProducts = productsSnapshot.docs.length;
      final activeProducts = productsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'active')
          .length;

      await _firestore.collection('sellers').doc(sellerId).update({
        'total_products': totalProducts,
        'active_products': activeProducts,
      });
    } catch (e) {
      print('Error updating seller stats: $e');
    }
  }

  // Get seller inventory (Active products in master_products)
  Stream<List<Map<String, dynamic>>> getSellerInventory(String sellerId) {
    return _firestore
        .collection('master_products')
        .where('seller_id', isEqualTo: sellerId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  // Update product stock
  Future<bool> updateProductStock(String productId, double newQuantity) async {
    try {
      await _firestore.collection('master_products').doc(productId).update({
        'stock_quantity': newQuantity,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating product stock: $e');
      return false;
    }
  }

  /// Update minimum stock level for a product
  Future<void> updateProductMinStock(String productId, int minStockLevel) async {
    try {
      await _firestore
          .collection('master_products')
          .doc(productId)
          .update({'min_stock_level': minStockLevel});
    } catch (e) {
      print('Error updating minimum stock: $e');
      rethrow;
    }
  }

  // Get nearby warehouses (by city)
  Stream<List<WarehouseModel>> getNearbyWarehouses(String city) {
    // Normalizing city name for better matching (simple lowercase check)
    String normalizedCity = city.toLowerCase().trim();
    
    // Note: In a real app, you might use Geohashes or more complex queries.
    // For now, we filter client-side or use exact match if stored normalized.
    // Let's rely on basic equality for MVP.
    
    return _firestore
        .collection('warehouses')
        // .where('city', isEqualTo: city) // Case-sensitive in Firestore
        .snapshots()
        .map((snapshot) {
           return snapshot.docs
              .map((doc) => WarehouseModel.fromMap(doc.data(), doc.id))
              .where((w) => w.city.toLowerCase().trim() == normalizedCity && w.active)
              .toList();
        });
  }

  // Get ALL warehouses (for search/directory)
  Stream<List<WarehouseModel>> getAllWarehouses() {
    return _firestore
        .collection('warehouses')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WarehouseModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Seed test warehouses (Temporary for development)
  Future<void> seedTestWarehouses() async {
    final warehouses = [
      {
        'name': 'Dhubri Central Hub',
        'address': 'NS Road, Near Main Market',
        'city': 'Dhubri',
        'state': 'Assam',
        'pincode': '783301',
        'capacity': 5000,
        'active': true,
      },
      {
        'name': 'Golakganj Distribution Center',
        'address': 'Kachakhana Road',
        'city': 'Golakganj',
        'state': 'Assam',
        'pincode': '783334',
        'capacity': 2000,
        'active': true,
      },
      {
        'name': 'Guwahati Main Depot',
        'address': 'GS Road, Khanapara',
        'city': 'Guwahati',
        'state': 'Assam',
        'pincode': '781022',
        'capacity': 10000,
        'active': true,
      },
    ];

    for (var data in warehouses) {
      // Check if exists to avoid duplicates
      final existing = await _firestore
          .collection('warehouses')
          .where('name', isEqualTo: data['name'])
          .get();

      if (existing.docs.isEmpty) {
        await _firestore.collection('warehouses').add(data);
        print('Seeded: ${data['name']}');
      }
    }
  }

  // Create new shipment
  Future<String?> createShipment(ShipmentModel shipment) async {
    try {
      final docRef = await _firestore.collection('shipments').add(shipment.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating shipment: $e');
      return null;
    }
  }

  // Get seller shipments
  Stream<List<ShipmentModel>> getSellerShipments(String sellerId) {
    return _firestore
        .collection('shipments')
        .where('seller_id', isEqualTo: sellerId)
        // .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShipmentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // --- Admin Methods ---

  // Get ALL shipments (for Admin/Warehouse)
  Stream<List<ShipmentModel>> getAllShipments() {
    return _firestore
        .collection('shipments')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShipmentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Mark shipment as received
  Future<void> receiveShipment(String shipmentId) async {
    try {
      await _firestore.collection('shipments').doc(shipmentId).update({
        'status': 'received',
        'received_at': FieldValue.serverTimestamp(),
      });
      
      
      // TODO: Here we should technically update the WAREHOUSE INVENTORY 
      // by adding the items from the shipment to the warehouse stock.
      // For now, we just mark it as received.
      
    } catch (e) {
      print('Error receiving shipment: $e');
      throw e;
    }
  }

  // --- Product Management (with Price & Stock Sync) ---

  // Update product (for Seller/Admin) with cascading updates to Vendor Inventory
  Future<bool> updateProduct(String productId, Map<String, dynamic> updates) async {
    try {
      // 1. Update Master Product
      await _firestore.collection('master_products').doc(productId).update({
        ...updates,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 2. Sync changes to Vendor Inventories
      // Specifically check if Price or MRP changed
      bool priceChanged = updates.containsKey('price') || updates.containsKey('selling_price') || updates.containsKey('mrp');
      
      if (priceChanged) {
        await _syncPriceToVendorInventory(productId, updates);
      }
      
      return true;
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  // Helper to sync price changes to all vendors carrying the product
  Future<void> _syncPriceToVendorInventory(String productId, Map<String, dynamic> masterUpdates) async {
     try {
       // Find all vendor inventory items for this product
       final inventorySnapshot = await _firestore
           .collection('vendor_inventory')
           .where('productId', isEqualTo: productId)
           .get();

       if (inventorySnapshot.docs.isEmpty) return;

       // Prepare batch update
       final batch = _firestore.batch();
       
       double? newSellingPrice = masterUpdates['selling_price'] ?? masterUpdates['price']; // Handle both key names
       double? newMrp = masterUpdates['mrp'];

       for (var doc in inventorySnapshot.docs) {
           Map<String, dynamic> inventoryUpdate = {};
           
           if (newSellingPrice != null) {
               // Only update if no specific override lock exists (if you implement locking later)
               // For now, we assume Master Price update overrides old vendor price unless it's a "special" override.
               // Ensuring we use 'price' as the key for vendor_inventory as per schema convention
               inventoryUpdate['price'] = newSellingPrice; 
           }
           
           if (newMrp != null) {
               inventoryUpdate['mrp'] = newMrp; // Assuming 'mrp' exists in vendor_inventory
           }
           
           if (inventoryUpdate.isNotEmpty) {
               batch.update(doc.reference, inventoryUpdate);
           }
       }

       await batch.commit();
       print("Synced price for ${inventorySnapshot.docs.length} vendor inventory items.");

     } catch (e) {
       print("Error syncing price to vendor inventory: $e");
       // Don't fail the whole operation if sync fails, but log it.
     }
  }
}
