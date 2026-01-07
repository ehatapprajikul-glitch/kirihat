import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsReports extends StatelessWidget {
  const AnalyticsReports({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics & Reports',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Platform performance overview and insights',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 32),

          // Overview Stats
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, orderSnapshot) {
              if (!orderSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var orders = orderSnapshot.data!.docs;
              int totalOrders = orders.length;
              double totalRevenue = orders.fold(0.0, (sum, doc) {
                var data = doc.data() as Map<String, dynamic>;
                return sum + ((data['total_amount'] ?? 0) as num).toDouble();
              });

              // Calculate today's stats
              DateTime now = DateTime.now();
              DateTime today = DateTime(now.year, now.month, now.day);
              
              var todayOrders = orders.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                Timestamp? createdAt = data['created_at'];
                if (createdAt != null) {
                  DateTime orderDate = createdAt.toDate();
                  return orderDate.isAfter(today);
                }
                return false;
              }).toList();

              double todayRevenue = todayOrders.fold(0.0, (sum, doc) {
                var data = doc.data() as Map<String, dynamic>;
                return sum + ((data['total_amount'] ?? 0) as num).toDouble();
              });

              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Revenue',
                      '₹${(totalRevenue / 1000).toStringAsFixed(1)}K',
                      Icons.attach_money,
                      Colors.green,
                      'All time',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Total Orders',
                      totalOrders.toString(),
                      Icons.shopping_cart,
                      Colors.blue,
                      'All time',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Today Revenue',
                      '₹${todayRevenue.toStringAsFixed(0)}',
                      Icons.today,
                      Colors.purple,
                      '${todayOrders.length} orders',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Avg Order Value',
                      totalOrders > 0 
                          ? '₹${(totalRevenue / totalOrders).toStringAsFixed(0)}'
                          : '₹0',
                      Icons.shopping_bag,
                      Colors.orange,
                      'Per order',
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // User Growth
          const Text(
            'User Growth',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = snapshot.data!.docs;
              int customers = users.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return (data['role'] ?? 'customer') == 'customer';
              }).length;

              int vendors = users.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return (data['role'] ?? 'customer') == 'vendor';
              }).length;

              int riders = users.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return (data['role'] ?? 'customer') == 'rider';
              }).length;

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildUserStat('Customers', customers, Colors.green),
                        _buildUserStat('Vendors', vendors, Colors.blue),
                        _buildUserStat('Riders', riders, Colors.orange),
                        _buildUserStat('Total Users', users.length, Colors.purple),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Top Products
          const Text(
            'Top Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No products')),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Price')),
                    DataColumn(label: Text('Stock')),
                  ],
                  rows: snapshot.data!.docs.take(10).map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return DataRow(
                      cells: [
                        DataCell(Text(data['name'] ?? 'N/A')),
                        DataCell(Text(data['category'] ?? 'N/A')),
                        DataCell(Text('₹${data['price'] ?? 0}')),
                        DataCell(Text('${data['stock_quantity'] ?? 0}')),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Export Button
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export to CSV feature coming soon!'),
                ),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Export Reports (CSV)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9759),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
