import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:kirihat_core/services/notification_service.dart';
import 'order/vendor_orders.dart';

class VendorNotificationsScreen extends StatelessWidget {
  const VendorNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () => NotificationService.markAllAsRead(user.uid),
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      "Something went wrong",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.error.toString().contains('index'))
                      const Text(
                        "Looks like a missing index! Copy the link above to create it.",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No notifications yet',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isRead = data['isRead'] ?? false;
              String type = data['type'] ?? 'info';
              Timestamp? ts = data['timestamp'];

              return Card(
                elevation: isRead ? 0 : 2,
                color: isRead ? Colors.white : Colors.blue.shade50,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _getIconColor(type).withOpacity(0.1),
                    child: Icon(_getIcon(type), color: _getIconColor(type)),
                  ),
                  title: Text(
                    data['title'] ?? 'Notification',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(data['message'] ?? '', style: TextStyle(color: Colors.grey[800])),
                      const SizedBox(height: 8),
                      Text(
                        ts != null ? DateFormat('MMM d, h:mm a').format(ts.toDate()) : 'Just now',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!isRead) NotificationService.markAsRead(doc.id);
                    await SystemSound.play(SystemSoundType.click);

                    if (data['orderId'] != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => VendorOrdersScreen(
                                  initialOrderId: data['orderId'])));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'order_new': return Colors.green;
      case 'order_cancelled': return Colors.red;
      case 'rider_cancelled': return Colors.orange;
      case 'order_delivered': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'order_new': return Icons.shopping_bag;
      case 'order_cancelled': return Icons.cancel;
      case 'rider_cancelled': return Icons.no_transfer;
      case 'order_delivered': return Icons.local_shipping;
      default: return Icons.notifications;
    }
  }
}
