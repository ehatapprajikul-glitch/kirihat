import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerMonitor extends StatelessWidget {
  const CustomerMonitor({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer App Monitoring',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Stats Cards
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'customer').snapshots(),
            builder: (context, userSnapshot) {
              int totalCustomers = userSnapshot.data?.docs.length ?? 0;
              int activeCustomers = userSnapshot.data?.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return !(data['disabled'] ?? false);
              }).length ?? 0;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                builder: (context, orderSnapshot) {
                  var orders = orderSnapshot.data?.docs ?? [];
                  int totalOrders = orders.length;
                  double totalRevenue = orders.fold(0.0, (sum, doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return sum + ((data['total_amount'] ?? 0) as num).toDouble();
                  });

                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Customers',
                          totalCustomers.toString(),
                          Icons.people,
                          Colors.blue,
                          '$activeCustomers active',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Total Orders',
                          totalOrders.toString(),
                          Icons.shopping_cart,
                          const Color(0xFF0D9759),
                          'All time',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Total Revenue',
                          '₹${(totalRevenue / 1000).toStringAsFixed(1)}K',
                          Icons.attach_money,
                          Colors.purple,
                          'All time',
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // Active Carts Section
          const Text(
            'Active Carts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collectionGroup('cart').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('No active carts')),
                );
              }

              // Group carts by user
              Map<String, List<DocumentSnapshot>> cartsByUser = {};
              for (var doc in snapshot.data!.docs) {
                String userId = doc.reference.parent.parent!.id;
                if (!cartsByUser.containsKey(userId)) {
                  cartsByUser[userId] = [];
                }
                cartsByUser[userId]!.add(doc);
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cartsByUser.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    String userId = cartsByUser.keys.elementAt(index);
                    List<DocumentSnapshot> userCart = cartsByUser[userId]!;
                    
                    int itemCount = userCart.fold(0, (sum, doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return sum + ((data['quantity'] ?? 0) as int);
                    });

                    double cartValue = userCart.fold(0.0, (sum, doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      int qty = (data['quantity'] ?? 0) as int;
                      double price = ((data['price'] ?? 0) as num).toDouble();
                      return sum + (qty * price);
                    });

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, userDoc) {
                        String userName = 'Unknown User';
                        if (userDoc.hasData && userDoc.data!.exists) {
                          userName = (userDoc.data!.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0D9759),
                            child: Text(userName[0].toUpperCase()),
                          ),
                          title: Text(userName),
                          subtitle: Text('$itemCount items'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${cartValue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'Cart Value',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Recent Orders
          const Text(
            'Recent Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .orderBy('created_at', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('No orders yet')),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Order ID')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Date')),
                  ],
                  rows: snapshot.data!.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return DataRow(
                      cells: [
                        DataCell(Text(data['order_id'] ?? doc.id.substring(0, 8))),
                        DataCell(Text(data['customer_name'] ?? 'N/A')),
                        DataCell(Text('₹${data['total_amount'] ?? 0}')),
                        DataCell(_buildStatusBadge(data['status'] ?? 'Pending')),
                        DataCell(Text(_formatDate(data['created_at']))),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
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
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
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

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'delivered':
        color = Colors.green;
        break;
      case 'shipped':
        color = Colors.blue;
        break;
      case 'processing':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
