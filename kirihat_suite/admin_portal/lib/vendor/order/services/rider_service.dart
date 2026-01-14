import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/kirihat_core.dart';

class RiderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all active riders for vendor
  Stream<List<RiderModel>> getActiveRidersStream(String vendorId) {
    return _firestore
        .collection('riders')
        .where('vendor_id', isEqualTo: vendorId)
        .where('status', isEqualTo: 'Active')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RiderModel.fromFirestore(doc))
            .toList());
  }

  // Get available riders (active and online)
  Stream<List<RiderModel>> getAvailableRidersStream(String vendorId) {
    return _firestore
        .collection('riders')
        .where('vendor_id', isEqualTo: vendorId)
        .where('status', isEqualTo: 'Active')
        .where('duty_status', isEqualTo: 'online')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RiderModel.fromFirestore(doc))
            .toList());
  }

  // Get rider by ID
  Future<RiderModel?> getRider(String riderId) async {
    try {
      final doc = await _firestore.collection('riders').doc(riderId).get();
      if (doc.exists) {
        return RiderModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch rider: $e');
    }
  }

  // Update rider status
  Future<void> updateRiderStatus(String riderId, String status) async {
    try {
      await _firestore.collection('riders').doc(riderId).update({
        'status': status,
        'last_active': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update rider status: $e');
    }
  }

  // Update duty status
  Future<void> updateDutyStatus(String riderId, String dutyStatus) async {
    try {
      await _firestore.collection('riders').doc(riderId).update({
        'duty_status': dutyStatus,
        'is_online': dutyStatus == 'online', // Legacy sync
        'last_active': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update duty status: $e');
    }
  }

  // Update rider online status (Legacy)
  Future<void> updateOnlineStatus(String riderId, bool isOnline) async {
    try {
      await _firestore.collection('riders').doc(riderId).update({
        'is_online': isOnline,
        'duty_status': isOnline ? 'online' : 'offline',
        'last_active': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update online status: $e');
    }
  }

  // Get rider statistics
  Future<RiderStatistics> getRiderStatistics(String riderId) async {
    try {
      // Get completed deliveries
      final deliveriesSnapshot = await _firestore
          .collection('orders')
          .where('rider_id', isEqualTo: riderId)
          .where('status', isEqualTo: 'Delivered')
          .get();

      final totalDeliveries = deliveriesSnapshot.docs.length;
      
      // Calculate today's deliveries
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      int todayDeliveries = 0;
      double totalEarnings = 0;
      
      for (var doc in deliveriesSnapshot.docs) {
        final data = doc.data();
        final deliveredAt = (data['delivered_at'] as Timestamp?)?.toDate();
        
        if (deliveredAt != null && deliveredAt.isAfter(todayStart)) {
          todayDeliveries++;
        }
        
        // Assuming delivery fee is stored in order
        totalEarnings += (data['delivery_fee'] ?? 0).toDouble();
      }

      return RiderStatistics(
        totalDeliveries: totalDeliveries,
        todayDeliveries: todayDeliveries,
        totalEarnings: totalEarnings,
      );
    } catch (e) {
      throw Exception('Failed to get rider statistics: $e');
    }
  }

  // Increment delivery count
  Future<void> incrementDeliveryCount(String riderId) async {
    try {
      await _firestore.collection('riders').doc(riderId).update({
        'total_deliveries': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to increment delivery count: $e');
    }
  }

  // Create new rider
  Future<String> createRider(RiderModel rider) async {
    try {
      final docRef = await _firestore.collection('riders').add(rider.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create rider: $e');
    }
  }

  // Update rider information
  Future<void> updateRider(String riderId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('riders').doc(riderId).update(data);
    } catch (e) {
      throw Exception('Failed to update rider: $e');
    }
  }

  // Delete rider
  Future<void> deleteRider(String riderId) async {
    try {
      await _firestore.collection('riders').doc(riderId).delete();
    } catch (e) {
      throw Exception('Failed to delete rider: $e');
    }
  }

  // Get all riders for vendor (including inactive)
  Stream<List<RiderModel>> getAllRidersStream(String vendorId) {
    return _firestore
        .collection('riders')
        .where('vendor_id', isEqualTo: vendorId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RiderModel.fromFirestore(doc))
            .toList());
  }

  // Search riders by name or phone
  Future<List<RiderModel>> searchRiders(String vendorId, String query) async {
    try {
      final snapshot = await _firestore
          .collection('riders')
          .where('vendor_id', isEqualTo: vendorId)
          .get();

      final allRiders = snapshot.docs
          .map((doc) => RiderModel.fromFirestore(doc))
          .toList();

      // Filter by name or phone
      final searchQuery = query.toLowerCase();
      return allRiders.where((rider) {
        return rider.name.toLowerCase().contains(searchQuery) ||
            rider.phone.contains(searchQuery);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search riders: $e');
    }
  }
}

class RiderStatistics {
  final int totalDeliveries;
  final int todayDeliveries;
  final double totalEarnings;

  RiderStatistics({
    required this.totalDeliveries,
    required this.todayDeliveries,
    required this.totalEarnings,
  });
}
