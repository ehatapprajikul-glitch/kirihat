import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/services/hero_category_service.dart';
import 'package:kirihat_core/services/home_layout_service.dart';
import '../../widgets/product_card.dart';
import '../product/enhanced_product_detail.dart';
import '../widgets/floating_cart_button.dart';
import '../widgets/draggable_cart_wrapper.dart';
import '../widgets/product_search_delegate.dart';
import 'package:kirihat_core/utils/cart_helper.dart';

enum SortOption { priceAsc, priceDesc, discount, name }

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
  final HomeLayoutService _layoutService = HomeLayoutService();
  
  // Data State
  List<Map<String, dynamic>> _allProducts = []; // Full list for the category
  List<Map<String, dynamic>> _filteredProducts = []; // Filtered by subcategory
  Set<String> _subcategories = {}; // Unique subcategories
  Map<String, String> _subcategoryIcons = {}; // Subcategory name -> icon URL
  Map<String, int> _subcategoryProductCounts = {}; // Subcategory -> product count
  String? _categoryIcon; // Parent category icon
  
  String _selectedSubcategory = 'All';
  bool _isLoading = true;
  int _cartCount = 0;
  
  // Sorting & Filtering State
  SortOption _currentSort = SortOption.priceAsc;
  bool _showInStockOnly = false;

  @override
  void initState() {
    super.initState();
    _loadData(); // Load products and extract subcategories
    _loadCartCount();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Get Parent Category ID and data
      final categoryQuery = await FirebaseFirestore.instance
          .collection('categories')
          .where('name', isEqualTo: widget.categoryName)
          .limit(1)
          .get();

      if (categoryQuery.docs.isEmpty) {
        print('Category not found: ${widget.categoryName}');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final categoryId = categoryQuery.docs.first.id;
      final categoryData = categoryQuery.docs.first.data();
      final fetchedCategoryIcon = categoryData['icon'] as String?;

      // 2. Fetch Subcategories (categories with parent_id = current category)
      // Using the same 'categories' collection with nested structure
      final subcatsQuery = await FirebaseFirestore.instance
          .collection('categories')
          .where('parent_id', isEqualTo: categoryId)
          .where('isActive', isEqualTo: true)
          .orderBy('sort_order')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ Subcategory fetch timed out');
              throw TimeoutException('Failed to load subcategories');
            },
          );

      final List<String> fetchedSubcategories = [];
      final Map<String, String> subcategoryIconsMap = {};
      
      for (var doc in subcatsQuery.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) {
          fetchedSubcategories.add(name);
          // Store icon URL if exists
          if (data['icon'] != null) {
            subcategoryIconsMap[name] = data['icon'];
          }
        }
      }

      // 3. Fetch Products from MASTER_PRODUCTS (admin-controlled)
      final masterProductsSnap = await FirebaseFirestore.instance
          .collection('master_products')
          .where('category', isEqualTo: widget.categoryName)
          .get();

      if (masterProductsSnap.docs.isEmpty) {
        print('⚠️ No products found in category: ${widget.categoryName}');
        if (mounted) {
          setState(() {
            _allProducts = [];
            _filterProducts();
            _isLoading = false;
          });
        }
        return;
      }

      // 4. Build inventory map ONLY for products in this category (OPTIMIZED)
      // Extract product IDs from master products
      final productIds = masterProductsSnap.docs.map((doc) => doc.id).toList();
      
      Map<String, Map<String, dynamic>> inventoryMap = {};
      
      // Fetch inventory in batches of 10 (Firestore 'in' query limit)
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();
        try {
          final inventorySnap = await FirebaseFirestore.instance
              .collection('vendor_inventory')
              .where('vendor_id', isEqualTo: widget.vendorId)
              .where('product_id', whereIn: batch)
              .get();

          for (var doc in inventorySnap.docs) {
            final data = doc.data();
            final productId = data['product_id'];
            if (productId != null) {
              inventoryMap[productId] = {
                'price': data['selling_price'],
                'stock_quantity': data['stock_quantity'] ?? 0,
                'isAvailable': data['isAvailable'] ?? true,
              };
            }
          }
        } catch (e) {
          print('❌ Error loading inventory batch: $e');
        }
      }

      print('✅ Loaded inventory for ${inventoryMap.length}/${productIds.length} products');

      // 5. Build products list with vendor inventory overlay
      List<Map<String, dynamic>> fetchedProducts = [];

      for (var doc in masterProductsSnap.docs) {
        Map<String, dynamic> product = doc.data();
        product['id'] = doc.id; // ALWAYS use master product ID
        product['vendor_id'] = widget.vendorId; // CRITICAL: Add vendor_id for cart
        
        // Overlay vendor inventory data
        if (inventoryMap.containsKey(doc.id)) {
          final inv = inventoryMap[doc.id]!;
          product['price'] = inv['price'] ?? product['price'];
          product['stock_quantity'] = inv['stock_quantity'];
          product['isAvailable'] = inv['isAvailable'];
          product['isAvailableInCurrentVendor'] = inv['isAvailable'] == true;
        } else {
          // Product exists in catalog but not in this vendor's inventory
          product['stock_quantity'] = 0;
          product['isAvailable'] = false;
          product['isAvailableInCurrentVendor'] = false;
        }

        fetchedProducts.add(product);
      }

      if (mounted) {
        setState(() {
          _allProducts = fetchedProducts;
          // Use fetched subcategories instead of extracting from products
          _subcategories = fetchedSubcategories.toSet();
          _subcategoryIcons = subcategoryIconsMap; // Store icons
          _categoryIcon = fetchedCategoryIcon;
          _filterProducts();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading category data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        
        // Show user-friendly error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load products. Please check your connection.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadData,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _filterProducts() {
    if (_selectedSubcategory == 'All') {
      _filteredProducts = List.from(_allProducts);
    } else {
      _filteredProducts = _allProducts
          .where((p) => p['subcategory'] == _selectedSubcategory)
          .toList();
    }
    
    // Apply in-stock filter
    if (_showInStockOnly) {
      _filteredProducts = _filteredProducts
          .where((p) => (p['stock_quantity'] ?? 0) > 0 && 
                        (p['isAvailableInCurrentVendor'] ?? false))
          .toList();
    }
    
    // Apply sorting
    _sortProducts();
    
    // Calculate product counts per subcategory
    _subcategoryProductCounts.clear();
    for (var subcategory in _subcategories) {
      final count = _allProducts.where((p) => p['subcategory'] == subcategory).length;
      _subcategoryProductCounts[subcategory] = count;
    }
  }
  
  void _sortProducts() {
    switch (_currentSort) {
      case SortOption.priceAsc:
        _filteredProducts.sort((a, b) => 
          ((a['price'] ?? 0) as num).compareTo((b['price'] ?? 0) as num));
        break;
      case SortOption.priceDesc:
        _filteredProducts.sort((a, b) => 
          ((b['price'] ?? 0) as num).compareTo((a['price'] ?? 0) as num));
        break;
      case SortOption.discount:
        _filteredProducts.sort((a, b) {
          final discountA = ((a['mrp'] ?? 0) as num) - ((a['price'] ?? 0) as num);
          final discountB = ((b['mrp'] ?? 0) as num) - ((b['price'] ?? 0) as num);
          return discountB.compareTo(discountA);
        });
        break;
      case SortOption.name:
        _filteredProducts.sort((a, b) => 
          (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
        break;
    }
  }

  Future<void> _loadCartCount() async {
    final count = await CartHelper.getCartCount();
    if (mounted) {
      setState(() => _cartCount = count);
    }
  }

  void _onSubcategorySelected(String subcategory) {
    setState(() {
      _selectedSubcategory = subcategory;
      _filterProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder for responsiveness
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(widget.categoryName),
              centerTitle: true,
              backgroundColor: const Color(0xFF0D9759),
              foregroundColor: Colors.white,
              pinned: true,
              floating: true,
              forceElevated: innerBoxIsScrolled,
              actions: [
                IconButton(
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: ProductSearchDelegate(
                        products: _allProducts,
                        categoryName: widget.categoryName,
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : DraggableCartWrapper(
                child: Column(
                  children: [
                    // Sorting & Filtering Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.grey[50],
                      child: Row(
                        children: [
                          // Sort Dropdown
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButton<SortOption>(
                                value: _currentSort,
                                isExpanded: true,
                                underline: const SizedBox(),
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                items: const [
                                  DropdownMenuItem(value: SortOption.priceAsc, 
                                    child: Text('Price: Low to High')),
                                  DropdownMenuItem(value: SortOption.priceDesc, 
                                    child: Text('Price: High to Low')),
                                  DropdownMenuItem(value: SortOption.discount, 
                                    child: Text('Discount %')),
                                  DropdownMenuItem(value: SortOption.name, 
                                    child: Text('Name: A-Z')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _currentSort = value;
                                      _filterProducts();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // In-Stock Filter
                          FilterChip(
                            label: const Text('In Stock', style: TextStyle(fontSize: 12)),
                            selected: _showInStockOnly,
                            onSelected: (selected) {
                              setState(() {
                                _showInStockOnly = selected;
                                _filterProducts();
                              });
                            },
                            selectedColor: const Color(0xFF0D9759).withOpacity(0.2),
                            checkmarkColor: const Color(0xFF0D9759),
                          ),
                        ],
                      ),
                    ),
                    // Product Grid with Sidebar
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isSmallMobile = constraints.maxWidth < 380;
                          final sidebarWidth = isSmallMobile ? 100.0 : 120.0;
                          
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Sidebar - Subcategories
                              SizedBox(
                                width: sidebarWidth,
                                child: _buildSubcategorySidebar(isSmallMobile),
                              ),
                              
                              // Right - Products Grid
                              Expanded(
                                child: Container(
                                  color: Colors.white,
                                  child: _filteredProducts.isEmpty
                                      ? _buildEmptyState()
                                      : _buildProductsGrid(constraints.maxWidth - sidebarWidth),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSubcategorySidebar(bool isSmall) {
    // Convert Set to List and add 'All'
    final List<String> displayList = ['All', ..._subcategories.toList()..sort()];

    return Container(
      color: Colors.grey[50],
      child: ListView.builder(
        // Added bottom padding (100) for sidebar visibility
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          final name = displayList[index];
          final isSelected = _selectedSubcategory == name;
          final isAll = name == 'All';

          return GestureDetector(
            onTap: () => _onSubcategorySelected(name),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected 
                    ? Border.all(color: const Color(0xFF0D9759), width: 1.5)
                    : null,
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Container - Rounded Square
                  Container(
                    width: isSmall ? 40 : 48, // Increased size
                    height: isSmall ? 40 : 48,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0D9759).withOpacity(0.1) : Colors.white,
                      // Shape -> Rectangle with Border Radius
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: isAll
                          // "All" -> Show Parent Category Icon if available
                          ? (_categoryIcon != null
                              ? Container(
                                  width: isSmall ? 32 : 36, // Increased inner size
                                  height: isSmall ? 32 : 36,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    image: DecorationImage(
                                      image: CachedNetworkImageProvider(_categoryIcon!),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                )
                              : Icon(Icons.grid_view_rounded, 
                                  color: isSelected ? const Color(0xFF0D9759) : Colors.grey,
                                  size: isSmall ? 24 : 28)
                            )
                          : _subcategoryIcons.containsKey(name)
                              ? Container(
                                  width: isSmall ? 32 : 36, // Increased inner size
                                  height: isSmall ? 32 : 36,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    image: DecorationImage(
                                      image: CachedNetworkImageProvider(_subcategoryIcons[name]!),
                                      fit: BoxFit.contain, // Show full icon
                                    ),
                                  ),
                                )
                              : Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: isSmall ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? const Color(0xFF0D9759) : Colors.grey,
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Name
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isSmall ? 10 : 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF0D9759) : Colors.black87,
                    ),
                  ),
                  // Product Count
                  if (name != 'All' && _subcategoryProductCounts.containsKey(name))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${_subcategoryProductCounts[name]} items',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[600],
                        ),
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

  Widget _buildProductsGrid(double availableWidth) {
    // Calculate responsiveness
    // On average mobile (360px width) - sidebar (70-90px) = ~270-290px available.
    // To fit 2 columns, each card + spacing needs to fit.
    // 270 / 2 = 135px. So we should use a threshold around 130-135px to ensure 2 columns.
    
    int crossAxisCount = (availableWidth / 135).floor();
    // Force at least 2 columns if we have reasonable space (e.g. > 260px), otherwise 1
    if (availableWidth > 260 && crossAxisCount < 2) crossAxisCount = 2;
    if (crossAxisCount < 1) crossAxisCount = 1;
    
    double spacing = 10.0; // Slightly tighter spacing
    double cardWidth = (availableWidth - (spacing * 2) - ((crossAxisCount - 1) * spacing)) / crossAxisCount;
    
    // Desired height components: Image (~55%) + Content (~45%)
    // If card width is 135, height needs to be enough to hold content comfortably.
    // Increased to 280.0 to prevent overflow on small screens where width is narrow.
    double desiredHeight = 280.0; 
    
    double childAspectRatio = cardWidth / desiredHeight;
    
    // Clamp to prevent errors or extreme stretching
    // Lowered min clamp to 0.45 to allow taller cards relative to width
    if (childAspectRatio < 0.45) childAspectRatio = 0.45;
    if (childAspectRatio > 1.0) childAspectRatio = 1.0;

    return GridView.builder(
      // Added substantial bottom padding (100) to clear floating UI elements
      padding: EdgeInsets.fromLTRB(spacing, spacing, spacing, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return ProductCard(
          key: ValueKey(product['id']), // Ensure unique key for performance
          product: product,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EnhancedProductDetailScreen(
                  productId: product['id'],
                  productData: product,
                ),
              ),
            );
          },
          onAdd: () async {
            // Quietly add to cart (button updates to counter)
            await CartHelper.addToCart(context, product, showSuccessMessage: false);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final bool hasProducts = _allProducts.isNotEmpty;
    final bool isFiltered = _selectedSubcategory != 'All' || _showInStockOnly;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.filter_list_off : Icons.inventory_2_outlined,
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered 
                  ? 'No products match your filters'
                  : 'No products available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? _selectedSubcategory != 'All'
                      ? 'Try selecting "All" or a different subcategory'
                      : 'Try removing the "In Stock" filter'
                  : 'This vendor hasn\'t stocked items in this category yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedSubcategory = 'All';
                    _showInStockOnly = false;
                    _filterProducts();
                  });
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
