import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get vendor orders stream
  Stream<QuerySnapshot> getVendorOrdersStream(String vendorId) {
    return _firestore
        .collection('orders')
        .where('vendor_id', isEqualTo: vendorId)
        .snapshots();
  }

  // Assign rider to order
  Future<void> assignRiderToOrder({
    required String orderId,
    required String riderId,
    String? riderName,
    String? riderPhone,
  }) async {
    // Generate 4-digit PIN
    final String deliveryPin = (1000 + Random().nextInt(9000)).toString();

    // Run transaction
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);
      
      if (!orderDoc.exists) {
        throw Exception('Order does not exist!');
      }

      // Check if already assigned or cancelled
      final status = orderDoc.get('status');
      if (status == 'Cancelled' || status == 'Delivered') {
        throw Exception('Cannot assign rider to $status order');
      }

      // Update order
      transaction.update(orderRef, {
        'status': 'Shipped',
        'rider_id': riderId,
        'rider_name': riderName,
        'rider_phone': riderPhone,
        'delivery_pin': deliveryPin,
        'shipped_at': FieldValue.serverTimestamp(),
      });
    });
  }

  // Bulk Assign rider to multiple orders
  Future<void> bulkAssignRiderToOrders({
    required List<String> orderIds,
    required String riderId,
    String? riderName,
    String? riderPhone,
  }) async {
    if (orderIds.isEmpty) return;
    if (orderIds.length > 10) throw Exception('Maximum 10 orders per assignment');

    final WriteBatch batch = _firestore.batch();

    for (String orderId in orderIds) {
      final String deliveryPin = (1000 + Random().nextInt(9000)).toString();
      final orderRef = _firestore.collection('orders').doc(orderId);
      
      batch.update(orderRef, {
        'status': 'Shipped',
        'rider_id': riderId,
        'rider_name': riderName,
        'rider_phone': riderPhone,
        'delivery_pin': deliveryPin,
        'shipped_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Bulk Accept orders
  Future<void> bulkAcceptOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return;
    final WriteBatch batch = _firestore.batch();
    for (String id in orderIds) {
      batch.update(_firestore.collection('orders').doc(id), {
        'status': 'Processing',
        'accepted_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Bulk Mark as Packed
  Future<void> bulkMarkAsPacked(List<String> orderIds) async {
    if (orderIds.isEmpty) return;
    final WriteBatch batch = _firestore.batch();
    for (String id in orderIds) {
      batch.update(_firestore.collection('orders').doc(id), {
        'status': 'Packed',
        'packed_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Bulk Cancel orders
  Future<void> bulkCancelOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return;
    final WriteBatch batch = _firestore.batch();
    for (String id in orderIds) {
      batch.update(_firestore.collection('orders').doc(id), {
        'status': 'Cancelled',
        'cancellation_reason': 'Bulk cancelled by vendor',
        'cancelled_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Cancel order
  Future<void> cancelOrder(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'Cancelled',
      'cancellation_reason': 'Cancelled by vendor',
      'cancelled_at': FieldValue.serverTimestamp(),
    });
  }
  
  // Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
      if (status == 'Processing') 'accepted_at': FieldValue.serverTimestamp(),
      if (status == 'Packed') 'packed_at': FieldValue.serverTimestamp(),
      if (status == 'Shipped') 'shipped_at': FieldValue.serverTimestamp(),
      if (status == 'Out for Delivery') 'out_for_delivery_at': FieldValue.serverTimestamp(),
      if (status == 'Delivered') 'delivered_at': FieldValue.serverTimestamp(),
      if (status == 'Cancelled') 'cancelled_at': FieldValue.serverTimestamp(),
    });
  }


  // Mark as processing
  Future<void> markAsProcessing(String orderId) async {
    await updateOrderStatus(orderId, 'Processing');
  }

  // Mark as packed
  Future<void> markAsPacked(String orderId) async {
    await updateOrderStatus(orderId, 'Packed');
  }

  // Get order statistics
  Future<OrderStatistics> getOrderStatistics(String vendorId) async {
    final QuerySnapshot snapshot = await _firestore
        .collection('orders')
        .where('vendor_id', isEqualTo: vendorId)
        .get();

    int totalOrders = snapshot.docs.length;
    int pending = 0;
    int processing = 0;
    int shipped = 0;
    int delivered = 0;
    int cancelled = 0;
    double totalRevenue = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'Pending';
      final amount = (data['total_amount'] as num?)?.toDouble() ?? 0.0;

      switch (status) {
        case 'Pending':
          pending++;
          break;
        case 'Processing':
          processing++;
          break;
        case 'Shipped':
          shipped++;
          break;
        case 'Delivered':
        case 'Completed':
          delivered++;
          totalRevenue += amount;
          break;
        case 'Cancelled':
          cancelled++;
          break;
      }
    }

    return OrderStatistics(
      totalOrders: totalOrders,
      pending: pending,
      processing: processing,
      shipped: shipped,
      delivered: delivered,
      cancelled: cancelled,
      totalRevenue: totalRevenue,
    );
  }

  // Validate Delivery PIN
  Future<bool> validateDeliveryPin(String orderId, String pin) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (!doc.exists) return false;
    
    final correctPin = doc.get('delivery_pin') as String?;
    return correctPin == pin;
  }
}

class OrderStatistics {
  final int totalOrders;
  final int pending;
  final int processing;
  final int shipped;
  final int delivered;
  final int cancelled;
  final double totalRevenue;

  OrderStatistics({
    required this.totalOrders,
    required this.pending,
    required this.processing,
    required this.shipped,
    required this.delivered,
    required this.cancelled,
    required this.totalRevenue,
  });
}
