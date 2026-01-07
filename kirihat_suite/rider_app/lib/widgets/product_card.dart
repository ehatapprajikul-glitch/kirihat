import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/utils/app_colors.dart';
import 'package:kirihat_core/services/wishlist_service.dart';
import 'package:kirihat_core/utils/cart_helper.dart';

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isTogglingWishlist = false;
  final WishlistService _wishlistService = WishlistService();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _toggleWishlist() async {
    if (_userId == null || widget.product['id'] == null) return;

    setState(() {
      _isTogglingWishlist = true;
    });

    try {
      final wasAdded = await _wishlistService.toggleWishlist(
        _userId!,
        widget.product['id'],
        sourceVendorId: widget.product['vendor_id'],
      );
      
      if (mounted) {
        setState(() {
          _isTogglingWishlist = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasAdded ? '❤️ Added to wishlist' : 'Removed from wishlist'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error toggling wishlist: $e');
      if (mounted) {
        setState(() {
          _isTogglingWishlist = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String productId = widget.product['id'] ?? '';
    String name = widget.product['name'] ?? 'Unknown';
    String imageUrl = widget.product['imageUrl'] ?? '';
    double price = (widget.product['price'] ?? 0).toDouble();
    double? mrp = widget.product['mrp'] != null ? (widget.product['mrp'] as num).toDouble() : null;
    int stock = widget.product['stock_quantity'] ?? 0;
    String unit = widget.product['unit'] ?? '';
    bool isAvailableInCurrentVendor = widget.product['isAvailableInCurrentVendor'] ?? true;
    
    // Check both stock AND cross-vendor availability
    bool isOOS = stock <= 0 || !isAvailableInCurrentVendor;

    bool hasDiscount = mrp != null && mrp > price && mrp > 0;
    int discountAmount = hasDiscount ? (mrp - price).round() : 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SECTION (Proportional height: 55%)
            Expanded(
              flex: 55,
              child: Stack(
                fit: StackFit.expand,
                children: [
                   ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      color: Colors.grey[50],
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(color: Colors.white),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                            )
                          : const Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  ),
                  // Discount Badge (Top Left)
                  if (hasDiscount && !isOOS)
                    Positioned(
                      top: 8,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: const BoxDecoration(
                          color: AppColors.discountGreen,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          "₹$discountAmount OFF",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (isOOS)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: const Center(
                          child: Text("Out of Stock",
                              style: TextStyle(
                                  color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  // Wishlist Heart Icon (Top Right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: StreamBuilder<Set<String>>(
                      stream: _userId != null 
                          ? _wishlistService.watchWishlistSet(_userId!) 
                          : Stream.value({}),
                      builder: (context, snapshot) {
                        final wishlistSet = snapshot.data ?? {};
                        final isInWishlist = wishlistSet.contains(productId);

                        return GestureDetector(
                          onTap: _isTogglingWishlist ? null : _toggleWishlist,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isInWishlist ? Colors.pink[50] : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _isTogglingWishlist
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.pink),
                                    ),
                                  )
                                : Icon(
                                    isInWishlist ? Icons.favorite : Icons.favorite_border,
                                    size: 16,
                                    color: isInWishlist ? Colors.pink : Colors.grey,
                                  ),
                          ),
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),

            // INFO SECTION (Proportional height: 45%)
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Product Name & Unit - Use Flexible to prevent overflow
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          if (unit.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                unit,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Small spacing
                    const SizedBox(height: 4),

                    // Price & ADD Button Row
                    StreamBuilder<int>(
                      stream: CartHelper.watchCartItemQuantity(productId),
                      builder: (context, snapshot) {
                        final int cartQuantity = snapshot.data ?? 0;
                        
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Price Badge - Flexible to prevent overflow
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.priceGreen,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "₹${price.toStringAsFixed(0)}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white),
                                    ),
                                  ),
                                  if (hasDiscount)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        "₹${mrp!.toStringAsFixed(0)}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          decoration: TextDecoration.lineThrough,
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Add Button - Fixed width to prevent overflow
                            if (!isOOS)
                              cartQuantity == 0
                                  ? InkWell(
                                      onTap: widget.onAdd,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.primary, width: 1.5),
                                          borderRadius: BorderRadius.circular(6),
                                          color: Colors.white,
                                        ),
                                        child: const Text(
                                          "ADD",
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              CartHelper.updateCartItemQuantity(context, productId, cartQuantity - 1);
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(2),
                                              child: Icon(Icons.remove, size: 14, color: Colors.white),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              "$cartQuantity",
                                              style: const TextStyle(
                                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              if (cartQuantity < stock) {
                                                CartHelper.updateCartItemQuantity(context, productId, cartQuantity + 1);
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Max stock reached"), duration: Duration(milliseconds: 500)),
                                                );
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(2),
                                              child: Icon(Icons.add, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                          ],
                        );
                      }
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
