import 'package:flutter/material.dart';
import '../models/inventory_filter.dart';

/// Filter bar widget for inventory management
class FilterBar extends StatelessWidget {
  final InventoryFilter currentFilter;
  final Function(InventoryFilter) onFilterChanged;
  final List<String> categories;

  const FilterBar({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active filters description
          if (currentFilter.hasActiveFilters) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    currentFilter.getFilterDescription(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    onFilterChanged(InventoryFilter.defaults());
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Stock Status Filter
                _buildFilterChip(
                  label: 'Stock Status',
                  value: _getStockStatusLabel(currentFilter.stockStatus),
                  icon: Icons.inventory,
                  onTap: () => _showStockStatusPicker(context),
                ),
                const SizedBox(width: 8),
                
                // Category Filter
                if (categories.isNotEmpty)
                  _buildFilterChip(
                    label: 'Category',
                    value: currentFilter.category ?? 'All',
                    icon: Icons.category,
                    onTap: () => _showCategoryPicker(context),
                  ),
                const SizedBox(width: 8),
                
                // Sort Filter
                _buildFilterChip(
                  label: 'Sort',
                  value: _getSortLabel(currentFilter.sortBy),
                  icon: currentFilter.sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  onTap: () => _showSortPicker(context),
                ),
                const SizedBox(width: 8),
                
                // Price Range (optional)
                _buildFilterChip(
                  label: 'Price',
                  value: 'Range',
                  icon: Icons.attach_money,
                  onTap: () => _showPriceRangePicker(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  String _getStockStatusLabel(String? status) {
    switch (status) {
      case 'in_stock':
        return 'In Stock';
      case 'low_stock':
        return 'Low Stock';
      case 'out_of_stock':
        return 'Out of Stock';
      default:
        return 'All';
    }
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'name':
        return 'Name';
      case 'price':
        return 'Price';
      case 'stock':
        return 'Stock';
      case 'date':
        return 'Date';
      default:
        return 'Date';
    }
  }

  void _showStockStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Stock Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...[
                ('all', 'All Products', Icons.inventory_2),
                ('in_stock', 'In Stock', Icons.check_circle),
                ('low_stock', 'Low Stock', Icons.warning_amber),
                ('out_of_stock', 'Out of Stock', Icons.remove_circle),
              ].map((item) {
                return ListTile(
                  leading: Icon(item.$3, color: Colors.deepOrange),
                  title: Text(item.$2),
                  selected: currentFilter.stockStatus == item.$1,
                  onTap: () {
                    onFilterChanged(
                      currentFilter.copyWith(stockStatus: item.$1),
                    );
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Colors.deepOrange),
                title: const Text('All Categories'),
                selected: currentFilter.category == null,
                onTap: () {
                  onFilterChanged(
                    currentFilter.copyWith(category: null),
                  );
                  Navigator.pop(context);
                },
              ),
              ...categories.map((category) {
                return ListTile(
                  leading: const Icon(Icons.category, color: Colors.deepOrange),
                  title: Text(category),
                  selected: currentFilter.category == category,
                  onTap: () {
                    onFilterChanged(
                      currentFilter.copyWith(category: category),
                    );
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showSortPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort Products',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...[
                ('name', 'Name (A-Z)', Icons.sort_by_alpha),
                ('price', 'Price', Icons.attach_money),
                ('stock', 'Stock Quantity', Icons.inventory),
                ('date', 'Date Added', Icons.calendar_today),
              ].map((item) {
                return ListTile(
                  leading: Icon(item.$3, color: Colors.deepOrange),
                  title: Text(item.$2),
                  selected: currentFilter.sortBy == item.$1,
                  trailing: currentFilter.sortBy == item.$1
                      ? Icon(
                          currentFilter.sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    // Toggle direction if same sort field
                    final newAscending = currentFilter.sortBy == item.$1
                        ? !currentFilter.sortAscending
                        : false;
                    
                    onFilterChanged(
                      currentFilter.copyWith(
                        sortBy: item.$1,
                        sortAscending: newAscending,
                      ),
                    );
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showPriceRangePicker(BuildContext context) {
    double minPrice = currentFilter.minPrice ?? 0;
    double maxPrice = currentFilter.maxPrice ?? 1000;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Price Range'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₹${minPrice.toInt()} - ₹${maxPrice.toInt()}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Min Price',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: minPrice.toInt().toString(),
                          ),
                          onChanged: (val) {
                            setState(() {
                              minPrice = double.tryParse(val) ?? 0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Max Price',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: maxPrice.toInt().toString(),
                          ),
                          onChanged: (val) {
                            setState(() {
                              maxPrice = double.tryParse(val) ?? 1000;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    onFilterChanged(
                      currentFilter.copyWith(
                        minPrice: null,
                        maxPrice: null,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onFilterChanged(
                      currentFilter.copyWith(
                        minPrice: minPrice,
                        maxPrice: maxPrice,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
