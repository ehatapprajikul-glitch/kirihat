import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home_layout_model.dart';

class HomeLayoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get admin global layouts (vendor_id = null)
  Stream<List<LayoutModel>> getAdminLayouts() {
    return _firestore
        .collection('home_layouts')
        .where('vendor_id', isEqualTo: null)
        .where('active', isEqualTo: true)
        .orderBy('position')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LayoutModel.fromFirestore(doc)).toList();
    });
  }

  /// Get merged layouts (admin + vendor override)
  Stream<List<LayoutModel>> getMergedLayouts(String vendorId) {
    return _firestore
        .collection('home_layouts')
        .where('active', isEqualTo: true)
        .orderBy('position')
        .snapshots()
        .map((snapshot) {
      final layouts = snapshot.docs
          .map((doc) => LayoutModel.fromFirestore(doc))
          .where((layout) => 
              layout.vendorId == null || 
              layout.vendorId == vendorId)
          .toList();
      
      layouts.sort((a, b) => a.position.compareTo(b.position));
      return layouts;
    });
  }

  /// Get vendor layouts for a specific vendor
  Stream<List<LayoutModel>> getVendorLayouts(String vendorId) {
    return _firestore
        .collection('home_layouts')
        .where('vendor_id', isEqualTo: vendorId)
        .where('active', isEqualTo: true)
        .orderBy('position')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LayoutModel.fromFirestore(doc)).toList();
    });
  }

  /// Get aggregated products across vendors (or specific vendors)
  Stream<QuerySnapshot> getAggregatedProducts({
    List<String>? vendorIds,
    int limit = 20,
  }) {
    Query query = _firestore.collection('vendor_inventory')
        .where('isAvailable', isEqualTo: true);
    
    if (vendorIds != null && vendorIds.isNotEmpty) {
      query = query.where('vendor_id', whereIn: vendorIds);
    }
    
    return query.limit(limit).snapshots();
  }

  /// Enrich inventory data with master product details
  Future<Map<String, dynamic>> enrichInventoryWithProduct(Map<String, dynamic> inventoryData) async {
      String? productId = inventoryData['product_id'];
      if (productId == null) return inventoryData;
      
      try {
        final doc = await _firestore.collection('master_products').doc(productId).get();
        if (doc.exists) {
          final productData = doc.data()!;
          return {
            ...productData,
            ...inventoryData,
            'id': productId,
            // Prioritize inventory fields
            'price': inventoryData['selling_price'] ?? productData['price'],
            'image_url': productData['image_url'] ?? productData['imageUrl'], 
          };
        }
      } catch (e) {
        print('Error enriching product: $e');
      }
      return inventoryData;
  }
}
