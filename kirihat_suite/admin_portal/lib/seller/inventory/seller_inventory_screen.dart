import 'package:flutter/material.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import '../products/enhanced_add_product_screen.dart';

class SellerInventoryScreen extends StatefulWidget {
  final SellerModel seller;

  const SellerInventoryScreen({super.key, required this.seller});

  @override
  State<SellerInventoryScreen> createState() => _SellerInventoryScreenState();
}

class _SellerInventoryScreenState extends State<SellerInventoryScreen> {
  final SellerService _sellerService = SellerService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = "";
  String _selectedFilter = 'All'; // 'All', 'Low Stock', 'Out of Stock'
  
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  // Stock update dialog
  Future<void> _showUpdateStockDialog(Map<String, dynamic> item) async {
    final TextEditingController stockController = 
        TextEditingController(text: item['stock_quantity'].toString());
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock: ${item['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stockController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Stock Quantity',
                border: OutlineInputBorder(),
                suffixText: 'units',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(label: const Text('+10'), onPressed: () {
                   double current = double.tryParse(stockController.text) ?? 0;
                   stockController.text = (current + 10).toInt().toString();
                }),
                ActionChip(label: const Text('+50'), onPressed: () {
                   double current = double.tryParse(stockController.text) ?? 0;
                   stockController.text = (current + 50).toInt().toString();
                }),
                ActionChip(label: const Text('Set to 0'), 
                  backgroundColor: Colors.red[50],
                  labelStyle: const TextStyle(color: Colors.red),
                  onPressed: () => stockController.text = '0'
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStock = double.tryParse(stockController.text);
              if (newStock != null && newStock >= 0) {
                 Navigator.pop(context);
                 await _sellerService.updateProductStock(item['id'], newStock);
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Stock updated successfully')),
                   );
                 }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Professional light grey background
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _sellerService.getSellerInventory(widget.seller.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final inventory = snapshot.data!;
          
          // 1. Filter
          var filteredList = inventory.where((item) {
            final name = (item['name'] ?? '').toString().toLowerCase();
            final matchesSearch = name.contains(_searchQuery.toLowerCase());
            
            num stockNum = item['stock_quantity'] ?? 0;
            
            bool matchesFilter = true;
            if (_selectedFilter == 'Low Stock') {
              matchesFilter = stockNum < 10 && stockNum > 0;
            } else if (_selectedFilter == 'Out of Stock') {
              matchesFilter = stockNum <= 0;
            }

            return matchesSearch && matchesFilter;
          }).toList();

          // 2. Sort
          filteredList.sort((a, b) {
            final aStock = (a['stock_quantity'] as num? ?? 0);
            final bStock = (b['stock_quantity'] as num? ?? 0);
            final aName = (a['name'] as String? ?? '');
            final bName = (b['name'] as String? ?? '');

            int result;
            if (_sortColumnIndex == 0) { // Name
              result = aName.compareTo(bName);
            } else if (_sortColumnIndex == 2) { // Stock
              result = aStock.compareTo(bStock);
            } else {
              result = 0;
            }
            
            return _sortAscending ? result : -result;
          });

          return Column(
            children: [
              _buildTopBar(inventory),
              Expanded(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      // Table Toolbar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 16),
                            Text('${filteredList.length} results', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            const Spacer(),
                            // Filter Chips
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
                      const Divider(height: 1),
                      // Data Table
                      Expanded(
                        child: SingleChildScrollView(
                           scrollDirection: Axis.vertical,
                           child: SingleChildScrollView(
                             scrollDirection: Axis.horizontal,
                             child: ConstrainedBox(
                               constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64),
                               child: DataTable(
                                 sortColumnIndex: _sortColumnIndex,
                                 sortAscending: _sortAscending,
                                 columns: [
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
                                   const DataColumn(label: Text('Actions')),
                                 ],
                                 rows: filteredList.map((item) => _buildDataRow(item)).toList(),
                               ),
                             ),
                           ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(List<Map<String, dynamic>> inventory) {
    // Stats
    int lowStock = 0;
    int outOfStock = 0;
    for (var item in inventory) {
       num stock = item['stock_quantity'] ?? 0;
       if (stock <= 0) outOfStock++;
       else if (stock < 10) lowStock++;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Inventory',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
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
                label: const Text('Add New Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
               Expanded(child: _buildHeaderSearch()),
               const SizedBox(width: 24),
               _buildStatBadge('Low Stock', lowStock, Colors.orange),
               const SizedBox(width: 16),
               _buildStatBadge('Out of Stock', outOfStock, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'Search by product name, SKU...',
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // More professional square-ish look
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
               Text('$count Items', style: TextStyle(fontSize: 13, color: color.withOpacity(0.8))),
            ],
          )
        ],
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
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[300]!),
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Unknown';
    final String image = (item['images'] != null && (item['images'] as List).isNotEmpty) 
        ? item['images'][0] 
        : '';
    final num stockNum = item['stock_quantity'] ?? 0;
    
    // Status Logic
    Color statusColor = Colors.green;
    String statusText = 'In Stock';
    if (stockNum <= 0) {
      statusColor = Colors.red;
      statusText = 'Out of Stock';
    } else if (stockNum < 10) {
      statusColor = Colors.orange;
      statusText = 'Low Stock';
    }

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[200],
                  image: image.isNotEmpty ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover) : null,
                ),
                child: image.isEmpty ? const Icon(Icons.image, size: 20, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                   Text('Unit: ${item['unit'] ?? 'N/A'}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             decoration: BoxDecoration(
               color: statusColor.withOpacity(0.1),
               borderRadius: BorderRadius.circular(4),
             ),
             child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        DataCell(
          InkWell(
            onTap: () => _showUpdateStockDialog(item),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text('${stockNum.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(width: 4),
                   Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              // Edit button removed as per user request (moved to Products tab)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline), 
                color: Colors.grey[600],
                iconSize: 20,
                tooltip: '-1 Stock',
                onPressed: () => _sellerService.updateProductStock(item['id'], (stockNum - 1).toDouble()),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline), 
                color: const Color(0xFF0D9759),
                iconSize: 20,
                tooltip: '+1 Stock',
                onPressed: () => _sellerService.updateProductStock(item['id'], (stockNum + 1).toDouble()),
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
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No inventory items found', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}
