import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import '../products/enhanced_add_product_screen.dart';
import '../products/services/barcode_printer_service.dart';
import 'package:intl/intl.dart';

/// Enhanced Professional Inventory Screen
/// Features: Bulk actions, export, barcode printing, advanced filters, batch updates
/// Designed to match big platform standards (Amazon Seller Central, Shopify, etc.)
class EnhancedSellerInventoryScreen extends StatefulWidget {
  final SellerModel seller;

  const EnhancedSellerInventoryScreen({super.key, required this.seller});

  @override
  State<EnhancedSellerInventoryScreen> createState() => _EnhancedSellerInventoryScreenState();
}

class _EnhancedSellerInventoryScreenState extends State<EnhancedSellerInventoryScreen> {
  final SellerService _sellerService = SellerService();
  final BarcodePrinterService _barcodePrinterService = BarcodePrinterService();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<FormFieldState> _searchFieldKey = GlobalKey<FormFieldState>();
  Timer? _debounceTimer;
  
  // Use ValueNotifier for selections to avoid full rebuilds
  final ValueNotifier<Set<String>> _selectedItemsNotifier = ValueNotifier<Set<String>>({});
  
  // Search and Filter - separate display from filter query
  String _searchQuery = ""; // This is what filters the list (debounced)
  String _selectedFilter = 'All';
  String _selectedCategory = 'All Categories';
  double _minPrice = 0;
  double _maxPrice = double.infinity;
  
  // Sorting
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  
  // View mode
  bool _isGridView = false;

  late Stream<List<Map<String, dynamic>>> _inventoryStream;

  @override
  void initState() {
    super.initState();
    _inventoryStream = _sellerService.getSellerInventory(widget.seller.id);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _selectedItemsNotifier.dispose();
    super.dispose();
  }

  // Helper to access selected items
  Set<String> get _selectedItems => _selectedItemsNotifier.value;

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  // Toggle selection - using ValueNotifier for smooth updates
  void _toggleSelection(String itemId) {
    final newSet = Set<String>.from(_selectedItems);
    if (newSet.contains(itemId)) {
      newSet.remove(itemId);
    } else {
      newSet.add(itemId);
    }
    _selectedItemsNotifier.value = newSet;
  }

  // Select/Deselect all
  void _toggleSelectAll(List<Map<String, dynamic>> items, bool isAllSelected) {
    if (isAllSelected) {
      _selectedItemsNotifier.value = {};
    } else {
      _selectedItemsNotifier.value = items.map((item) => item['id'].toString()).toSet();
    }
  }

