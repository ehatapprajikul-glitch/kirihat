import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sends a notification to a specific vendor
  static Future<void> sendNotification({
    required String vendorId,
    required String title,
    required String message,
    required String type, // 'order_new', 'order_cancelled', 'order_delivered', 'rider_cancelled'
    required String orderId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'recipientId': vendorId,
        'title': title,
        'message': message,
        'type': type,
        'orderId': orderId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  /// Mark a specific notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications for a vendor as read
  static Future<void> markAllAsRead(String vendorId) async {
    try {
      var batch = _firestore.batch();
      var snapshots = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: vendorId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshots.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }
  /// Send notification to Customer (Sub-collection)
  static Future<void> sendCustomerNotification({
    required String customerId,
    required String title,
    required String body,
    required String type,
    required String orderId,
    String? imageUrl,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(customerId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'order_id': orderId,
        'image': imageUrl,
        'is_read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("✅ Notification sent to customer: $customerId");
    } catch (e) {
      print('Error sending customer notification: $e');
    }
  }
}
