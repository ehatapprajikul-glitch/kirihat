import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'vendor_notifications_screen.dart';

class VendorHeader extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavigate;

  const VendorHeader({super.key, required this.currentPage, required this.onNavigate});

  String _getPageTitle() {
    switch (currentPage) {
      case 'home': return 'Dashboard';
      case 'catalog_selection': return 'Catalog Selection';
      case 'products': return 'Product Catalog';
      case 'orders': return 'Order Management';
      case 'earnings': return 'Earnings & Payouts';
      case 'analytics': return 'Sales Analytics';
      case 'riders': return 'Rider Management';
      case 'profile': return 'Vendor Profile';
      default: return 'Vendor Panel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Page Title
          Text(
            _getPageTitle(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          
          const Spacer(),
          
          // Right Side Actions
          // Right Side Actions
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('recipientId', isEqualTo: user?.uid)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VendorNotificationsScreen()),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined, color: Colors.grey),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 16),
          
          // User Profile
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepOrange.shade50,
                child: Text(
                  (user?.displayName ?? 'V')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'Vendor',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