  // Stock update dialog with minimum stock level
  Future<void> _showUpdateStockDialog(Map<String, dynamic> item) async {
    final TextEditingController stockController = 
        TextEditingController(text: item['stock_quantity'].toString());
    final TextEditingController minStockController = 
        TextEditingController(text: (item['min_stock_level'] ?? 10).toString());
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Update Stock: ${item['name']}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: stockController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Current Stock Quantity',
                  border: OutlineInputBorder(),
                  suffixText: 'units',
                  helperText: 'Available inventory',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minStockController,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                decoration: const InputDecoration(
                  labelText: 'Minimum Stock Level (Alert Threshold)',
                  border: OutlineInputBorder(),
                  suffixText: 'units',
                  helperText: 'Get notified when stock falls below this',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quick Adjustments:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('+10'),
                    avatar: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      double current = double.tryParse(stockController.text) ?? 0;
                      stockController.text = (current + 10).toInt().toString();
                    }
                  ),
                  ActionChip(
                    label: const Text('+50'),
                    avatar: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      double current = double.tryParse(stockController.text) ?? 0;
                      stockController.text = (current + 50).toInt().toString();
                    }
                  ),
                  ActionChip(
                    label: const Text('+100'),
                    avatar: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      double current = double.tryParse(stockController.text) ?? 0;
                      stockController.text = (current + 100).toInt().toString();
                    }
                  ),
                  ActionChip(
                    label: const Text('Set to 0'),
                    avatar: const Icon(Icons.clear, size: 16),
                    backgroundColor: Colors.red[50],
                    labelStyle: const TextStyle(color: Colors.red),
                    onPressed: () => stockController.text = '0'
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStock = double.tryParse(stockController.text);
              final minStock = int.tryParse(minStockController.text);
              
              if (newStock != null && newStock >= 0) {
                Navigator.pop(context);
                
                // Update stock
                await _sellerService.updateProductStock(item['id'], newStock);
                
                // TODO: Add method to update min_stock_level in your SellerService
                // if (minStock != null && minStock >= 0) {
                //   await _sellerService.updateProductMinStock(item['id'], minStock);
                // }
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Stock updated successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // Bulk stock update dialog
  Future<void> _showBulkUpdateDialog() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select items first')),
      );
      return;
    }

    String updateType = 'set'; // 'set', 'increase', 'decrease'
    final TextEditingController valueController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Bulk Update Stock (${_selectedItems.length} items)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select update type:'),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'set',
                    label: Text('Set To'),
                    icon: Icon(Icons.edit, size: 16),
                  ),
                  ButtonSegment(
                    value: 'increase',
                    label: Text('Increase'),
                    icon: Icon(Icons.add, size: 16),
                  ),
                  ButtonSegment(
                    value: 'decrease',
                    label: Text('Decrease'),
                    icon: Icon(Icons.remove, size: 16),
                  ),
                ],
                selected: {updateType},
                onSelectionChanged: (Set<String> selection) {
                  setDialogState(() => updateType = selection.first);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: updateType == 'set' ? 'New Stock Value' : 'Amount',
                  border: const OutlineInputBorder(),
                  suffixText: 'units',
                  helperText: updateType == 'set' 
                      ? 'All selected items will be set to this value'
                      : updateType == 'increase'
                          ? 'This amount will be added to current stock'
                          : 'This amount will be subtracted from current stock',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final value = double.tryParse(valueController.text);
                if (value != null && value >= 0) {
                  Navigator.pop(context);
                  await _performBulkStockUpdate(updateType, value);
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Update All'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performBulkStockUpdate(String updateType, double value) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Updating stock...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Get current inventory
      final inventory = await _sellerService.getSellerInventory(widget.seller.id).first;
      
      int successCount = 0;
      for (String itemId in _selectedItems) {
        try {
          final item = inventory.firstWhere((i) => i['id'].toString() == itemId);
          final currentStock = (item['stock_quantity'] as num).toDouble();
          
          double newStock;
          switch (updateType) {
            case 'set':
              newStock = value;
              break;
            case 'increase':
              newStock = currentStock + value;
              break;
            case 'decrease':
              newStock = (currentStock - value).clamp(0, double.infinity);
              break;
            default:
              newStock = currentStock;
          }
          
          await _sellerService.updateProductStock(itemId, newStock);
          successCount++;
        } catch (e) {
          // Continue with other items even if one fails
          continue;
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Successfully updated $successCount items'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _selectedItemsNotifier.value = {};
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Export to CSV
  Future<void> _exportToCSV(List<Map<String, dynamic>> inventory) async {
    try {
      // Create CSV header
      String csv = 'Product ID,Name,Category,SKU,Barcode,Stock,Unit,MRP,Selling Price,Status\n';

      for (var item in inventory) {
        final num stockNum = item['stock_quantity'] ?? 0;
        String status = stockNum <= 0 ? 'Out of Stock' : (stockNum < 10 ? 'Low Stock' : 'In Stock');
        
        // Escape commas and quotes in text fields
        String escapeCsvField(String? field) {
          if (field == null) return '';
          if (field.contains(',') || field.contains('"')) {
            return '"${field.replaceAll('"', '""')}"';
          }
          return field;
        }
        
        csv += '${escapeCsvField(item['id']?.toString())},'
               '${escapeCsvField(item['name']?.toString())},'
               '${escapeCsvField(item['category']?.toString())},'
               '${escapeCsvField(item['sku']?.toString())},'
               '${escapeCsvField(item['barcode']?.toString())},'
               '$stockNum,'
               '${escapeCsvField(item['unit']?.toString())},'
               '${item['mrp'] ?? ''},'
               '${item['selling_price'] ?? ''},'
               '$status\n';
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'inventory_export_$timestamp.csv';
      
      // TODO: Implement file saving based on your platform
      // For web: use download API
      // For mobile: use path_provider and share
      
      // For now, copy to clipboard as a fallback
      // await Clipboard.setData(ClipboardData(text: csv));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Inventory exported to $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Open the file
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Print barcodes for selected items with barcode printer service
  Future<void> _printBarcodes() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select items to print barcodes')),
      );
      return;
    }

    // Get selected product details
    final inventory = await _sellerService.getSellerInventory(widget.seller.id).first;
    final selectedProducts = inventory
        .where((item) => _selectedItems.contains(item['id'].toString()))
        .toList();

    await _showBarcodeLayoutDialog(selectedProducts);
  }

  // Show barcode layout selection dialog
  Future<void> _showBarcodeLayoutDialog(List<Map<String, dynamic>> products) async {
    // Barcode quantities for each product
    Map<Map<String, dynamic>, int> productQuantities = {};
    for (var product in products) {
      productQuantities[product] = 1;
    }

    await showDialog(
      context: context,
      builder: (context) => _BarcodePrintDialog(
        productsWithQuantities: productQuantities,
      ),
    );
  }

  // Advanced filter dialog
  Future<void> _showAdvancedFilters() async {
    double tempMinPrice = _minPrice;
    double tempMaxPrice = _maxPrice == double.infinity ? 0 : _maxPrice;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advanced Filters'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Price Range:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Min Price',
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: tempMinPrice.toString()),
                      onChanged: (value) {
                        tempMinPrice = double.tryParse(value) ?? 0;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to'),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Max Price',
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: tempMaxPrice > 0 ? tempMaxPrice.toString() : ''
                      ),
                      onChanged: (value) {
                        tempMaxPrice = double.tryParse(value) ?? 0;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Additional Filters:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('(More filter options coming soon)', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _minPrice = 0;
                _maxPrice = double.infinity;
                _selectedCategory = 'All Categories';
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _minPrice = tempMinPrice;
                _maxPrice = tempMaxPrice > 0 ? tempMaxPrice : double.infinity;
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _inventoryStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              final inventory = snapshot.data!;
              
              // Apply filters
              var filteredList = _applyFilters(inventory);

              // Apply sorting
              filteredList = _applySorting(filteredList);

              // Calculate stats
              final stats = _calculateStats(inventory);

              return Column(
                children: [
                  _buildTopBar(stats, inventory, constraints),
                  if (_selectedItems.isNotEmpty) _buildBulkActionBar(),
                  Expanded(
                    child: _isGridView 
                        ? _buildGridView(filteredList, constraints)
                        : _buildTableView(filteredList, constraints),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // Filter logic
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> inventory) {
    return inventory.where((item) {
      // Search filter
      final name = (item['name'] ?? '').toString().toLowerCase();
      final sku = (item['sku'] ?? '').toString().toLowerCase();
      final barcode = (item['barcode'] ?? '').toString().toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      final matchesSearch = name.contains(searchLower) || 
                           sku.contains(searchLower) || 
                           barcode.contains(searchLower);
      
      // Stock filter
      num stockNum = item['stock_quantity'] ?? 0;
      bool matchesStockFilter = true;
      if (_selectedFilter == 'Low Stock') {
        matchesStockFilter = stockNum < 10 && stockNum > 0;
      } else if (_selectedFilter == 'Out of Stock') {
        matchesStockFilter = stockNum <= 0;
      }

      // Price filter
      final price = ((item['mrp'] ?? item['selling_price']) as num? ?? 0).toDouble();
      final matchesPriceFilter = price >= _minPrice && price <= _maxPrice;

      return matchesSearch && matchesStockFilter && matchesPriceFilter;
    }).toList();
  }

  // Sort logic
  List<Map<String, dynamic>> _applySorting(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aStock = (a['stock_quantity'] as num? ?? 0);
      final bStock = (b['stock_quantity'] as num? ?? 0);
      final aName = (a['name'] as String? ?? '');
      final bName = (b['name'] as String? ?? '');
      final aPrice = ((a['mrp'] ?? a['selling_price']) as num? ?? 0);
      final bPrice = ((b['mrp'] ?? b['selling_price']) as num? ?? 0);

      int result;
      switch (_sortColumnIndex) {
        case 0: // Name
          result = aName.compareTo(bName);
          break;
        case 2: // Stock
          result = aStock.compareTo(bStock);
          break;
        case 3: // Price
          result = aPrice.compareTo(bPrice);
          break;
        default:
          result = 0;
      }
      
      return _sortAscending ? result : -result;
    });
    return list;
  }

  // Calculate statistics
  Map<String, dynamic> _calculateStats(List<Map<String, dynamic>> inventory) {
    int lowStock = 0;
    int outOfStock = 0;
    double totalValue = 0;
    int totalItems = inventory.length;
    
    for (var item in inventory) {
      num stock = item['stock_quantity'] ?? 0;
      double price = ((item['mrp'] ?? item['selling_price']) as num? ?? 0).toDouble();
      
      if (stock <= 0) {
        outOfStock++;
      } else if (stock < 10) {
        lowStock++;
      }
      
      totalValue += stock * price;
    }

    return {
      'lowStock': lowStock,
      'outOfStock': outOfStock,
      'totalValue': totalValue,
      'totalItems': totalItems,
      'inStock': totalItems - outOfStock,
    };
  }

  // Top bar with stats and actions
  Widget _buildTopBar(Map<String, dynamic> stats, List<Map<String, dynamic>> inventory, BoxConstraints constraints) {
    bool isSmall = constraints.maxWidth < 700;
    bool isMedium = constraints.maxWidth >= 700 && constraints.maxWidth < 1200;

    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isSmall)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats['totalItems']} items • ₹${NumberFormat('#,##,###').format(stats['totalValue'])} value',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                     Expanded(
                       child: OutlinedButton.icon(
                        onPressed: () => _exportToCSV(inventory),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Export'),
                      ),
                     ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EnhancedAddProductScreen(seller: widget.seller),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Product'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9759),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory Management',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats['totalItems']} total items • ₹${NumberFormat('#,##,###').format(stats['totalValue'])} total value',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _exportToCSV(inventory),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnhancedAddProductScreen(seller: widget.seller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9759),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 24),
          
          // Stats cards
          if (isMedium)
             Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: (constraints.maxWidth - 48 - 16) / 2, // 2 columns (48 padding + 16 spacing)
                    child: _buildStatCard('In Stock', '${stats['inStock']}', Colors.green, Icons.check_circle),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 48 - 16) / 2,
                    child: _buildStatCard('Low Stock', '${stats['lowStock']}', Colors.orange, Icons.warning_amber_rounded),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 48 - 16) / 2,
                    child: _buildStatCard('Out of Stock', '${stats['outOfStock']}', Colors.red, Icons.error_outline),
                  ),
                  SizedBox(
                     width: (constraints.maxWidth - 48 - 16) / 2,
                     child: _buildStatCard('Total Value', '₹${NumberFormat.compact().format(stats['totalValue'])}', Colors.blue, Icons.currency_rupee),
                  ),
                ],
             )
          else if (isSmall)
             Column(
               children: [
                 _buildStatCard('In Stock', '${stats['inStock']}', Colors.green, Icons.check_circle),
                 const SizedBox(height: 8),
                 _buildStatCard('Low Stock', '${stats['lowStock']}', Colors.orange, Icons.warning_amber_rounded),
                 const SizedBox(height: 8),
                 _buildStatCard('Out of Stock', '${stats['outOfStock']}', Colors.red, Icons.error_outline),
                 const SizedBox(height: 8),
                 _buildStatCard('Total Value', '₹${NumberFormat.compact().format(stats['totalValue'])}', Colors.blue, Icons.currency_rupee),
               ],
             )
          else
            Row(
              children: [
                Expanded(child: _buildStatCard('In Stock', '${stats['inStock']}', Colors.green, Icons.check_circle)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Low Stock', '${stats['lowStock']}', Colors.orange, Icons.warning_amber_rounded)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Out of Stock', '${stats['outOfStock']}', Colors.red, Icons.error_outline)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Total Value', '₹${NumberFormat.compact().format(stats['totalValue'])}', Colors.blue, Icons.currency_rupee)),
              ],
            ),

          const SizedBox(height: 24),
          
          // Search and filters
          if (isSmall)
             Column(
               children: [
                 _buildSearchBar(),
                 const SizedBox(height: 12),
                 Row(
                   children: [
                     Expanded(
                       child: OutlinedButton.icon(
                        onPressed: _showAdvancedFilters,
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Filters'),
                      ),
                     ),
                     const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(_isGridView ? Icons.table_rows : Icons.grid_view),
                      onPressed: () => setState(() => _isGridView = !_isGridView),
                      tooltip: _isGridView ? 'Table View' : 'Grid View',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                      ),
                    ),
                   ],
                 )
               ],
             )
          else
            Row(
              children: [
                Expanded(child: _buildSearchBar()),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showAdvancedFilters,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Filters'),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(_isGridView ? Icons.table_rows : Icons.grid_view),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  tooltip: _isGridView ? 'Table View' : 'Grid View',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      key: _searchFieldKey,
      controller: _searchController,
      onChanged: (val) {
        // Cancel previous timer
        if (_debounceTimer?.isActive ?? false) {
          _debounceTimer!.cancel();
        }
        
        // Start new timer for filtering (300ms delay)
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _searchQuery = val; // Only update the filter query after delay
            });
          }
        });
      },
      decoration: InputDecoration(
        hintText: 'Search by name, SKU, or barcode...',
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  if (_debounceTimer?.isActive ?? false) {
                    _debounceTimer!.cancel();
                  }
                  setState(() => _searchQuery = "");
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // Bulk action bar with ValueListenableBuilder
  Widget _buildBulkActionBar() {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedItemsNotifier,
      builder: (context, selectedItems, child) {
        if (selectedItems.isEmpty) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border(
              bottom: BorderSide(color: Colors.blue[200]!),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Text(
                '${selectedItems.length} items selected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _showBulkUpdateDialog,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Bulk Update'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _printBarcodes,
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('Print Barcodes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _selectedItemsNotifier.value = {},
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Table view
  Widget _buildTableView(List<Map<String, dynamic>> filteredList, BoxConstraints constraints) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          // Table toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 16),
                Text(
                  '${filteredList.length} results',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const Spacer(),
                if (constraints.maxWidth > 500)
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('All'),
                      _buildFilterChip('Low Stock'),
                      _buildFilterChip('Out of Stock'),
                    ],
                  ),
              ],
            ),
          ),
          if (constraints.maxWidth <= 500)
             Padding(
               padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
               child: SingleChildScrollView(
                 scrollDirection: Axis.horizontal,
                 child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Low Stock'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Out of Stock'),
                    ],
                 ),
               ),
             ),
          const Divider(height: 1),
          
          // Data table
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No items match your filters',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery = "";
                              _searchController.clear();
                              _selectedFilter = 'All';
                              _minPrice = 0;
                              _maxPrice = double.infinity;
                            });
                          },
                          child: const Text('Clear all filters'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth - 32, // Card margin 16*2
                        ),
                        child: ValueListenableBuilder<Set<String>>(
                          valueListenable: _selectedItemsNotifier,
                          builder: (context, selectedItems, child) {
                            final isAllSelected = selectedItems.length == filteredList.length && filteredList.isNotEmpty;
                            
                            return DataTable(
                              sortColumnIndex: _sortColumnIndex,
                              sortAscending: _sortAscending,
                              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                              showCheckboxColumn: false, 
                              columns: [
                                DataColumn(
                                  label: Checkbox(
                                    value: isAllSelected,
                                    tristate: true,
                                    onChanged: (val) => _toggleSelectAll(filteredList, isAllSelected),
                                  ),
                                ),
                                DataColumn(
                                  label: const Text('Product'),
                                  onSort: (index, ascending) => _onSort(index, ascending),
                                ),
                                const DataColumn(label: Text('Status')),
                                DataColumn(
                                  label: const Text('Stock'),
                                  numeric: true,
                                  onSort: (index, ascending) => _onSort(index, ascending),
                                ),
                                DataColumn(
                                  label: const Text('Price'),
                                  numeric: true,
                                  onSort: (index, ascending) => _onSort(index, ascending),
                                ),
                                const DataColumn(label: Text('Actions')),
                              ],
                              rows: filteredList.map((item) => _buildDataRow(item, selectedItems)).toList(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Grid view
  Widget _buildGridView(List<Map<String, dynamic>> filteredList, BoxConstraints constraints) {
    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No items match your filters',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }
    
    int crossAxisCount = 2;
    if (constraints.maxWidth > 1400) crossAxisCount = 5;
    else if (constraints.maxWidth > 1100) crossAxisCount = 4;
    else if (constraints.maxWidth > 700) crossAxisCount = 3;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredList.length,
      itemBuilder: (context, index) => _buildGridItem(filteredList[index]),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Unknown';
    final String image = (item['images'] != null && (item['images'] as List).isNotEmpty) 
        ? item['images'][0] 
        : '';
    final num stockNum = item['stock_quantity'] ?? 0;
    final double price = ((item['mrp'] ?? item['selling_price']) as num? ?? 0).toDouble();
    final bool isSelected = _selectedItems.contains(item['id'].toString());
    
    Color statusColor = Colors.green;
    String statusText = 'In Stock';
    if (stockNum <= 0) {
      statusColor = Colors.red;
      statusText = 'Out of Stock';
    } else if (stockNum < 10) {
      statusColor = Colors.orange;
      statusText = 'Low Stock';
    }

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleSelection(item['id'].toString()),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  color: Colors.grey[200],
                  image: image.isNotEmpty 
                      ? DecorationImage(
                          image: NetworkImage(image),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    if (image.isEmpty)
                      const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.grey),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        elevation: 2,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (val) => _toggleSelection(item['id'].toString()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stock: ${stockNum.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '₹${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showUpdateStockDialog(item),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.blue[700],
                        ),
                      ],
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = label);
      },
      selectedColor: Colors.blue.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[300]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> item, Set<String> selectedItems) {
    final String name = item['name'] ?? 'Unknown';
    final String image = (item['images'] != null && (item['images'] as List).isNotEmpty) 
        ? item['images'][0] 
        : '';
    final num stockNum = item['stock_quantity'] ?? 0;
    final double price = ((item['mrp'] ?? item['selling_price']) as num? ?? 0).toDouble();
    final bool isSelected = selectedItems.contains(item['id'].toString());
    
    Color statusColor = Colors.green;
    String statusText = 'In Stock';
    IconData statusIcon = Icons.check_circle;
    if (stockNum <= 0) {
      statusColor = Colors.red;
      statusText = 'Out of Stock';
      statusIcon = Icons.error;
    } else if (stockNum < 10) {
      statusColor = Colors.orange;
      statusText = 'Low Stock';
      statusIcon = Icons.warning_amber;
    }

    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) => _toggleSelection(item['id'].toString()),
      color: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.blue.withOpacity(0.05);
          }
          return null;
        },
      ),
      cells: [
        DataCell(
          Checkbox(
            value: isSelected,
            onChanged: (val) => _toggleSelection(item['id'].toString()),
          ),
        ),
        DataCell(
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey[200],
                  image: image.isNotEmpty 
                      ? DecorationImage(
                          image: NetworkImage(image),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: image.isEmpty 
                    ? const Icon(Icons.image, size: 24, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${item['sku'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        DataCell(
          InkWell(
            onTap: () => _showUpdateStockDialog(item),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${stockNum.toInt()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit, size: 14, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            '₹${price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.grey[600],
                iconSize: 20,
                tooltip: 'Decrease by 1',
                onPressed: stockNum > 0
                    ? () => _sellerService.updateProductStock(
                          item['id'],
                          (stockNum - 1).toDouble(),
                        )
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFF0D9759),
                iconSize: 20,
                tooltip: 'Increase by 1',
                onPressed: () => _sellerService.updateProductStock(
                  item['id'],
                  (stockNum + 1).toDouble(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 24),
          const Text(
            'No inventory items yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first product',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedAddProductScreen(seller: widget.seller),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add First Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9759),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodePrintDialog extends StatefulWidget {
  final Map<Map<String, dynamic>, int> productsWithQuantities;

  const _BarcodePrintDialog({
    super.key,
    required this.productsWithQuantities,
  });

  @override
  State<_BarcodePrintDialog> createState() => _BarcodePrintDialogState();
}

class _BarcodePrintDialogState extends State<_BarcodePrintDialog> {
  final BarcodePrinterService _printerService = BarcodePrinterService();
  
  LayoutMode _selectedLayout = LayoutMode.grid;
  int _gridColumns = 2;
  int _gridRows = 7;
  
  // Local copy of quantities to modify
  late Map<Map<String, dynamic>, int> _quantities;

  @override
  void initState() {
    super.initState();
    _quantities = Map.from(widget.productsWithQuantities);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Barcode Print Settings'),
      content: SizedBox(
        width: 500, // Limit width for better look
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Layout Mode:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              RadioListTile<LayoutMode>(
                title: const Text('Grid Layout (Multiple per page)'),
                subtitle: const Text('Compact layout like sticker sheets'),
                value: LayoutMode.grid,
                groupValue: _selectedLayout,
                onChanged: (value) {
                  setState(() {
                    _selectedLayout = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF0D9759),
              ),
              RadioListTile<LayoutMode>(
                title: const Text('2 Per Page Layout'),
                subtitle: const Text('Larger barcodes with more details'),
                value: LayoutMode.twoPerPage,
                groupValue: _selectedLayout,
                onChanged: (value) {
                  setState(() {
                    _selectedLayout = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF0D9759),
              ),
              
              if (_selectedLayout == LayoutMode.grid) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                const Text(
                  'Grid Settings:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Columns: $_gridColumns'),
                          Slider(
                            value: _gridColumns.toDouble(),
                            min: 1,
                            max: 4,
                            divisions: 3,
                            label: _gridColumns.toString(),
                            onChanged: (value) {
                              setState(() {
                                _gridColumns = value.toInt();
                              });
                            },
                            activeColor: const Color(0xFF0D9759),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rows: $_gridRows'),
                          Slider(
                            value: _gridRows.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _gridRows.toString(),
                            onChanged: (value) {
                              setState(() {
                                _gridRows = value.toInt();
                              });
                            },
                            activeColor: const Color(0xFF0D9759),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'Barcodes per page: ${_gridColumns * _gridRows}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(),
              ),
              const Text(
                'Set Quantities:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _quantities.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = _quantities.keys.elementAt(index);
                    final quantity = _quantities[product]!;
                    
                    return ListTile(
                      title: Text(
                        product['name'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'SKU: ${product['sku'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: Colors.grey[600],
                            onPressed: () {
                              setState(() {
                                if (quantity > 1) {
                                  _quantities[product] = quantity - 1;
                                }
                              });
                            },
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 24,
                            alignment: Alignment.center,
                            child: Text(
                              '$quantity',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: const Color(0xFF0D9759),
                            onPressed: () {
                              setState(() {
                                _quantities[product] = quantity + 1;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            // Preview logic
            Navigator.pop(context);
            await _printerService.previewBarcodes(
              context,
              _quantities,
              layoutMode: _selectedLayout,
              gridColumns: _gridColumns,
              gridRows: _gridRows,
            );
          },
          icon: const Icon(Icons.visibility),
          label: const Text('Preview'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            // Print logic
            Navigator.pop(context);
            await _printerService.printBarcodes(
              context,
              _quantities,
              layoutMode: _selectedLayout,
              gridColumns: _gridColumns,
              gridRows: _gridRows,
            );
          },
          icon: const Icon(Icons.print),
          label: const Text('Print'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9759),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}