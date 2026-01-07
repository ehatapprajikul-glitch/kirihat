import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/warehouse_model.dart';

class WarehouseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==================== WAREHOUSE MANAGEMENT ====================
  
  Future<List<WarehouseStockModel>> getWarehouseInventory() async {
    try {
      final snapshot = await _db
          .collection('warehouse_inventory')
          .orderBy('product_name')
          .get();

      return snapshot.docs
          .map((doc) => WarehouseStockModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching warehouse inventory: $e');
      return [];
    }
  }

  Stream<List<WarehouseStockModel>> streamWarehouseInventory() {
    return _db
        .collection('warehouse_inventory')
        .orderBy('product_name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WarehouseStockModel.fromMap(doc.data()))
            .toList());
  }

  Future<WarehouseStockModel?> getProductStock(String productId) async {
    try {
      final doc = await _db
          .collection('warehouse_inventory')
          .doc(productId)
          .get();

      if (doc.exists) {
        return WarehouseStockModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error fetching product stock: $e');
      return null;
    }
  }

  // ==================== RECEIVING SHIPMENTS ====================
  
  Future<bool> receiveShipment({
    required String shipmentId,
    required String productId,
    required String productName,
    required int quantity,
    required String adminId,
  }) async {
    try {
      final batch = _db.batch();

      // 1. Update shipment status
      final shipmentRef = _db.collection('shipments').doc(shipmentId);
      batch.update(shipmentRef, {
        'status': 'completed',
        'received_at': FieldValue.serverTimestamp(),
        'received_by': adminId,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 2. Update warehouse inventory
      final inventoryRef = _db.collection('warehouse_inventory').doc(productId);
      final inventoryDoc = await inventoryRef.get();

      if (inventoryDoc.exists) {
        // Increment existing stock
        batch.update(inventoryRef, {
          'quantity': FieldValue.increment(quantity),
          'last_updated': FieldValue.serverTimestamp(),
          'last_shipment_id': shipmentId,
        });
      } else {
        // Create new inventory record
        batch.set(inventoryRef, {
          'product_id': productId,
          'product_name': productName,
          'quantity': quantity,
          'min_stock_level': 10,
          'max_stock_level': 1000,
          'last_updated': FieldValue.serverTimestamp(),
          'last_shipment_id': shipmentId,
        });
      }

      // 3. Update product status to 'in_warehouse'
      final productRef = _db.collection('master_products').doc(productId);
      batch.update(productRef, {
        'status': 'in_warehouse',
        'warehouse_stock': FieldValue.increment(quantity),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error receiving shipment: $e');
      return false;
    }
  }

  // ==================== VENDOR STOCK REQUESTS ====================
  
  Future<List<VendorStockRequest>> getVendorRequests({String? status}) async {
    try {
      Query query = _db.collection('vendor_stock_requests');
      
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      
      final snapshot = await query.orderBy('created_at', descending: true).get();

      return snapshot.docs
          .map((doc) => VendorStockRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error fetching vendor requests: $e');
      return [];
    }
  }

  Stream<List<VendorStockRequest>> streamVendorRequests({String? status}) {
    Query query = _db.collection('vendor_stock_requests');
    
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    return query
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorStockRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<bool> approveVendorRequest({
    required String requestId,
    required int approvedQuantity,
    required String adminId,
  }) async {
    try {
      await _db.collection('vendor_stock_requests').doc(requestId).update({
        'status': 'approved',
        'approved_quantity': approvedQuantity,
        'approved_by': adminId,
        'approved_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error approving request: $e');
      return false;
    }
  }

  Future<bool> rejectVendorRequest({
    required String requestId,
    required String reason,
    required String adminId,
  }) async {
    try {
      await _db.collection('vendor_stock_requests').doc(requestId).update({
        'status': 'rejected',
        'rejection_reason': reason,
        'approved_by': adminId,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error rejecting request: $e');
      return false;
    }
  }

  // ==================== DISTRIBUTION TO VENDORS ====================
  
  Future<bool> distributeToVendor({
    required String requestId,
    required String vendorId,
    required String productId,
    required int quantity,
    required String adminId,
  }) async {
    try {
      final batch = _db.batch();

      // 1. Update stock request
      final requestRef = _db.collection('vendor_stock_requests').doc(requestId);
      batch.update(requestRef, {
        'status': 'shipped',
        'shipped_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 2. Deduct from warehouse
      final inventoryRef = _db.collection('warehouse_inventory').doc(productId);
      batch.update(inventoryRef, {
        'quantity': FieldValue.increment(-quantity),
        'last_updated': FieldValue.serverTimestamp(),
      });

      // 3. Update product warehouse_stock
      final productRef = _db.collection('master_products').doc(productId);
      batch.update(productRef, {
        'warehouse_stock': FieldValue.increment(-quantity),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 4. Create transfer record
      final transferRef = _db.collection('warehouse_transfers').doc();
      batch.set(transferRef, {
        'request_id': requestId,
        'vendor_id': vendorId,
        'product_id': productId,
        'quantity': quantity,
        'status': 'shipped',
        'shipped_at': FieldValue.serverTimestamp(),
        'shipped_by': adminId,
        'created_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error distributing to vendor: $e');
      return false;
    }
  }

  // ==================== VENDOR RECEIVES STOCK ====================
  
  Future<bool> vendorReceiveStock({
    required String requestId,
    required String vendorId,
    required String productId,
    required int quantity,
  }) async {
    try {
      final batch = _db.batch();

      // 1. Update stock request
      final requestRef = _db.collection('vendor_stock_requests').doc(requestId);
      batch.update(requestRef, {
        'status': 'received',
        'received_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 2. Update vendor inventory
      final vendorInventoryRef = _db
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('product_id', isEqualTo: productId)
          .limit(1);

      final vendorInventoryDocs = await vendorInventoryRef.get();

      if (vendorInventoryDocs.docs.isNotEmpty) {
        // Update existing
        batch.update(vendorInventoryDocs.docs.first.reference, {
          'stock_quantity': FieldValue.increment(quantity),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new
        final newVendorInventoryRef = _db.collection('vendor_inventory').doc();
        batch.set(newVendorInventoryRef, {
          'vendor_id': vendorId,
          'product_id': productId,
          'stock_quantity': quantity,
          'isAvailable': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // 3. Update product status to 'live' if this is first vendor stock
      final productRef = _db.collection('master_products').doc(productId);
      batch.update(productRef, {
        'status': 'live',
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error vendor receiving stock: $e');
      return false;
    }
  }

  // ==================== ANALYTICS & MONITORING ====================
  
  Future<Map<String, dynamic>> getWarehouseStats() async {
    try {
      final inventorySnapshot = await _db.collection('warehouse_inventory').get();
      
      int totalProducts = inventorySnapshot.docs.length;
      int totalQuantity = 0;
      int lowStockCount = 0;
      
      for (var doc in inventorySnapshot.docs) {
        final stock = WarehouseStockModel.fromMap(doc.data());
        totalQuantity += stock.quantity;
        if (stock.isLowStock) lowStockCount++;
      }

      final pendingRequests = await _db
          .collection('vendor_stock_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      return {
        'total_products': totalProducts,
        'total_quantity': totalQuantity,
        'low_stock_count': lowStockCount,
        'pending_requests': pendingRequests.docs.length,
      };
    } catch (e) {
      print('Error getting warehouse stats: $e');
      return {
        'total_products': 0,
        'total_quantity': 0,
        'low_stock_count': 0,
        'pending_requests': 0,
      };
    }
  }
}
