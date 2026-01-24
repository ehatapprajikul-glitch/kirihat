import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:kirihat_core/utils/currency_helper.dart';

// Inventory system imports
import 'inventory/widgets/stock_adjustment_dialog.dart';
import 'inventory/widgets/bulk_action_bar.dart';
import 'inventory/widgets/storage_location_dialog.dart';

class MyListedProductsScreen extends StatefulWidget {
  const MyListedProductsScreen({super.key});

  @override
  State<MyListedProductsScreen> createState() => _MyListedProductsScreenState();
}

class _MyListedProductsScreenState extends State<MyListedProductsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  
  // Search and Filter State
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> _selectedFilterNotifier = ValueNotifier<String>('all');
  final ValueNotifier<String> _sortByNotifier = ValueNotifier<String>('name_asc');
  final ValueNotifier<String?> _categoryFilterNotifier = ValueNotifier<String?>(null);
  Timer? _debounce;
  
  // Bulk operations state
  final ValueNotifier<bool> _isSelectionModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Set<String>> _selectedProductsNotifier = ValueNotifier<Set<String>>({});
  
  // Enhanced cache for product data and inventory
  static final Map<String, Map<String, dynamic>> _productCache = {};
  static final Map<String, Map<String, dynamic>> _inventoryCache = {};
  List<String> _categories = [];
  
  // Search focus for collapsible header
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<bool> _isSearchFocused = ValueNotifier<bool>(false);
  
  // Cache initialization flag
  bool _isCacheInitialized = false;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = 2; // Default to All Items
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      _isSearchFocused.value = _searchFocusNode.hasFocus;
    });
    
    // Pre-warm cache on init
    _initializeCache();
  }
  
  Future<void> _initializeCache() async {
    if (_isCacheInitialized) return;
    
    try {
      final String vendorId = FirebaseAuth.instance.currentUser!.uid;
      
      // Load all inventory data into cache
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .get();
      
      // Get unique product IDs
      Set<String> productIds = {};
      for (var doc in inventorySnapshot.docs) {
        _inventoryCache[doc.id] = doc.data();
        String productId = doc.data()['product_id'] ?? '';
        if (productId.isNotEmpty) {
          productIds.add(productId);
        }
      }
      
      // Batch load all products
      for (var productId in productIds) {
        if (!_productCache.containsKey(productId)) {
          try {
            var productDoc = await FirebaseFirestore.instance
                .collection('master_products')
                .doc(productId)
                .get();
            if (productDoc.exists) {
              _productCache[productId] = productDoc.data()!;
            }
          } catch (e) {
            // Continue loading other products
          }
        }
      }
      
      _isCacheInitialized = true;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Cache initialization error: $e');
    }
  }
  
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchQueryNotifier.value = _searchController.text;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchQueryNotifier.dispose();
    _selectedFilterNotifier.dispose();
    _sortByNotifier.dispose();
    _categoryFilterNotifier.dispose();
    _isSelectionModeNotifier.dispose();
    _selectedProductsNotifier.dispose();
    _searchFocusNode.dispose();
    _isSearchFocused.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final String vendorId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(vendorId),
          _buildCategoriesTab(vendorId),
          _buildAllItemsTab(vendorId),
        ],
      ),
      floatingActionButton: _buildFAB(vendorId),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.deepOrange,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Inventory Manager', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: _isSelectionModeNotifier,
          builder: (context, isSelectionMode, _) {
            if (_tabController.index != 2) return const SizedBox.shrink();
            return IconButton(
              onPressed: () {
                _isSelectionModeNotifier.value = !isSelectionMode;
                if (!_isSelectionModeNotifier.value) {
                  _selectedProductsNotifier.value = {};
                }
              },
              icon: Icon(isSelectionMode ? Icons.close : Icons.checklist),
              tooltip: isSelectionMode ? 'Exit Selection' : 'Select Items',
            );
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
          Tab(icon: Icon(Icons.category), text: 'Categories'),
          Tab(icon: Icon(Icons.list), text: 'All Items'),
        ],
      ),
    );
  }

  Widget _buildFAB(String vendorId) {
    return FloatingActionButton(
      onPressed: () => _exportToCSV(vendorId),
      backgroundColor: Colors.deepOrange,
      child: const Icon(Icons.download),
      tooltip: 'Export CSV',
    );
  }

  // DASHBOARD TAB - Enhanced with better card sizing
  Widget _buildDashboardTab(String vendorId) {
    return RefreshIndicator(
      onRefresh: () async {
        _isCacheInitialized = false;
        await _initializeCache();
        setState(() {});
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendor_inventory')
            .where('vendor_id', isEqualTo: vendorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;
          
          // Update inventory cache
          for (var doc in docs) {
            _inventoryCache[doc.id] = doc.data() as Map<String, dynamic>;
          }
          
          int total = docs.length;
          int lowStock = docs.where((d) => (d.data() as Map)['stock_quantity'] > 0 && (d.data() as Map)['stock_quantity'] < 5).length;
          int outOfStock = docs.where((d) => (d.data() as Map)['stock_quantity'] == 0).length;
          int inStock = total - outOfStock;
          double totalValue = docs.fold(0.0, (sum, d) {
            var data = d.data() as Map;
            return sum + ((data['stock_quantity'] ?? 0) * (data['selling_price'] ?? 0));
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Inventory Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // Metrics Grid - Responsive and properly sized
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildMetricCard('Total Products', total.toString(), Icons.inventory_2, Colors.blue, constraints.maxWidth),
                        _buildMetricCard('Low Stock', lowStock.toString(), Icons.warning, Colors.orange, constraints.maxWidth),
                        _buildMetricCard('Out of Stock', outOfStock.toString(), Icons.remove_circle, Colors.red, constraints.maxWidth),
                        _buildMetricCard('Total Value', CurrencyHelper.format(totalValue), Icons.attach_money, Colors.green, constraints.maxWidth),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Stock Distribution
                _buildStockDistribution(total, inStock, lowStock, outOfStock),
                
                const SizedBox(height: 32),
                
                // Quick Actions
                const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildActionButton('View All Items', Icons.list, () => _tabController.animateTo(2)),
                    _buildActionButton('Categories', Icons.category, () => _tabController.animateTo(1)),
                    _buildActionButton('Export CSV', Icons.download, () => _exportToCSV(vendorId)),
                    _buildActionButton('Low Stock Report', Icons.warning_amber, () => _showLowStockReport(docs)),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Recent Products - Using cached ProductCard
                const Text('Recently Added', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...(docs.take(5).map((doc) {
                  return _ProductCard(
                    key: ValueKey(doc.id),
                    inventoryId: doc.id,
                    inventoryData: _inventoryCache[doc.id] ?? doc.data() as Map<String, dynamic>,
                    vendorId: vendorId,
                    isSelectionMode: false,
                    isSelected: false,
                    productCache: _productCache,
                    onProductLoaded: (productId, productData) {
                      _productCache[productId] = productData;
                    },
                  );
                }).toList()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, double maxWidth) {
    // Calculate responsive width
    double cardWidth = (maxWidth - 36) / 2; // 2 cards per row with spacing
    if (maxWidth > 600) {
      cardWidth = (maxWidth - 48) / 4; // 4 cards per row on larger screens
    }
    
    return Container(
      width: cardWidth.clamp(140, 200), // Min 140, Max 200
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockDistribution(int total, int inStock, int lowStock, int outOfStock) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stock Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildDistributionRow('In Stock', inStock, total, Colors.green),
          const SizedBox(height: 12),
          _buildDistributionRow('Low Stock', lowStock, total, Colors.orange),
          const SizedBox(height: 12),
          _buildDistributionRow('Out of Stock', outOfStock, total, Colors.red),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String label, int count, int total, Color color) {
    double percentage = total > 0 ? (count / total) : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text('$count (${(percentage * 100).toStringAsFixed(1)}%)', 
                 style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // CATEGORIES TAB - Hierarchical browser with search
  Widget _buildCategoriesTab(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Extract unique categories and count
        Map<String, int> categoryCount = {};
        Map<String, Set<String>> categorySubcategories = {};
        
        for (var doc in snapshot.data!.docs) {
          String productId = (doc.data() as Map)['product_id'] ?? '';
          if (_productCache.containsKey(productId)) {
            String category = _productCache[productId]?['category'] ?? 'Uncategorized';
            categoryCount[category] = (categoryCount[category] ?? 0) + 1;
            
            var subcats = _productCache[productId]?['subcategories'];
            if (subcats != null) {
              if (subcats is List) {
                categorySubcategories.putIfAbsent(category, () => {});
                for (var sub in subcats) {
                  categorySubcategories[category]!.add(sub.toString());
                }
              }
            }
          }
        }

        if (categoryCount.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No categories found', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        var categories = categoryCount.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

        return _CategoryBrowser(
          vendorId: vendorId,
          categories: categories,
          categorySubcategories: categorySubcategories,
          productCache: _productCache,
          allDocs: snapshot.data!.docs,
        );
      },
    );
  }

  // ALL ITEMS TAB - Complete implementation with search, filters, bulk ops
  Widget _buildAllItemsTab(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isCacheInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No products in your inventory', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              ],
            ),
          );
        }

        var allDocs = snapshot.data!.docs;
        
        // Update inventory cache
        for (var doc in allDocs) {
          _inventoryCache[doc.id] = doc.data() as Map<String, dynamic>;
        }
        
        int totalProducts = allDocs.length;
        int lowStock = allDocs.where((d) => (d.data() as Map)['stock_quantity'] > 0 && (d.data() as Map)['stock_quantity'] < 5).length;
        int outOfStock = allDocs.where((d) => (d.data() as Map)['stock_quantity'] == 0).length;
        int inStock = totalProducts - outOfStock;
        int unlocated = allDocs.where((d) {
          var location = (d.data() as Map)['storage_location'];
          return location == null || (location['aisle'] ?? '').isEmpty && (location['shelf'] ?? '').isEmpty && (location['bin'] ?? '').isEmpty;
        }).length;
        double totalValue = allDocs.fold(0.0, (sum, d) {
          var data = d.data() as Map;
          return sum + ((data['stock_quantity'] ?? 0) * (data['selling_price'] ?? 0));
        });

        return ValueListenableBuilder<String>(
          valueListenable: _selectedFilterNotifier,
          builder: (context, selectedFilter, _) {
            var filteredDocs = allDocs.where((d) {
              int stock = (d.data() as Map)['stock_quantity'] ?? 0;
              var location = (d.data() as Map)['storage_location'];
              bool hasLocation = location != null && ((location['aisle'] ?? '').isNotEmpty || (location['shelf'] ?? '').isNotEmpty || (location['bin'] ?? '').isNotEmpty);
              
              if (selectedFilter == 'in_stock') return stock > 0;
              if (selectedFilter == 'low_stock') return stock > 0 && stock < 5;
              if (selectedFilter == 'out_of_stock') return stock == 0;
              if (selectedFilter == 'unlocated') return !hasLocation;
              return true;
            }).toList();

            return Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _isSearchFocused,
                  builder: (context, isFocused, _) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: isFocused ? 0 : null,
                      curve: Curves.easeInOut,
                      child: isFocused
                          ? const SizedBox.shrink()
                          : Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  color: Colors.white,
                                  child: Row(
                                    children: [
                                      Expanded(child: _buildSmallMetric(totalProducts.toString(), 'Total', Icons.shopping_bag_outlined, Colors.brown)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildSmallMetric(lowStock.toString(), 'Low Stock', Icons.warning_amber_outlined, Colors.orange)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildSmallMetric(outOfStock.toString(), 'Out of Stock', Icons.remove_circle_outline, Colors.red)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildSmallMetric(CurrencyHelper.format(totalValue), 'Value', Icons.attach_money, Colors.deepOrange)),
                                    ],
                                  ),
                                ),

                                ValueListenableBuilder<bool>(
                                  valueListenable: _isSelectionModeNotifier,
                                  builder: (context, isSelectionMode, _) {
                                    if (!isSelectionMode) return const SizedBox.shrink();
                                    return ValueListenableBuilder<Set<String>>(
                                      valueListenable: _selectedProductsNotifier,
                                      builder: (context, selectedProducts, __) {
                                        return BulkActionBar(
                                          selectedCount: selectedProducts.length,
                                          onCancel: () {
                                            _isSelectionModeNotifier.value = false;
                                            _selectedProductsNotifier.value = {};
                                          },
                                          onDelete: _handleBulkDelete,
                                          onChangeCategory: () {},
                                          onAdjustStock: _handleBulkStockAdjustment,
                                          onSetLocation: _handleBulkLocationUpdate,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                    );
                  },
                ),

                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      ValueListenableBuilder<String?>(
                        valueListenable: _categoryFilterNotifier,
                        builder: (context, category, _) {
                          if (category == null) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.deepOrange),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.category, size: 16, color: Colors.deepOrange),
                                const SizedBox(width: 8),
                                Text('Category: $category', 
                                     style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _categoryFilterNotifier.value = null,
                                  child: const Icon(Icons.close, size: 16, color: Colors.deepOrange),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<String>(
                              valueListenable: _searchQueryNotifier,
                              builder: (context, query, _) {
                                return TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Search by name, barcode, category...',
                                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                    suffixIcon: query.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 20),
                                            onPressed: () {
                                              _searchController.clear();
                                              _searchQueryNotifier.value = '';
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', totalProducts, 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('In Stock', inStock, 'in_stock'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Low Stock', lowStock, 'low_stock'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Out of Stock', outOfStock, 'out_of_stock'),
                            const SizedBox(width: 8),
                            _buildFilterChip('📍 No Location', unlocated, 'unlocated'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _searchQueryNotifier,
                    builder: (context, searchQuery, child) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: _categoryFilterNotifier,
                        builder: (context, categoryFilter, __) {
                          var displayDocs = filteredDocs;
                          
                          if (categoryFilter != null) {
                            displayDocs = displayDocs.where((d) {
                              String productId = (d.data() as Map)['product_id'] ?? '';
                              if (_productCache.containsKey(productId)) {
                                String category = _productCache[productId]?['category'] ?? '';
                                return category == categoryFilter;
                              }
                              return false;
                            }).toList();
                          }
                          
                          if (searchQuery.isNotEmpty) {
                            displayDocs = displayDocs.where((d) {
                              var inventoryData = d.data() as Map;
                              String productId = inventoryData['product_id'] ?? '';
                              if (_productCache.containsKey(productId)) {
                                return _matchesSearch(_productCache[productId]!, searchQuery);
                              }
                              return true;
                            }).toList();
                          }
                          
                          if (displayDocs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(searchQuery.isNotEmpty ? 'No results for "$searchQuery"' : 'No products found',
                                       style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: displayDocs.length,
                            itemBuilder: (context, index) {
                              var doc = displayDocs[index];
                              return ValueListenableBuilder<bool>(
                                valueListenable: _isSelectionModeNotifier,
                                builder: (context, isSelectionMode, _) {
                                  return ValueListenableBuilder<Set<String>>(
                                    valueListenable: _selectedProductsNotifier,
                                    builder: (context, selectedProducts, __) {
                                      return _ProductCard(
                                        key: ValueKey(doc.id),
                                        inventoryId: doc.id,
                                        inventoryData: _inventoryCache[doc.id] ?? doc.data() as Map<String, dynamic>,
                                        vendorId: vendorId,
                                        isSelectionMode: isSelectionMode,
                                        isSelected: selectedProducts.contains(doc.id),
                                        productCache: _productCache,
                                        onToggleSelection: (id) {
                                          final newSet = Set<String>.from(selectedProducts);
                                          if (newSet.contains(id)) {
                                            newSet.remove(id);
                                          } else {
                                            newSet.add(id);
                                          }
                                          _selectedProductsNotifier.value = newSet;
                                        },
                                        onProductLoaded: (productId, productData) {
                                          _productCache[productId] = productData;
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper widget methods...
  Widget _buildSmallMetric(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, String filterValue) {
    bool isSelected = _selectedFilterNotifier.value == filterValue;
    return InkWell(
      onTap: () => _selectedFilterNotifier.value = filterValue,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepOrange : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.deepOrange : Colors.grey[300]!),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // Bulk operation methods (unchanged, keeping them for completeness)
  Future<void> _handleBulkDelete() async {
    final selectedProducts = _selectedProductsNotifier.value;
    if (selectedProducts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Products'),
        content: Text('Remove ${selectedProducts.length} selected products from your inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (var id in selectedProducts) {
          batch.delete(FirebaseFirestore.instance.collection('vendor_inventory').doc(id));
        }
        await batch.commit();
        
        if (mounted) {
          _selectedProductsNotifier.value = {};
          _isSelectionModeNotifier.value = false;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Products removed successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _handleBulkStockAdjustment() async {
    final selectedProducts = _selectedProductsNotifier.value;
    if (selectedProducts.isEmpty) return;

    final adjustment = await showDialog<int>(
      context: context,
      builder: (context) {
        int value = 0;
        return AlertDialog(
          title: const Text('Adjust Stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Adjust stock for ${selectedProducts.length} products'),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Adjustment (+/-)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., +10 or -5',
                ),
                onChanged: (val) => value = int.tryParse(val) ?? 0,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, value), child: const Text('Apply')),
          ],
        );
      },
    );

    if (adjustment != null && adjustment != 0) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        for (var id in selectedProducts) {
          final docRef = FirebaseFirestore.instance.collection('vendor_inventory').doc(id);
          final doc = await docRef.get();
          if (doc.exists) {
            int currentStock = (doc.data()?['stock_quantity'] ?? 0);
            int newStock = (currentStock + adjustment).clamp(0, 999999);
            batch.update(docRef, {
              'stock_quantity': newStock,
              'last_updated': FieldValue.serverTimestamp(),
            });
          }
        }
        
        await batch.commit();
        
        if (mounted) {
          _selectedProductsNotifier.value = {};
          _isSelectionModeNotifier.value = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stock adjusted by $adjustment for ${selectedProducts.length} products')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _handleBulkLocationUpdate() async {
    final selectedProducts = _selectedProductsNotifier.value;
    if (selectedProducts.isEmpty) return;

    final location = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => StorageLocationDialog(
        currentLocation: null,
        productName: '${selectedProducts.length} products',
      ),
    );

    if (location != null) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        for (var id in selectedProducts) {
          final docRef = FirebaseFirestore.instance.collection('vendor_inventory').doc(id);
          batch.update(docRef, {
            'storage_location': location,
            'last_updated': FieldValue.serverTimestamp(),
          });
          if (_inventoryCache.containsKey(id)) {
            _inventoryCache[id]!['storage_location'] = location;
          }
        }
        
        await batch.commit();
        
        if (mounted) {
          _selectedProductsNotifier.value = {};
          _isSelectionModeNotifier.value = false;
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Location updated for ${selectedProducts.length} products')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  bool _matchesSearch(Map<String, dynamic> productData, String query) {
    String searchQuery = query.toLowerCase();
    
    String name = (productData['name'] ?? '').toString().toLowerCase();
    if (name.contains(searchQuery)) return true;
    
    String barcode = (productData['barcode'] ?? '').toString().toLowerCase();
    if (barcode.contains(searchQuery)) return true;
    
    String category = (productData['category'] ?? '').toString().toLowerCase();
    if (category.contains(searchQuery)) return true;
    
    var subcategories = productData['subcategories'];
    if (subcategories != null) {
      if (subcategories is List) {
        for (var sub in subcategories) {
          if (sub.toString().toLowerCase().contains(searchQuery)) return true;
        }
      } else if (subcategories is String) {
        if (subcategories.toLowerCase().contains(searchQuery)) return true;
      }
    }
    
    return false;
  }

  void _showLowStockReport(List<QueryDocumentSnapshot> docs) {
    var lowStockItems = docs.where((d) => (d.data() as Map)['stock_quantity'] > 0 && (d.data() as Map)['stock_quantity'] < 5).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Low Stock Report'),
        content: SizedBox(
          width: double.maxFinite,
          child: lowStockItems.isEmpty
              ? const Text('No low stock items')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: lowStockItems.length,
                  itemBuilder: (context, index) {
                    var data = lowStockItems[index].data() as Map;
                    return ListTile(
                      title: Text('Product ${lowStockItems[index].id.substring(0, 8)}'),
                      subtitle: Text('Stock: ${data['stock_quantity']}'),
                      trailing: const Icon(Icons.warning, color: Colors.orange),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _exportToCSV(String vendorId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final docs = await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .get();
      
      StringBuffer csv = StringBuffer();
      csv.writeln('Product ID,Product Name,Category,Barcode,Stock Quantity,Selling Price,Created At');
      
      for (var doc in docs.docs) {
        var data = doc.data();
        String productId = data['product_id'] ?? '';
        
        String productName = 'Unknown';
        String category = 'N/A';
        String barcode = 'N/A';
        
        if (_productCache.containsKey(productId)) {
          var productData = _productCache[productId]!;
          productName = productData['name'] ?? 'Unknown';
          category = productData['category'] ?? 'N/A';
          barcode = productData['barcode'] ?? 'N/A';
        }
        
        productName = '"${productName.replaceAll('"', '""')}"';
        category = '"${category.replaceAll('"', '""')}"';
        
        csv.writeln('$productId,$productName,$category,$barcode,${data['stock_quantity']},${data['selling_price']},${data['created_at']}');
      }
      
      Navigator.pop(context);
      
      final csvData = csv.toString();
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'inventory_export_${DateTime.now().millisecondsSinceEpoch}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Exported ${docs.docs.length} products to CSV')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatValue(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toInt().toString();
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime date = (timestamp as Timestamp).toDate();
      Duration diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return 'Unknown';
    }
  }
}

// ENHANCED Product Card Widget with Cache Support
class _ProductCard extends StatefulWidget {
  final String inventoryId;
  final Map<String, dynamic> inventoryData;
  final String vendorId;
  final Map<String, Map<String, dynamic>> productCache;
  final Function(String, Map<String, dynamic>)? onProductLoaded;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String)? onToggleSelection;

  const _ProductCard({
    super.key,
    required this.inventoryId,
    required this.inventoryData,
    required this.vendorId,
    required this.productCache,
    this.onProductLoaded,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelection,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _productData;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  Future<void> _loadProductData() async {
    String productId = widget.inventoryData['product_id'] ?? '';
    
    // Check cache first
    if (widget.productCache.containsKey(productId)) {
      if (mounted) {
        setState(() {
          _productData = widget.productCache[productId];
          _isLoading = false;
        });
      }
      return;
    }
    
    // Load from Firestore only if not in cache
    setState(() => _isLoading = true);
    
    try {
      var productDoc = await FirebaseFirestore.instance
          .collection('master_products')
          .doc(productId)
          .get();

      if (productDoc.exists && mounted) {
        var productData = productDoc.data()!;
        setState(() {
          _productData = productData;
          _isLoading = false;
        });
        widget.onProductLoaded?.call(productId, productData);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStock(int newStock) async {
    try {
      await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .doc(widget.inventoryId)
          .update({
        'stock_quantity': newStock,
        'last_updated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showStockDialog() {
    final currentStock = widget.inventoryData['stock_quantity'] ?? 0;
    final productName = _productData?['name'] ?? 'Product';

    showDialog(
      context: context,
      builder: (context) => StockAdjustmentDialog(
        productName: productName,
        currentStock: currentStock,
        onAdjust: (adjustment) {
          final newStock = (currentStock + adjustment).clamp(0, 999999);
          _updateStock(newStock);
        },
      ),
    );
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Remove this product from your inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('vendor_inventory')
            .doc(widget.inventoryId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product removed')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _showLocationDialog(BuildContext context) async {
    var currentLocation = widget.inventoryData['storage_location'] as Map<String, dynamic>?;
    
    final location = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => StorageLocationDialog(
        currentLocation: currentLocation,
        productName: _productData?['name'] ?? 'Product',
      ),
    );

    if (location != null) {
      try {
        await FirebaseFirestore.instance
            .collection('vendor_inventory')
            .doc(widget.inventoryId)
            .update({
          'storage_location': location,
          'last_updated': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Location updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 100,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_productData == null) {
      return const SizedBox.shrink();
    }

    int stock = widget.inventoryData['stock_quantity'] ?? 0;
    double sellingPrice = widget.inventoryData['selling_price']?.toDouble() ?? 0;
    String name = _productData!['name'] ?? 'Unknown Product';
    String unit = _productData!['unit'] ?? '';
    String category = _productData!['category'] ?? '';
    String barcode = _productData!['barcode'] ?? 'N/A';
    String imageUrl = _productData!['imageUrl'] ?? '';

    bool isOutOfStock = stock == 0;
    bool isLowStock = stock > 0 && stock < 5;
    Color stockColor = isOutOfStock ? Colors.red : isLowStock ? Colors.orange : Colors.green;
    String stockText = isOutOfStock ? 'Out of Stock' : 'Stock: $stock';

    return InkWell(
      onTap: widget.isSelectionMode ? () => widget.onToggleSelection?.call(widget.inventoryId) : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: widget.isSelected ? Colors.deepOrange.withOpacity(0.1) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: widget.isSelected ? Colors.deepOrange : Colors.grey[200]!,
            width: widget.isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (widget.isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onToggleSelection?.call(widget.inventoryId),
                    activeColor: Colors.deepOrange,
                  ),
                ),
              
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                          },
                        ),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('$unit • $category • Barcode: $barcode',
                         style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 6),
                    
                    Builder(
                      builder: (context) {
                        var storageLocation = widget.inventoryData['storage_location'] as Map?;
                        bool hasLocation = storageLocation != null && 
                            ((storageLocation['aisle'] ?? '').isNotEmpty || 
                             (storageLocation['shelf'] ?? '').isNotEmpty || 
                             (storageLocation['bin'] ?? '').isNotEmpty);
                        
                        if (hasLocation) {
                          String aisle = storageLocation['aisle'] ?? '-';
                          String shelf = storageLocation['shelf'] ?? '-';
                          String bin = storageLocation['bin'] ?? '-';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 11, color: Colors.green),
                                const SizedBox(width: 3),
                                Text('$aisle/$shelf/$bin',
                                     style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        } else {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_off, size: 11, color: Colors.orange),
                                SizedBox(width: 3),
                                Text('No Location', 
                                     style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(CurrencyHelper.format(sellingPrice),
                             style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: stockColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(stockText,
                                   style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (!widget.isSelectionMode)
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showLocationDialog(context),
                      icon: const Icon(Icons.location_on, size: 20),
                      color: Colors.green,
                      style: IconButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1)),
                      tooltip: 'Set Location',
                    ),
                    IconButton(
                      onPressed: _showStockDialog,
                      icon: const Icon(Icons.edit, size: 20),
                      color: Colors.deepOrange,
                      style: IconButton.styleFrom(backgroundColor: Colors.deepOrange.withOpacity(0.1)),
                      tooltip: 'Edit Stock',
                    ),
                    IconButton(
                      onPressed: _deleteProduct,
                      icon: const Icon(Icons.delete, size: 20),
                      color: Colors.grey[400],
                      style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Category Browser Widget - Hierarchical view with search
class _CategoryBrowser extends StatefulWidget {
  final String vendorId;
  final List<MapEntry<String, int>> categories;
  final Map<String, Set<String>> categorySubcategories;
  final Map<String, Map<String, dynamic>> productCache;
  final List<QueryDocumentSnapshot> allDocs;

  const _CategoryBrowser({
    required this.vendorId,
    required this.categories,
    required this.categorySubcategories,
    required this.productCache,
    required this.allDocs,
  });

  @override
  State<_CategoryBrowser> createState() => _CategoryBrowserState();
}

class _CategoryBrowserState extends State<_CategoryBrowser> {
  String? _selectedCategory;
  String? _selectedSubcategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _getFilteredProducts() {
    return widget.allDocs.where((doc) {
      String productId = (doc.data() as Map)['product_id'] ?? '';
      if (!widget.productCache.containsKey(productId)) return false;
      
      var productData = widget.productCache[productId]!;
      String category = productData['category'] ?? '';
      
      if (_selectedCategory != null && category != _selectedCategory) return false;
      
      if (_selectedSubcategory != null) {
        var subcats = productData['subcategories'];
        bool hasSubcat = false;
        if (subcats is List) {
          hasSubcat = subcats.any((s) => s.toString() == _selectedSubcategory);
        } else if (subcats is String) {
          hasSubcat = subcats == _selectedSubcategory;
        }
        if (!hasSubcat) return false;
      }
      
      if (_searchQuery.isNotEmpty) {
        String query = _searchQuery.toLowerCase();
        String name = (productData['name'] ?? '').toString().toLowerCase();
        String barcode = (productData['barcode'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !barcode.contains(query)) return false;
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCategory == null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search categories...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.categories.length,
              itemBuilder: (context, index) {
                var entry = widget.categories[index];
                if (_searchQuery.isNotEmpty && 
                    !entry.key.toLowerCase().contains(_searchQuery.toLowerCase())) {
                  return const SizedBox.shrink();
                }
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.category, color: Colors.deepOrange),
                    ),
                    title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${entry.value} products'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => setState(() {
                      _selectedCategory = entry.key;
                      _searchQuery = '';
                      _searchController.clear();
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    var subcategories = widget.categorySubcategories[_selectedCategory] ?? {};
    var products = _getFilteredProducts();
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.deepOrange.withOpacity(0.1),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _selectedCategory = null;
                  _selectedSubcategory = null;
                }),
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(backgroundColor: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedCategory!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    if (_selectedSubcategory != null)
                      Text(_selectedSubcategory!, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products in this category...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        
        if (subcategories.isNotEmpty && _selectedSubcategory == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subcategories:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: subcategories.map((subcat) {
                    return ActionChip(
                      label: Text(subcat),
                      backgroundColor: Colors.deepOrange.withOpacity(0.1),
                      side: BorderSide(color: Colors.deepOrange.withOpacity(0.3)),
                      onPressed: () => setState(() => _selectedSubcategory = subcat),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        
        if (_selectedSubcategory != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Chip(
                  label: Text(_selectedSubcategory!),
                  backgroundColor: Colors.deepOrange,
                  labelStyle: const TextStyle(color: Colors.white),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                  onDeleted: () => setState(() => _selectedSubcategory = null),
                ),
              ],
            ),
          ),
        
        const Divider(height: 1),
        
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No products found', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    var doc = products[index];
                    var inventoryData = doc.data() as Map<String, dynamic>;
                    String productId = inventoryData['product_id'] ?? '';
                    var productData = widget.productCache[productId];
                    
                    if (productData == null) return const SizedBox.shrink();
                    
                    int stock = inventoryData['stock_quantity'] ?? 0;
                    double price = inventoryData['selling_price']?.toDouble() ?? 0;
                    String name = productData['name'] ?? 'Unknown';
                    String barcode = productData['barcode'] ?? 'N/A';
                    String imageUrl = productData['imageUrl'] ?? '';
                    
                    bool isOutOfStock = stock == 0;
                    bool isLowStock = stock > 0 && stock < 5;
                    Color stockColor = isOutOfStock ? Colors.red : isLowStock ? Colors.orange : Colors.green;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(imageUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                                )
                              : const Icon(Icons.image, color: Colors.grey),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Barcode: $barcode • ${CurrencyHelper.format(price)}', style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: stockColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Stock: $stock',
                                       style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
