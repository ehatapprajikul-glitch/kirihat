import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHeader extends StatelessWidget {
  final String currentPage;
  final Function(String)? onNavigate;

  const AdminHeader({
    super.key,
    required this.currentPage,
    this.onNavigate,
  });

  String _getPageTitle() {
    switch (currentPage) {
      case 'dashboard':
        return 'Dashboard';
      case 'users':
        return 'User Management';
      case 'layout_designer':
        return 'Home Layout Designer';
      case 'coupons':
        return 'Discount Coupons';
      case 'commission':
        return 'Commission Settings';
      case 'notifications':
        return 'Push Notifications';
      case 'customer_monitor':
        return 'Customer Monitor';
      case 'vendor_monitor':
        return 'Vendor Monitor';
      case 'rider_monitor':
        return 'Rider Monitor';
      case 'data_monitoring':
        return 'Data Access & Monitoring';
      case 'analytics':
        return 'Analytics & Reports';
      case 'support':
        return 'Customer Support';
      case 'settings':
        return 'Platform Settings';
      default:
        return 'Admin Panel';
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Page Title
          Text(
            _getPageTitle(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),

          const Spacer(),

          // Notifications Icon with Real-Time Badge
          StreamBuilder<int>(
            stream: _getNotificationCountStream(),
            builder: (context, snapshot) {
              int notificationCount = snapshot.data ?? 0;

              return IconButton(
                onPressed: () => _showNotificationsPanel(context),
                icon: notificationCount > 0
                    ? Badge(
                        label: Text(notificationCount > 9 ? '9+' : '$notificationCount'),
                        child: const Icon(Icons.notifications_outlined),
                      )
                    : const Icon(Icons.notifications_outlined),
              );
            },
          ),

          const SizedBox(width: 16),

          // Admin Profile
          PopupMenuButton(
            offset: const Offset(0, 50),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0D9759),
                  child: Text(
                    (user?.email?[0] ?? 'A').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
            itemBuilder: (context) => <PopupMenuEntry>[
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/');
                }
              } else if (value == 'settings' && onNavigate != null) {
                onNavigate!('settings');
              }
            },
          ),
        ],
      ),
    );
  }

  Stream<int> _getNotificationCountStream() {
    // Combine multiple streams to get total count
    return FirebaseFirestore.instance
        .collection('callback_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((callbacksSnapshot) async {
      int count = callbacksSnapshot.docs.length;

      // Add concerns count
      var concernsSnapshot = await FirebaseFirestore.instance
          .collection('customer_concerns')
          .where('status', isEqualTo: 'pending')
          .get();
      count += concernsSnapshot.docs.length;

      // Add low stock count
      var productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('stock_quantity', isLessThan: 5)
          .get();
      count += productsSnapshot.docs.length;

      return count;
    });
  }

  void _showNotificationsPanel(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D9759),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      'Admin Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Notifications List
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getAllNotifications(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No notifications', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        var notification = snapshot.data![index];
                        return _buildNotificationItem(
                          context,
                          notification['icon'] as IconData,
                          notification['color'] as Color,
                          notification['title'] as String,
                          notification['subtitle'] as String,
                          notification['action'] as VoidCallback,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAllNotifications() async {
    List<Map<String, dynamic>> notifications = [];

    // Pending Callbacks
    var callbacksSnapshot = await FirebaseFirestore.instance
        .collection('callback_requests')
        .where('status', isEqualTo: 'pending')
        .get();

    if (callbacksSnapshot.docs.isNotEmpty) {
      notifications.add({
        'icon': Icons.phone_callback,
        'color': Colors.red,
        'title': '${callbacksSnapshot.docs.length} Pending Callback${callbacksSnapshot.docs.length > 1 ? 's' : ''}',
        'subtitle': 'Customers waiting for your call',
        'action': () {
          if (onNavigate != null) onNavigate!('support');
        },
      });
    }

    // Pending Concerns
    var concernsSnapshot = await FirebaseFirestore.instance
        .collection('customer_concerns')
        .where('status', isEqualTo: 'pending')
        .get();

    if (concernsSnapshot.docs.isNotEmpty) {
      notifications.add({
        'icon': Icons.feedback,
        'color': Colors.orange,
        'title': '${concernsSnapshot.docs.length} Customer Concern${concernsSnapshot.docs.length > 1 ? 's' : ''}',
        'subtitle': 'Unresolved complaints/feedback',
        'action': () {
          if (onNavigate != null) onNavigate!('support');
        },
      });
    }

    // Low Stock Items
    var productsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('stock_quantity', isLessThan: 5)
        .get();

    if (productsSnapshot.docs.isNotEmpty) {
      notifications.add({
        'icon': Icons.inventory_2,
        'color': Colors.amber,
        'title': '${productsSnapshot.docs.length} Low Stock Item${productsSnapshot.docs.length > 1 ? 's' : ''}',
        'subtitle': 'Products running out of stock',
        'action': () {
          if (onNavigate != null) onNavigate!('data_monitoring');
        },
      });
    }

    return notifications;
  }
}
