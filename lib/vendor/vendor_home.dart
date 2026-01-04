import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'my_listed_products.dart';
import 'vendor_sales_analytics.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Helper to format currency
  String formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(amount);
  }

  // Helper to check if date is today
  bool isToday(Timestamp? timestamp) {
    if (timestamp == null) return false;
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen width for responsive grid
    double width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 1200 ? 4 : (width > 800 ? 2 : 1);
    double childAspectRatio = width > 1200 ? 1.5 : (width > 800 ? 1.8 : 1.5);

    return SingleChildScrollView(
      child: Column(
        children: [
          // 1. DASHBOARD WELCOME HEADER (Replaces AppBar)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF512F), Color(0xFFDD2476)], 
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, ${currentUser?.displayName ?? 'Vendor'}!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Here's what's happening today.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // 2. DASHBOARD CONTENT
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, orderSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('vendor_id', isEqualTo: currentUser?.uid)
                    .snapshots(),
                builder: (context, productSnapshot) {
                  if (orderSnapshot.connectionState == ConnectionState.waiting ||
                      productSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(50.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Client-side filtering
                  var allOrders = orderSnapshot.data?.docs ?? [];
                  var vendorOrders = allOrders.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return data['vendor_id'] == currentUser?.uid ||
                        data['vendor_id'] == currentUser?.email;
                  }).toList();

                  var products = productSnapshot.data?.docs ?? [];

                  // Calculate Stats
                  double totalRevenue = 0;
                  double todayRevenue = 0;
                  int pendingOrders = 0;
                  for (var doc in vendorOrders) {
                    var data = doc.data() as Map<String, dynamic>;
                    double amount = (data['total_amount'] ?? 0).toDouble();
                    String status = data['status'] ?? 'Pending';
                    Timestamp? date = data['created_at'];

                    if (status != 'Cancelled') {
                      totalRevenue += amount;
                      if (isToday(date)) todayRevenue += amount;
                    }
                    if (status == 'Pending') pendingOrders++;
                  }

                  int totalProducts = products.length;
                  int lowStockCount = 0;
                  for (var doc in products) {
                    var data = doc.data() as Map<String, dynamic>;
                    int stock = data['stock_quantity'] ?? 0;
                    if (stock < 5) lowStockCount++;
                  }

                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // STATS GRID
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: childAspectRatio,
                          children: [
                            _buildStatCard("Today's Revenue", formatCurrency(todayRevenue), Icons.attach_money, [const Color(0xFF11998e), const Color(0xFF38ef7d)]),
                            _buildStatCard("Pending Orders", "$pendingOrders", Icons.shopping_bag, [const Color(0xFFFC466B), const Color(0xFF3F5EFB)]),
                            _buildStatCard("Active Products", "$totalProducts", Icons.inventory_2, [const Color(0xFFff9966), const Color(0xFFff5e62)]),
                            _buildStatCard("Total Sales", formatCurrency(totalRevenue), Icons.show_chart, [const Color(0xFF4568DC), const Color(0xFFB06AB3)]),
                          ],
                        ),
                        const SizedBox(height: 32),

                        if (lowStockCount > 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Low Stock Alert", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                      Text("$lowStockCount products need restocking soon.", style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
                              ],
                            ),
                          ),
                          
                        if (lowStockCount > 0) const SizedBox(height: 24),

                          // QUICK ACTIONS
                          const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // If width is large, show 3 or 4 cards. If small, maybe 2.
                              // Currently we have 2 actions, let's just use a Row or Grid.
                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildActionCard(
                                      "My Products", 
                                      "Manage your inventory", 
                                      Icons.inventory, 
                                      const Color(0xFF0D9759), 
                                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListedProductsScreen()))
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildActionCard(
                                      "Analytics", 
                                      "View detailed reports", 
                                      Icons.pie_chart, 
                                      const Color(0xFF4568DC), 
                                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorSalesAnalytics()))
                                    ),
                                  ),
                                  // Add empty Expanded if you want equal sizing for more items in future
                                  // const Expanded(child: SizedBox()),
                                ],
                              );
                            }
                          ),
                          const SizedBox(height: 32),

                        // RECENT ORDERS TITLE
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Recent Orders", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                            TextButton(onPressed: (){}, child: const Text("View All"))
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildRecentOrders(vendorOrders),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrders(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return const Center(child: Text("No orders yet", style: TextStyle(color: Colors.grey)));

    // Sort manually
    docs.sort((a, b) {
      Timestamp t1 = (a.data() as Map)['created_at'] ?? Timestamp.now();
      Timestamp t2 = (b.data() as Map)['created_at'] ?? Timestamp.now();
      return t2.compareTo(t1);
    });

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.take(5).length,
      itemBuilder: (context, index) {
        var data = docs[index].data() as Map<String, dynamic>;
        String status = data['status'] ?? 'Pending';
        Color statusColor = status == 'Delivered' ? Colors.green : (status == 'Cancelled' ? Colors.red : Colors.orange);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.receipt_long, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order #${data['order_id'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(DateFormat('MMM d, h:mm a').format((data['created_at'] as Timestamp).toDate()), 
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(formatCurrency((data['total_amount'] ?? 0).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                   const SizedBox(height: 4),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                     decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                     child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                   )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
