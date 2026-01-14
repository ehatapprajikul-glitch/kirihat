import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/utils/cart_helper.dart';

/// Reusable cart badge widget that shows cart item count
/// Handles both guest and logged-in user states
class CartBadge extends StatelessWidget {
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? badgeColor;

  const CartBadge({
    super.key,
    required this.onTap,
    this.iconColor,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return _buildGuestBadge();
    }
    return _buildLoggedInBadge(user.uid);
  }

  /// Build cart badge for guest users using FutureBuilder
  Widget _buildGuestBadge() {
    return FutureBuilder<int>(
      future: CartHelper.getCartCount(),
      builder: (context, snapshot) {
        return _buildBadgeIcon(snapshot.data ?? 0);
      },
    );
  }

  /// Build cart badge for logged-in users using StreamBuilder
  Widget _buildLoggedInBadge(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            count += (doc.data() as Map<String, dynamic>)['quantity'] as int? ?? 1;
          }
        }
        return _buildBadgeIcon(count);
      },
    );
  }

  /// Build the actual badge icon with count
  Widget _buildBadgeIcon(int count) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            Icons.shopping_cart_outlined,
            color: iconColor,
          ),
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: badgeColor ?? const Color(0xFF0D9759),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
