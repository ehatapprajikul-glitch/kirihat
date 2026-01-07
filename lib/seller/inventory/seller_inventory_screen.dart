import 'package:flutter/material.dart';
import '../../models/seller_model.dart';
import '../../services/seller_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          final filteredInventory = inventory.where((item) {
            final name = (item['product_name'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          // Calculate Stats
          int totalStock = 0;
          int lowStockCount = 0;
          int outOfStockCount = 0;

          for (var item in inventory) {
             // Handle numeric types safely (dynamic, int, double)
             num stockNum = item['stock_quantity'] ?? 0;
             double stock = stockNum.toDouble();
             
             totalStock += stock.toInt();
             if (stock <= 0) outOfStockCount++;
             else if (stock < 10) lowStockCount++;
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatsRow(inventory.length, lowStockCount, outOfStockCount),
                const SizedBox(height: 24),
                _buildSearchBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredInventory.length,
                    itemBuilder: (context, index) {
                      return _buildInventoryItem(filteredInventory[index]);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No inventory found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add active products to manage inventory',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          'Inventory Management',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () {
            // Can navigate to Add Product or Quick Add
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Stock'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9759),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(int totalItems, int lowStock, int outOfStock) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Items', '$totalItems', Icons.list, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Low Stock', '$lowStock', Icons.warning_amber, Colors.orange)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Out of Stock', '$outOfStock', Icons.remove_circle_outline, Colors.red)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'Search products...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    final String name = item['product_name'] ?? 'Unknown Product';
    final String unit = item['unit'] ?? 'unit';
    // Handle numeric types safely
    num stockNum = item['stock_quantity'] ?? 0;
    double stock = stockNum.toDouble();
    
    // Determine status
    Color statusColor = Colors.green;
    String statusText = 'In Stock';
    
    if (stock <= 0) {
      statusColor = Colors.red;
      statusText = 'Out of Stock';
    } else if (stock < 10) {
      statusColor = Colors.orange;
      statusText = 'Low Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: (item['images'] != null && (item['images'] as List).isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(item['images'][0]),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (item['images'] == null || (item['images'] as List).isEmpty)
                  ? const Icon(Icons.image, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Unit: $unit', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            // Stock Controls
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildStockButton(Icons.remove, () => _updateStock(item['id'], stock - 1)),
                  Container(
                    width: 60,
                    alignment: Alignment.center,
                    child: Text(
                      '${stock.toInt()}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildStockButton(Icons.add, () => _updateStock(item['id'], stock + 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  Future<void> _updateStock(String productId, double newQuantity) async {
    if (newQuantity < 0) return;
    await _sellerService.updateProductStock(productId, newQuantity);
  }
}
