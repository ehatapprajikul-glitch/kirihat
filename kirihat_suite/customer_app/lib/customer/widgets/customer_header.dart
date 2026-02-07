import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/phone_auth_screen.dart';
import '../wishlist_screen.dart';
import 'cart_badge.dart';
import 'global_search_bar.dart';
import 'product_search_delegate.dart';
import 'voice_search_screen.dart';

class CustomerHeader extends StatelessWidget {
  final String selectedArea;
  final VoidCallback onLocationTap;
  final VoidCallback onCartTap;
  final List<Map<String, dynamic>> products;
  final String? categoryName;

  const CustomerHeader({
    super.key,
    required this.selectedArea,
    required this.onLocationTap,
    required this.onCartTap,
    this.products = const [],
    this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // App Icon/Logo Placeholder with gradient
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0FBB6C),
                        Color(0xFF0D9759),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9759).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 24,
                        );
                      },
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
                                  color: Color(0xFF1A1A1A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF0D9759)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0D9759).withOpacity(0.1),
                                const Color(0xFF0FBB6C).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Delivery in 20 minutes',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0D9759),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Login Button (for guests only)
                _buildLoginButton(context),
                
                // Wishlist Icon
                IconButton(
                  icon: const Icon(Icons.favorite_border, color: Colors.black87),
                  onPressed: () {
                     Navigator.push(
                       context, 
                       MaterialPageRoute(builder: (_) => const WishlistScreen())
                     );
                  },
                ),
                
                // Cart Icon with Badge - Using reusable widget
                CartBadge(onTap: onCartTap),
              ],
            ),
          ),
          
          // Search Bar
          GlobalSearchBar(
            onTap: () {
              showSearch(
                context: context,
                delegate: ProductSearchDelegate(
                  products: products,
                  categoryName: categoryName,
                ),
              );
            },
            onMicTap: () async {
              // Open Voice Search Screen
              final result = await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => 
                      const VoiceSearchScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    const curve = Curves.easeOut;
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                ),
              );

              // If we got text back, search for it
              if (result != null && result is String && result.isNotEmpty && context.mounted) {
                 showSearch(
                    context: context,
                    delegate: ProductSearchDelegate(
                      products: products,
                      categoryName: categoryName,
                      initialQuery: result,
                    ),
                 );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0FBB6C),
                Color(0xFF0D9759),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9759).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
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
        ),
      );
    }
    return const SizedBox.shrink(); // Return an empty widget if user is logged in
  }
}
