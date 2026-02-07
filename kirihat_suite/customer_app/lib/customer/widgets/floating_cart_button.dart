import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../cart_screen.dart';
import 'package:kirihat_core/utils/cart_helper.dart';

class FloatingCartButton extends StatelessWidget {
  const FloatingCartButton({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    
    // Guest mode - use ValueListenableBuilder for real-time updates
    if (user == null) {
      // Ensure notifier is initialized
      CartHelper.init();
      
      return ValueListenableBuilder<int>(
        valueListenable: CartHelper.cartCountNotifier,
        builder: (context, totalItems, child) {
          // Hide if no items
          if (totalItems == 0) {
            return const SizedBox.shrink();
          }

          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0FBB6C),
                  Color(0xFF0D9759),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9759).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
            label: Row(
              children: [
                const Text(
                  'Cart',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalItems',
                    style: const TextStyle(
                      color: Color(0xFF0D9759),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            ),
          );
        },
      );
    }

    // Logged-in mode - use StreamBuilder
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        // Calculate total item count
        int totalItems = 0;
        for (var doc in snapshot.data!.docs) {
          totalItems += (doc.data() as Map<String, dynamic>)['quantity'] as int? ?? 1;
        }

        // Hide if no items
        if (totalItems == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0FBB6C),
                Color(0xFF0D9759),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9759).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            heroTag: null, // Disable hero tag to prevent "multiple heroes" error
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
          label: Row(
            children: [
              const Text(
                'Cart',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalItems',
                  style: const TextStyle(
                    color: Color(0xFF0D9759),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}
