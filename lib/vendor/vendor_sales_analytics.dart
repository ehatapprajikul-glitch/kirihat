import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class VendorSalesAnalytics extends StatefulWidget {
  const VendorSalesAnalytics({super.key});

  @override
  State<VendorSalesAnalytics> createState() => _VendorSalesAnalyticsState();
}

class _VendorSalesAnalyticsState extends State<VendorSalesAnalytics> {
  final String vendorId = FirebaseAuth.instance.currentUser!.uid;
  String _selectedPeriod = 'Today';
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];

  DateTime get _startDate {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'All Time':
      default:
        return DateTime(2020, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        backgroundColor: Colors.green[100],
      ),
      body: Column(
        children: [
          // Period Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text(
                  'Period: ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: _periods.map((period) {
                      return ButtonSegment(value: period, label: Text(period));
                    }).toList(),
                    selected: {_selectedPeriod},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() => _selectedPeriod = selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Analytics Cards
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('vendor_id', isEqualTo: vendorId)
                  // .where('created_at', isGreaterThanOrEqualTo: _startDate) // Client-side filtering
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Filter by date range manually
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  Timestamp? timestamp = data['created_at'];
                  if (timestamp == null) return false;
                  return timestamp.toDate().isAfter(_startDate.subtract(const Duration(seconds: 1)));
                }).toList();

                if (filteredDocs.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildAnalyticsDashboard(filteredDocs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsDashboard(List<QueryDocumentSnapshot> orders) {
    // Calculate metrics
    int totalOrders = orders.length;
    int deliveredOrders = orders.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'delivered';
    }).length;
    
    int pendingOrders = orders.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return ['pending', 'accepted', 'preparing', 'out_for_delivery'].contains(data['status']);
    }).length;

    double totalRevenue = 0;
    Map<String, int> productSales = {};
    Map<String, double> productRevenue = {};

    for (var doc in orders) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'delivered') {
        double orderTotal = (data['total_amount'] ?? 0).toDouble();
        totalRevenue += orderTotal;

        // Track product-wise sales
        List items = data['items'] ?? [];
        for (var item in items) {
          String productName = item['product_name'] ?? 'Unknown';
          int quantity = item['quantity'] ?? 0;
          double price = (item['price'] ?? 0).toDouble();

          productSales[productName] = (productSales[productName] ?? 0) + quantity;
          productRevenue[productName] = (productRevenue[productName] ?? 0) + (price * quantity);
        }
      }
    }

    // Get top selling products
    var sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Orders',
                  totalOrders.toString(),
                  Icons.shopping_bag,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Delivered',
                  deliveredOrders.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Pending',
                  pendingOrders.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Revenue',
                  '₹${totalRevenue.toStringAsFixed(2)}',
                  Icons.currency_rupee,
                  const Color(0xFF0D9759),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top Selling Products
          const Text(
            'Top Selling Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (sortedProducts.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                'No product sales yet',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ...sortedProducts.take(10).map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      '${sortedProducts.indexOf(entry) + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D9759),
                      ),
                    ),
                  ),
                  title: Text(entry.key),
                  subtitle: Text('${entry.value} units sold'),
                  trailing: Text(
                    '₹${(productRevenue[entry.key] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9759),
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No sales data for ${_selectedPeriod.toLowerCase()}',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
