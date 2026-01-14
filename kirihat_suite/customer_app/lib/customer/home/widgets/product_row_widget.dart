import 'package:flutter/material.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import 'package:kirihat_core/services/product_service.dart';
import '../../../widgets/product_card.dart';
import '../../product/enhanced_product_detail.dart';
import '../../widgets/shimmer_loading.dart';

/// Horizontal scrolling product row widget
class ProductRowWidget extends StatelessWidget {
  final LayoutModel layout;
  final String vendorId;

  const ProductRowWidget({
    super.key,
    required this.layout,
    required this.vendorId,
  });

  @override
  Widget build(BuildContext context) {
    final filter = layout.data['filter'] as String? ?? 'trending';
    final limit = layout.data['limit'] as int? ?? 10;
    final showViewAll = layout.data['show_view_all'] as bool? ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and "View All"
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                layout.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (showViewAll)
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to full list screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('View all ${layout.title}')),
                    );
                  },
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        
        // Horizontal product list
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _getProducts(filter, vendorId, limit),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingSkeleton();
            }

            if (snapshot.hasError) {
              return _buildErrorState();
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return _buildEmptyState();
            }

            return SizedBox(
              height: 280,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 150,
                    margin: EdgeInsets.only(
                      right: index < products.length - 1 ? 12 : 0,
                    ),
                    child: ProductCard(
                      product: products[index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EnhancedProductDetailScreen(
                              productId: products[index]['id'],
                              productData: products[index],
                            ),
                          ),
                        );
                      },
                      onAdd: () {
                        // Add to cart functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Added to cart')),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _getProducts(
    String filter,
    String vendorId,
    int limit,
  ) async {
    final productService = ProductService();
    
    try {
      switch (filter) {
        case 'trending':
          return await productService.getTrendingProducts(
            vendorId: vendorId,
            limit: limit,
          );
        case 'new':
          return await productService.getNewArrivals(
            vendorId: vendorId,
            limit: limit,
          );
        case 'deals':
          return await productService.getDeals(
            vendorId: vendorId,
            limit: limit,
          );
        default:
          return await productService.getTrendingProducts(
            vendorId: vendorId,
            limit: limit,
          );
      }
    } catch (e) {
      print('❌ Error loading $filter products: $e');
      return [];
    }
  }

  Widget _buildLoadingSkeleton() {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return const ProductCardShimmer();
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Failed to load products',
        style: TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'No products available',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}
