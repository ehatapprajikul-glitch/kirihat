import 'package:flutter/material.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:kirihat_core/utils/currency_helper.dart';
import 'vendor_product_detail.dart';

// New inventory system imports
import 'inventory/models/inventory_filter.dart';
import 'inventory/services/inventory_service.dart';
import 'inventory/widgets/inventory_dashboard.dart';
import 'inventory/widgets/filter_bar.dart';
import 'inventory/widgets/bulk_action_bar.dart';
import 'inventory/widgets/product_list_item.dart';
import 'inventory/widgets/stock_adjustment_dialog.dart';
import 'inventory/widgets/add_category_dialog.dart';
import 'inventory/widgets/add_product_dialog.dart';

class VendorInventoryScreen extends StatefulWidget {
  const VendorInventoryScreen({super.key});

  @override
  State<VendorInventoryScreen> createState() => _VendorInventoryScreenState();
}

class _VendorInventoryScreenState extends State<VendorInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? user = FirebaseAuth.instance.currentUser;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  
  // New inventory system state
  final InventoryService _inventoryService = InventoryService();
  InventoryFilter _currentFilter = InventoryFilter.defaults();
  bool _isSelectionMode = false;
  final Set<String> _selectedProducts = {};
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories(); // Load categories for filter dropdown
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteCategory(String docId, String categoryName) async {
    bool confirm = await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Delete Category?"),
            content: Text(
                "Warning: This will delete '$categoryName' and ALL products inside it."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text("Cancel")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Delete All")),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      // 1. Delete Products
      var products = await FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: categoryName)
          .get();
      for (var doc in products.docs) {
        await doc.reference.delete();
      }
      // 2. Delete Category
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Category and items deleted.")));
      }
    }
  }

  Future<void> _deleteProduct(String docId) async {
    bool confirm = await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Delete Product?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text("Delete",
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(docId)
          .delete();
    }
  }

  // --- NEW HELPER METHODS ---
  
  // Load categories for filter dropdown
  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('name')
          .get();
      
      if (mounted) {
        setState(() {
          _categories = snapshot.docs
              .map((doc) => (doc.data()['name'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  // Handle stock adjustment for a single product
  Future<void> _handleStockAdjustment(String productId, String productName, int currentStock, int adjustment) async {
    try {
      await _inventoryService.adjustStock(productId, adjustment, reason: 'Quick adjustment');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock updated for $productName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating stock: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Show stock adjustment dialog
  void _showStockAdjustmentDialog(String productId, String productName, int currentStock) {
    showDialog(
      context: context,
      builder: (context) => StockAdjustmentDialog(
        productName: productName,
        currentStock: currentStock,
        onAdjust: (adjustment) {
          _handleStockAdjustment(productId, productName, currentStock, adjustment);
        },
      ),
    );
  }

  // Handle bulk delete
  Future<void> _handleBulkDelete() async {
    if (_selectedProducts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Products'),
        content: Text('Delete ${_selectedProducts.length} selected products?'),
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

    if (confirmed == true && user != null) {
      try {
        await _inventoryService.bulkDelete(_selectedProducts.toList(), user!.uid);
        
        if (mounted) {
          setState(() {
            _selectedProducts.clear();
            _isSelectionMode = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Products deleted successfully')),
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

  // Handle bulk category change
  Future<void> _handleBulkCategoryChange() async {
    if (_selectedProducts.isEmpty || _categories.isEmpty) return;

    final selectedCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _categories.map((category) {
            return ListTile(
              title: Text(category),
              onTap: () => Navigator.pop(context, category),
            );
          }).toList(),
        ),
      ),
    );

    if (selectedCategory != null && user != null) {
      try {
        await _inventoryService.bulkUpdateCategory(
          _selectedProducts.toList(),
          selectedCategory,
          user!.uid,
        );
        
        if (mounted) {
          setState(() {
            _selectedProducts.clear();
            _isSelectionMode = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category updated to $selectedCategory')),
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

  // Handle bulk stock adjustment
  Future<void> _handleBulkStockAdjustment() async {
    if (_selectedProducts.isEmpty) return;

    final adjustment = await showDialog<int>(
      context: context,
      builder: (context) {
        int value = 0;
        return AlertDialog(
          title: const Text('Adjust Stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Adjust stock for ${_selectedProducts.length} products'),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Adjustment (+/-)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => value = int.tryParse(val) ?? 0,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, value),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (adjustment != null && adjustment != 0 && user != null) {
      try {
        final adjustments = {
          for (var id in _selectedProducts) id: adjustment
        };
        await _inventoryService.bulkAdjustStock(adjustments, user!.uid);
        
        if (mounted) {
          setState(() {
            _selectedProducts.clear();
            _isSelectionMode = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stock adjusted by $adjustment')),
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


  // --- SAFE ICON BUILDER (Handles URL vs Emoji) ---
  Widget _buildCategoryIcon(String? iconData) {
    if (iconData == null || iconData.isEmpty) {
      return const Icon(Icons.image_not_supported,
          size: 40, color: Colors.grey);
    }
    // Check if it's a URL (Cloudinary)
    if (iconData.startsWith('http')) {
      return Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(iconData),
              fit: BoxFit.cover,
              onError: (e, s) => {}, // Silent error
            )),
      );
    }
    // Assume it's an emoji/text
    return Text(iconData, style: const TextStyle(fontSize: 40));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Inventory Manager"),
        backgroundColor: Colors.orange[100],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepOrange,
          indicatorColor: Colors.deepOrange,
          tabs: const [
            Tab(text: "Categories"),
            Tab(text: "All Items"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoriesTab(),
          _buildItemsTab(),
        ],
      ),
    );
  }

  // --- TAB 1: CATEGORIES ---
  Widget _buildCategoriesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "catBtn",
            onPressed: () => showDialog(
                context: context, builder: (_) => const AddCategoryDialog()),
            label: const Text("New Category"),
            icon: const Icon(Icons.category),
            backgroundColor: Colors.blueGrey,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "prodBtn",
            onPressed: () => showDialog(
                context: context, builder: (_) => const AddProductDialog()),
            label: const Text("New Product"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.deepOrange,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No categories yet."));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return GestureDetector(
                onTap: () {
                  _searchController.text = data['name'] ?? "";
                  setState(() => _searchQuery =
                      (data['name'] ?? "").toString().toLowerCase());
                  _tabController.animateTo(1);
                },
                child: Card(
                  elevation: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCategoryIcon(data['icon']),
                      const SizedBox(height: 10),
                      Text(data['name'] ?? "Unnamed",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      TextButton.icon(
                        onPressed: () =>
                            _deleteCategory(docs[index].id, data['name'] ?? ""),
                        icon: const Icon(Icons.delete,
                            size: 16, color: Colors.red),
                        label: const Text("Delete",
                            style: TextStyle(color: Colors.red, fontSize: 12)),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- TAB 2: ITEMS ---
  Widget _buildItemsTab() {
    return Column(
      children: [
        // Dashboard - Show inventory metrics
        if (user?.uid != null)
          InventoryDashboard(vendorId: user!.uid),
        
        // Filter Bar
        if (_categories.isNotEmpty)
          FilterBar(
            currentFilter: _currentFilter,
            onFilterChanged: (newFilter) {
              setState(() => _currentFilter = newFilter);
            },
            categories: _categories,
          ),
        
        // Bulk Action Bar (shown when in selection mode)
        if (_isSelectionMode)
          BulkActionBar(
            selectedCount: _selectedProducts.length,
            onCancel: () {
              setState(() {
                _isSelectionMode = false;
                _selectedProducts.clear();
              });
            },
            onDelete: _handleBulkDelete,
            onChangeCategory: _handleBulkCategoryChange,
            onAdjustStock: _handleBulkStockAdjustment,
          ),
        
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search products...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  }),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('vendor_id', isEqualTo: user?.uid)
                // .orderBy('created_at', descending: true) // Commented out
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No items found."));
              }

              var docs = snapshot.data!.docs;

              // Apply search filter
              var filtered = docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                String name = (data['name'] ?? "").toString().toLowerCase();
                String category =
                    (data['category'] ?? "").toString().toLowerCase();
                return name.contains(_searchQuery) ||
                    category.contains(_searchQuery);
              }).toList();
              
              // Apply inventory filter (stock status, category, price, etc.)
              filtered = _currentFilter.applyToList(filtered);

              if (filtered.isEmpty) {
                return const Center(
                    child: Text("No items found matching search."));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  var doc = filtered[index];
                  var data = doc.data() as Map<String, dynamic>;

                  // SAFE TIMESTAMP PARSING
                  String date = "Unknown Date";
                  if (data['created_at'] != null &&
                      data['created_at'] is Timestamp) {
                    date = DateFormat('MMM d, y • h:mm a')
                        .format((data['created_at'] as Timestamp).toDate());
                  }

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => VendorProductDetailScreen(
                                    productData: data, productId: doc.id)));
                      },
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            image: (data['imageUrl'] != null &&
                                    data['imageUrl'].toString().isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(data['imageUrl']),
                                    fit: BoxFit.cover)
                                : null),
                        child: (data['imageUrl'] == null ||
                                data['imageUrl'].toString().isEmpty)
                            ? const Icon(Icons.image, color: Colors.grey)
                            : null,
                      ),
                      title: Text(data['name'] ?? "Unknown Product",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data['unit'] != null && data['unit'].toString().isNotEmpty)
                             Text("${data['unit']}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                          Text("Added: $date",
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                              "Stock: ${data['stock_quantity'] ?? 0} | ${CurrencyHelper.format(data['price'] ?? 0)}",
                              style: TextStyle(
                                  color: (data['stock_quantity'] ?? 0) <= 0
                                      ? Colors.red 
                                      : (data['stock_quantity'] ?? 0) < 5 ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AddProductScreen(
                                        initialData: data, docId: doc.id))),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProduct(doc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
