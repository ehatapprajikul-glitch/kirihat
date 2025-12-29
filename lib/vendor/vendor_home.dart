import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.orange[600],
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.dashboard, color: Colors.white),
            SizedBox(width: 10),
            Text("Dashboard",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. WELCOME & SEARCH
            _buildHeader(),

            // 2. DATA STREAMS
            // CRITICAL FIX: Removed complex queries to ensure data loads first.
            // Filtering is done in Dart to avoid Indexing errors for now.
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('orders').snapshots(),
              builder: (context, orderSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .where('vendor_id', isEqualTo: currentUser?.uid)
                      .snapshots(),
                  builder: (context, productSnapshot) {
                    // Check connection state specifically
                    if (orderSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        productSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(50.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (orderSnapshot.hasError) {
                      return Center(
                          child: Text(
                              "Error loading orders: ${orderSnapshot.error}"));
                    }

                    // --- CLIENT SIDE FILTERING (SAFER) ---
                    // Filter orders for this vendor manually to bypass index issues
                    var allOrders = orderSnapshot.data?.docs ?? [];
                    var vendorOrders = allOrders.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      // Check matches on either UID or Email
                      return data['vendor_id'] == currentUser?.uid ||
                          data['vendor_id'] == currentUser?.email;
                    }).toList();

                    var products = productSnapshot.data?.docs ?? [];

                    // Sales Logic
                    double totalRevenue = 0;
                    double todayRevenue = 0;
                    int pendingOrders = 0;
                    int processingOrders = 0;
                    int completedOrders = 0;

                    for (var doc in vendorOrders) {
                      var data = doc.data() as Map<String, dynamic>;
                      double amount = (data['total_amount'] ?? 0).toDouble();
                      String status = data['status'] ?? 'Pending';
                      Timestamp? date = data['created_at'];

                      // Calculate Revenue (Only if not cancelled)
                      if (status != 'Cancelled') {
                        totalRevenue += amount;
                        if (isToday(date)) todayRevenue += amount;
                      }

                      if (status == 'Pending') pendingOrders++;
                      if (status == 'Shipped') processingOrders++;
                      if (status == 'Delivered') completedOrders++;
                    }

                    // Inventory Logic
                    int totalProducts = products.length;
                    int lowStockCount = 0;
                    for (var doc in products) {
                      var data = doc.data() as Map<String, dynamic>;
                      int stock = data['stock_quantity'] ?? 0;
                      if (stock < 5) lowStockCount++;
                    }

                    return Column(
                      children: [
                        // KPI CARDS
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.4,
                            children: [
                              _buildKPICard(
                                  "Total Sales",
                                  formatCurrency(totalRevenue),
                                  "Today: ${formatCurrency(todayRevenue)}",
                                  Colors.green,
                                  Icons.attach_money),
                              _buildKPICard(
                                  "Total Orders",
                                  "${vendorOrders.length}",
                                  "Pending: $pendingOrders",
                                  Colors.blue,
                                  Icons.shopping_bag),
                              _buildKPICard(
                                  "Products",
                                  "$totalProducts",
                                  "Low Stock: $lowStockCount",
                                  Colors.orange,
                                  Icons.inventory),
                              _buildKPICard(
                                  "Payouts",
                                  formatCurrency(totalRevenue * 0.9),
                                  "Next: Jan 15",
                                  Colors.purple,
                                  Icons.account_balance_wallet),
                            ],
                          ),
                        ),

                        // LOW STOCK ALERT
                        if (lowStockCount > 0)
                          _buildLowStockAlert(lowStockCount),

                        // RECENT ORDERS
                        _buildSectionHeader("Recent Orders"),
                        _buildRecentOrdersList(vendorOrders),

                        const SizedBox(height: 80),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: Colors.orange[600],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome, ${currentUser?.displayName ?? 'Vendor'}",
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const TextField(
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Search products, orders...",
                prefixIcon: Icon(Icons.search, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String title, String mainValue, String subValue,
      Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (title == "Products" &&
                  subValue.contains("Low") &&
                  !subValue.contains(": 0"))
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 16)
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mainValue,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 2),
              Text(title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4)),
            child: Text(subValue,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildLowStockAlert(int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Stock Alert",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red)),
                Text("$count products are low on stock.",
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(onPressed: () {}, child: const Text("View All")),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("No orders yet.", style: TextStyle(color: Colors.grey)),
      );
    }

    // Sort manually since we removed .orderBy from query
    docs.sort((a, b) {
      Timestamp t1 = (a.data() as Map)['created_at'] ?? Timestamp.now();
      Timestamp t2 = (b.data() as Map)['created_at'] ?? Timestamp.now();
      return t2.compareTo(t1);
    });

    var recentDocs = docs.take(5).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: recentDocs.length,
      itemBuilder: (context, index) {
        var data = recentDocs[index].data() as Map<String, dynamic>;
        String orderId = data['order_id'] ??
            recentDocs[index].id.substring(0, 5).toUpperCase();
        String customer = data['customer_phone'] ?? "Customer";
        double total = (data['total_amount'] ?? 0).toDouble();
        String status = data['status'] ?? 'Pending';

        String dateStr = "Recent";
        if (data['created_at'] != null) {
          dateStr = DateFormat('MMM d')
              .format((data['created_at'] as Timestamp).toDate());
        }

        Color statusColor = Colors.orange;
        if (status == 'Delivered') statusColor = Colors.green;
        if (status == 'Cancelled') statusColor = Colors.red;
        if (status == 'Shipped') statusColor = Colors.blue;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[50],
              child: const Icon(Icons.receipt_long, color: Colors.blue),
            ),
            title: Text("Order #$orderId",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("$customer • $dateStr"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatCurrency(total),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
