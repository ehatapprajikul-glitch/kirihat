import 'package:flutter/material.dart';
import '../../services/hero_category_service.dart';
import '../../services/home_layout_service.dart';
import '../../widgets/product_card.dart';
import '../product/enhanced_product_detail.dart';
import '../widgets/floating_cart_button.dart';
import '../../utils/cart_helper.dart';

class NewCategoryProductsScreen extends StatefulWidget {
  final String categoryName;
  final String vendorId;

  const NewCategoryProductsScreen({
    super.key,
    required this.categoryName,
    required this.vendorId,
  });

  @override
  State<NewCategoryProductsScreen> createState() => _NewCategoryProductsScreenState();
}

class _NewCategoryProductsScreenState extends State<NewCategoryProductsScreen> {
  final HeroCategoryService _heroService = HeroCategoryService();
  final HomeLayoutService _layoutService = HomeLayoutService();
  
  List<Map<String, dynamic>> _subcategories = [];
  String? _selectedSubcategory;
  bool _isLoadingSubcategories = true;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
    _loadCartCount();
  }

  Future<void> _loadSubcategories() async {
    // For now, we'll fetch subcategories by category name
    // In a more robust system, you'd pass category ID
    setState(() => _isLoadingSubcategories = true);
    
    try {
      // TODO: Implement proper category ID lookup
      // For now, showing placeholder
      setState(() {
        _subcategories = [
          {'name': 'All', 'icon_url': null},
          {'name': 'Fresh Vegetables', 'icon_url': null},
          {'name': 'New Launch', 'icon_url': null},
          {'name': 'Fresh Fruits', 'icon_url': null},
          {'name': 'Leafy Vegetables', 'icon_url': null},
        ];
        _selectedSubcategory = 'All';
        _isLoadingSubcategories = false;
      });
    } catch (e) {
      print('Error loading subcategories: $e');
      setState(() => _isLoadingSubcategories = false);
    }
  }

  Future<void> _loadCartCount() async {
    final count = await CartHelper.getCartCount();
    if (mounted) {
      setState(() => _cartCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar - Subcategories
          _buildSubcategorySidebar(),
          
          // Right - Products Grid
          Expanded(
            child: _buildProductsGrid(),
          ),
        ],
      ),
      
      // Floating Cart Button
      floatingActionButton: const FloatingCartButton(),
    );
  }

  Widget _buildSubcategorySidebar() {
    return Container(
      width: 100,
      color: Colors.grey[50],
      child: _isLoadingSubcategories
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _subcategories.length,
              itemBuilder: (context, index) {
                final subcategory = _subcategories[index];
                final name = subcategory['name'] ?? 'Unnamed';
                final iconUrl = subcategory['icon_url'];
                final isSelected = _selectedSubcategory == name;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedSubcategory = name);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0D9759).withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0D9759) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Icon
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            image: iconUrl != null && iconUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(iconUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: iconUrl == null || iconUrl.isEmpty
                              ? Icon(
                                  Icons.category,
                                  color: isSelected ? const Color(0xFF0D9759) : Colors.grey,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        // Name
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF0D9759) : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProductsGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final products = snapshot.data!;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return ProductCard(
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
              onAdd: () async {
                await CartHelper.addToCart(context, products[index]);
                _loadCartCount();
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    try {
      // Fetch vendor inventory
      final inventoryDocs = await _layoutService.getAggregatedProducts(
        vendorIds: [widget.vendorId],
        limit: 100,
      ).first;

      List<Map<String, dynamic>> enrichedProducts = [];

      for (var doc in inventoryDocs.docs) {
        final inventoryData = doc.data() as Map<String, dynamic>;
        
        // Enrich with master product data
        final enriched = await _layoutService.enrichInventoryWithProduct(inventoryData);
        
        // Filter by category
        if (enriched['category'] == widget.categoryName) {
          // Filter by subcategory if selected
          if (_selectedSubcategory == 'All' || 
              _selectedSubcategory == null ||
              enriched['subcategory'] == _selectedSubcategory) {
            enriched['id'] = doc.id;
            enrichedProducts.add(enriched);
          }
        }
      }

      return enrichedProducts;
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'We don\'t have this category\'s products',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please check back later',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
