import 'package:flutter/material.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import 'package:kirihat_core/services/product_service.dart';
import '../../../widgets/product_card.dart';
import '../../product/enhanced_product_detail.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import '../../widgets/shimmer_loading.dart';

enum Source { cache, server, serverAndCache }

/// Enhanced Horizontal Product Row with caching and error handling
class EnhancedProductRowWidget extends StatefulWidget {
  final LayoutModel layout;
  final String vendorId;

  const EnhancedProductRowWidget({
    super.key,
    required this.layout,
    required this.vendorId,
  });

  @override
  State<EnhancedProductRowWidget> createState() => _EnhancedProductRowWidgetState();
}

class _EnhancedProductRowWidgetState extends State<EnhancedProductRowWidget>
    with AutomaticKeepAliveClientMixin {
  final ProductService _productService = ProductService();
  
  List<Map<String, dynamic>>? _cachedProducts;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  bool get _isCacheValid {
    if (_cachedProducts == null || _cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }

  Future<void> _loadProducts() async {
    // 1. Try to load from CACHE first for instant display
    try {
      final filter = widget.layout.data['filter'] as String? ?? 'trending';
      final limit = widget.layout.data['limit'] as int? ?? 10;
      
      // Attempt to get cached data (offline support)
      final cachedProducts = await _getProducts(filter, limit, source: Source.cache);
      
      if (mounted && cachedProducts.isNotEmpty) {
        setState(() {
          _cachedProducts = cachedProducts;
          _isLoading = false; 
        });
      }
    } catch (e) {
      // Ignore cache errors, just proceed to network
      debugPrint('⚠️ Cache miss or error: $e');
    }

    // 2. Fetch fresh data from SERVER
    if (mounted) {
      setState(() {
        if (_cachedProducts == null) _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final filter = widget.layout.data['filter'] as String? ?? 'trending';
      final limit = widget.layout.data['limit'] as int? ?? 10;
      
      final products = await _getProducts(filter, limit, source: Source.server)
          .timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _cachedProducts = products;
          _cacheTimestamp = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading products: $e');
      if (mounted) {
        setState(() {
          // Only show error if we have NO data at all
          if (_cachedProducts == null || _cachedProducts!.isEmpty) {
            _errorMessage = 'Failed to load products';
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getProducts(String filter, int limit, {Source source = Source.serverAndCache}) async {
    try {
      switch (filter.toLowerCase()) {
        case 'trending':
          return await _productService.getTrendingProducts(
            vendorId: widget.vendorId,
            limit: limit,
          );
        case 'new':
        case 'new_arrivals':
          return await _productService.getNewArrivals(
            vendorId: widget.vendorId,
            limit: limit,
          );
        case 'deals':
        case 'on_sale':
          return await _productService.getDeals(
            vendorId: widget.vendorId,
            limit: limit,
          );
        case 'collection':
          final collectionId = widget.layout.data['collection_id'] as String?;
          if (collectionId == null || collectionId.isEmpty) return [];
          
          return await _productService.getProductsByCollection(
            vendorId: widget.vendorId,
            collectionId: collectionId,
            limit: limit,
          );
        case 'category':
          final category = widget.layout.data['category'] as String?;
          if (category == null || category.isEmpty) return [];
          
          return await _productService.getProductsByCategory(
            vendorId: widget.vendorId,
            category: category,
            limit: limit,
          );
        case 'products':
          final productIds = (widget.layout.data['product_ids'] as List?)?.cast<String>();
          if (productIds == null || productIds.isEmpty) return [];
          
          return await _productService.getFeaturedProducts(
            vendorId: widget.vendorId,
            productIds: productIds,
          );
        default:
          return await _productService.getTrendingProducts(
            vendorId: widget.vendorId,
            limit: limit,
          );
      }
    } catch (e) {
      // debugPrint('❌ Error in _getProducts($filter): $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // For AutomaticKeepAliveClientMixin

    // Show cached data while loading fresh data
    if (_cachedProducts != null && _cachedProducts!.isNotEmpty) {
      return _buildProductRow(_cachedProducts!);
    }

    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return const SizedBox.shrink();
  }

  Widget _buildProductRow(List<Map<String, dynamic>> products) {
    final showViewAll = widget.layout.data['show_view_all'] as bool? ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.layout.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (_errorMessage != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    _cachedProducts = null;
                    _cacheTimestamp = null;
                    _loadProducts();
                  },
                  tooltip: 'Retry',
                ),
              if (showViewAll && _errorMessage == null)
                TextButton(
                  onPressed: _handleViewAll,
                  child: const Text(
                    'View All',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
        
        // Product List
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 150,
                child: ProductCard(
                  product: products[index],
                  onTap: () => _navigateToProduct(products[index]),
                  onAdd: () => _addToCart(products[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        
        // Products skeleton
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => const SizedBox(
              width: 150,
              child: ProductCardShimmer(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage ?? 'Failed to load products',
                style: TextStyle(color: Colors.red[900]),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _cachedProducts = null;
                _cacheTimestamp = null;
                _loadProducts();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProduct(Map<String, dynamic> product) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnhancedProductDetailScreen(
            productId: product['id'] ?? product['product_id'],
            productData: product,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to open product'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    await CartHelper.addToCart(context, product);
  }

  void _handleViewAll() {
    // TODO: Navigate to full product list
    final filter = widget.layout.data['filter'] as String? ?? 'trending';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View all $filter products'),
      ),
    );
  }

  @override
  void dispose() {
    _cachedProducts = null;
    _cacheTimestamp = null;
    super.dispose();
  }
}