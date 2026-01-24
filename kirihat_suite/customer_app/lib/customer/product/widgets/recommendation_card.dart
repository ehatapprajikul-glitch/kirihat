import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

/// Enhanced product recommendation card with discount badge and add button
class RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final bool showDiscountBadge;
  final bool showAddButton;

  const RecommendationCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showDiscountBadge = true,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? 'Product';
    final price = product['price'] ?? 0;
    final mrp = product['mrp'] ?? price;
    final hasDiscount = mrp > price;
    final discountPercent = hasDiscount 
        ? (((mrp - price) / mrp) * 100).toStringAsFixed(0) 
        : '0';
    
    final imageUrl = product['imageUrl'] ?? 
        (product['images'] != null && (product['images'] as List).isNotEmpty
            ? product['images'][0]
            : '');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with optional discount badge
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.image, color: Colors.grey, size: 40),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.image, color: Colors.grey, size: 40),
                        ),
                ),
                // Discount Badge
                if (hasDiscount && showDiscountBadge)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), // Colors.green[50]
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$discountPercent% OFF',
                        style: const TextStyle(
                          color: Color(0xFF0D9759),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Price Section
                    Row(
                      children: [
                        Text(
                          CurrencyHelper.format(price),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D9759),
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            CurrencyHelper.format(mrp),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Add Button
            if (showAddButton)
              Padding(
                padding: const EdgeInsets.all(8),
                child: StreamBuilder<int>(
                  stream: CartHelper.watchCartItemQuantity(product['id']),
                  builder: (context, snapshot) {
                    final quantity = snapshot.data ?? 0;

                    if (quantity > 0) {
                      // Show quantity controls
                      return Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9759),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            InkWell(
                              onTap: () {
                                CartHelper.updateCartItemQuantity(
                                  context,
                                  product['id'],
                                  quantity - 1,
                                );
                              },
                              child: const Icon(Icons.remove, color: Colors.white, size: 16),
                            ),
                            Text(
                              '$quantity',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                CartHelper.updateCartItemQuantity(
                                  context,
                                  product['id'],
                                  quantity + 1,
                                );
                              },
                              child: const Icon(Icons.add, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    // Show Add button
                    return SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () async {
                          await CartHelper.addToCart(context, product);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF7FFF9), // Very light green/white bg
                          foregroundColor: const Color(0xFF0D9759), // Green text
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: Color(0xFF0D9759), width: 1), // Green border
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'ADD',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800, // Extra bold
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
