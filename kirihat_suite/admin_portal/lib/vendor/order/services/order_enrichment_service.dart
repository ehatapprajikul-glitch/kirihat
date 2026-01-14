import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../models/order_model.dart';

class OrderEnrichmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Enrich order with vendor and product barcode information
  /// Call this before generating the shipping label
  Future<OrderModel> enrichOrderForShippingLabel(OrderModel order) async {
    try {
      // 1. Fetch vendor information
      final vendorData = await _fetchVendorData(order.vendorId);
      
      // 2. Fetch barcodes for all items
      final enrichedItems = await _enrichItemsWithBarcodes(order.vendorId, order.items);
      
      // 3. Return enriched order
      return order.copyWith(
        items: enrichedItems,
        vendorName: vendorData['name'],
        vendorAddress: vendorData['address'],
        vendorPhone: vendorData['phone'],
        vendorEmail: vendorData['email'],
        priority: (order.deliveryMode == 'Express' || order.deliveryMode == 'Instant') 
            ? 'Instant' 
            : 'Standard',
      );
    } catch (e) {
      debugPrint('Error enriching order: $e');
      return order; // Return original order if enrichment fails
    }
  }

  /// Fetch vendor information from Firestore
  Future<Map<String, String?>> _fetchVendorData(String vendorId) async {
    try {
      if (vendorId.isEmpty) {
         return {
          'name': 'Kiri Hat Vendor',
          'address': null,
          'phone': null,
          'email': null,
        };
      }

      final vendorDoc = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .get();

      if (!vendorDoc.exists) {
        return {
          'name': 'Kiri Hat Vendor',
          'address': null,
          'phone': null,
          'email': null,
        };
      }

      final data = vendorDoc.data()!;
      return {
        'name': data['name'] ?? data['businessName'] ?? 'Kiri Hat Vendor',
        'address': _buildFullAddress(data),
        'phone': data['phone'] ?? data['contactPhone'],
        'email': data['email'] ?? data['contactEmail'],
      };
    } catch (e) {
      debugPrint('Error fetching vendor data: $e');
      return {
        'name': 'Kiri Hat Vendor',
        'address': null,
        'phone': null,
        'email': null,
      };
    }
  }

  /// Build full address from vendor data
  String? _buildFullAddress(Map<String, dynamic> data) {
    final addressParts = <String>[];
    
    if (data['address'] != null) {
      if (data['address'] is String) {
        return data['address'];
      } else if (data['address'] is Map) {
        final addr = data['address'] as Map<String, dynamic>;
        if (addr['street'] != null) addressParts.add(addr['street']);
        if (addr['area'] != null) addressParts.add(addr['area']);
        if (addr['city'] != null) addressParts.add(addr['city']);
        if (addr['state'] != null) addressParts.add(addr['state']);
        if (addr['pincode'] != null) addressParts.add(addr['pincode']);
      }
    }

    if (addressParts.isEmpty) {
      if (data['street'] != null) addressParts.add(data['street']);
      if (data['city'] != null) addressParts.add(data['city']);
      if (data['state'] != null) addressParts.add(data['state']);
      if (data['pincode'] != null) addressParts.add(data['pincode']);
    }

    return addressParts.isEmpty ? null : addressParts.join(', ');
  }

  /// Enrich order items with barcodes from master_products or vendor_inventory
  Future<List<OrderItem>> _enrichItemsWithBarcodes(String vendorId, List<OrderItem> items) async {
    final enrichedItems = <OrderItem>[];

    for (final item in items) {
      try {
        String? barcode;

        // 1. Try master_products first
        if (item.productId.isNotEmpty) {
          barcode = await _fetchBarcodeFromCollection('master_products', item.productId);
        }

        // 2. Fallback to vendor_inventory if not found
        if (barcode == null && item.productId.isNotEmpty && vendorId.isNotEmpty) {
           barcode = await _fetchBarcodeFromVendorInventory(vendorId, item.productId);
        }

        // 3. Last fallback: try by name in master_products
        if (barcode == null) {
          barcode = await _fetchBarcodeByProductName(item.name);
        }

        // Create enriched item
        enrichedItems.add(OrderItem(
          productId: item.productId,
          name: item.name,
          imageUrl: item.imageUrl,
          quantity: item.quantity,
          price: item.price,
          total: item.total,
          unit: item.unit,
          variant: item.variant,
          barcode: barcode ?? item.barcode, // Use fetched or existing barcode
          sku: item.sku,
        ));
      } catch (e) {
        debugPrint('Error enriching item ${item.name}: $e');
        enrichedItems.add(item); // Add original item if enrichment fails
      }
    }

    return enrichedItems;
  }

  /// Generic fetch barcode by ID from any collection
  Future<String?> _fetchBarcodeFromCollection(String collectionPath, String documentId) async {
    try {
      final doc = await _firestore.collection(collectionPath).doc(documentId).get();
      if (doc.exists) {
        return doc.data()?['barcode'];
      }
    } catch (e) {
      debugPrint('Error fetching barcode from $collectionPath: $e');
    }
    return null;
  }

  /// Fetch barcode from vendor_inventory (assuming structure: vendor_inventory/{vendorId}/products/{productId} 
  /// OR top-level vendor_inventory with vendorId and productId fields)
  Future<String?> _fetchBarcodeFromVendorInventory(String vendorId, String productId) async {
    try {
      // Attempt 1: Subcollection pattern vendors/{vendorId}/inventory/{productId}
      final invDoc = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('inventory')
          .doc(productId)
          .get();
      
      if (invDoc.exists) {
        return invDoc.data()?['barcode'];
      }

      // Attempt 2: Top-level collection pattern vendor_inventory with query
      final querySnapshot = await _firestore
          .collection('vendor_inventory')
          .where('vendorId', isEqualTo: vendorId)
          .where('productId', isEqualTo: productId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['barcode'];
      }
    } catch (e) {
      debugPrint('Error fetching barcode from vendor_inventory: $e');
    }
    return null;
  }

  /// Fetch barcode by product name (fallback method)
  Future<String?> _fetchBarcodeByProductName(String productName) async {
    try {
      final querySnapshot = await _firestore
          .collection('master_products')
          .where('name', isEqualTo: productName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['barcode'];
      }
    } catch (e) {
      debugPrint('Error fetching barcode by product name: $e');
    }
    return null;
  }
}
