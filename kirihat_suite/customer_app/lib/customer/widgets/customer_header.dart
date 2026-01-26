import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/phone_auth_screen.dart';
import 'cart_badge.dart';

class CustomerHeader extends StatelessWidget {
  final String selectedArea;
  final VoidCallback onLocationTap;
  final VoidCallback onCartTap;

  const CustomerHeader({
    super.key,
    required this.selectedArea,
    required this.onLocationTap,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // App Icon/Logo Placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0D9759),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Location
          Expanded(
            child: GestureDetector(
              onTap: onLocationTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible( // Prevent overflow if area name is long
                        child: Text(
                          selectedArea,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                    ],
                  ),
                  const Text(
                    'Delivery in 20 minutes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Login Button (for guests only)
          _buildLoginButton(context),
          
          // Cart Icon with Badge - Using reusable widget
          CartBadge(onTap: onCartTap),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9759),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Login',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return const SizedBox.shrink(); // Return an empty widget if user is logged in
  }
}
