import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/services/hero_category_service.dart';
import 'package:kirihat_core/services/home_layout_service.dart';
import '../../widgets/product_card.dart';
import '../product/enhanced_product_detail.dart';
import '../widgets/floating_cart_button.dart';
import '../widgets/draggable_cart_wrapper.dart';
import 'package:kirihat_core/utils/cart_helper.dart';

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
  String? _categoryIcon; // Parent category icon
  
  String _selectedSubcategory = 'All';
  bool _isLoading = true;
  bool _isFiltering = false; // Loading state for subcategory switch
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData(); // Load products and extract subcategories
    _loadCartCount();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Get Category ID from Name (needed to fetch subcategories)
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

      // 2. Fetch Subcategories for this Category WITH ICONS
      final subcatsQuery = await FirebaseFirestore.instance
          .collection('subcategories')
          .where('category_id', isEqualTo: categoryId)
          .get();

      final List<String> fetchedSubcategories = [];
      final Map<String, String> subcategoryIconsMap = {};
      
      for (var doc in subcatsQuery.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) {
          fetchedSubcategories.add(name);
          // Store icon URL if exists
          if (data['icon_url'] != null) {
            subcategoryIconsMap[name] = data['icon_url'];
          }
        }
      }

      // 3. Build Vendor Inventory Map (for availability overlay)
      Map<String, Map<String, dynamic>> inventoryMap = {};
      try {
        final inventorySnap = await FirebaseFirestore.instance
            .collection('vendor_inventory')
            .where('vendor_id', isEqualTo: widget.vendorId)
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
        print('Error loading inventory: $e');
      }

      // 4. Fetch Products from MASTER_PRODUCTS (admin-controlled)
      final masterProductsSnap = await FirebaseFirestore.instance
          .collection('master_products')
          .where('category', isEqualTo: widget.categoryName)
          .get();

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
      print('Error loading category data: $e');
      if (mounted) setState(() => _isLoading = false);
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
  }

  Future<void> _loadCartCount() async {
    final count = await CartHelper.getCartCount();
    if (mounted) {
      setState(() => _cartCount = count);
    }
  }

  void _onSubcategorySelected(String subcategory) async {
    setState(() {
      _selectedSubcategory = subcategory;
      _isFiltering = true; // Trigger loading state
    });

    // Short delay to ensure UI clears old products before showing new ones
    await Future.delayed(const Duration(milliseconds: 50));

    _filterProducts();

    if (mounted) {
      setState(() => _isFiltering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder for responsiveness
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DraggableCartWrapper(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallMobile = constraints.maxWidth < 380;
                  final sidebarWidth = isSmallMobile ? 70.0 : 90.0;
                  
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
                          child: _isFiltering
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9759)))
                              : (_filteredProducts.isEmpty
                                  ? _buildEmptyState()
                                  : _buildProductsGrid(constraints.maxWidth - sidebarWidth)),
                        ),
                      ),
                    ],
                  );
                },
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
                                      image: NetworkImage(_categoryIcon!),
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
                                      image: NetworkImage(_subcategoryIcons[name]!),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No products found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          if (_selectedSubcategory != 'All')
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Text(
                 'in $_selectedSubcategory',
                 style: const TextStyle(color: Colors.grey),
               ),
             ),
        ],
      ),
    );
  }
}
