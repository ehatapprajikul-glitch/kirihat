import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../users/create_user_dialog.dart';
import '../coupons/create_coupon.dart';

class MainDashboard extends StatelessWidget {
  final Function(String) onNavigate;
  
  const MainDashboard({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First Row Stats - Real Data
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = usersSnapshot.data!.docs;
              int totalUsers = users.length;
              int vendors = users.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return (data['role'] ?? 'customer') == 'vendor';
              }).length;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('riders').snapshots(),
                builder: (context, ridersSnapshot) {
                  int riders = ridersSnapshot.data?.docs.length ?? 0;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                    builder: (context, ordersSnapshot) {
                      double totalRevenue = 0;
                      if (ordersSnapshot.hasData) {
                        // Only count delivered orders for revenue
                        totalRevenue = ordersSnapshot.data!.docs
                            .where((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              return (data['status'] ?? '') == 'Delivered';
                            })
                            .fold(0.0, (sum, doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              return sum + ((data['total_amount'] ?? 0) as num).toDouble();
                            });
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => onNavigate('users'),
                              child: _buildStatCard(
                                'Total Users',
                                totalUsers.toString(),
                                Icons.people,
                                Colors.blue,
                                'Across all roles',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => onNavigate('vendor_monitor'),
                              child: _buildStatCard(
                                'Active Vendors',
                                vendors.toString(),
                                Icons.store,
                                Colors.green,
                                'Registered vendors',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => onNavigate('rider_monitor'),
                              child: _buildStatCard(
                                'Active Riders',
                                riders.toString(),
                                Icons.delivery_dining,
                                Colors.orange,
                                'Delivery partners',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => onNavigate('analytics'),
                              child: _buildStatCard(
                                'Total Revenue',
                                '₹${(totalRevenue / 1000).toStringAsFixed(1)}K',
                                Icons.attach_money,
                                Colors.purple,
                                'All time earnings',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // Second Row Stats - Real Data
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, ordersSnapshot) {
              int todayOrders = 0;
              if (ordersSnapshot.hasData) {
                DateTime now = DateTime.now();
                DateTime today = DateTime(now.year, now.month, now.day);
                todayOrders = ordersSnapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  Timestamp? createdAt = data['created_at'];
                  if (createdAt != null) {
                    return createdAt.toDate().isAfter(today);
                  }
                  return false;
                }).length;
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collectionGroup('cart').snapshots(),
                builder: (context, cartSnapshot) {
                  int activeCarts = 0;
                  if (cartSnapshot.hasData) {
                    Map<String, List<DocumentSnapshot>> cartsByUser = {};
                    for (var doc in cartSnapshot.data!.docs) {
                      String userId = doc.reference.parent.parent!.id;
                      if (!cartsByUser.containsKey(userId)) {
                        cartsByUser[userId] = [];
                      }
                      cartsByUser[userId]!.add(doc);
                    }
                    activeCarts = cartsByUser.length;
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('callback_requests')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, callbackSnapshot) {
                      int pendingCallbacks = callbackSnapshot.hasData 
                          ? callbackSnapshot.data!.docs.length 
                          : 0;

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('coupons')
                            .where('is_active', isEqualTo: true)
                            .snapshots(),
                        builder: (context, couponSnapshot) {
                          int activeCoupons = couponSnapshot.hasData 
                              ? couponSnapshot.data!.docs.length 
                              : 0;

                          return Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => onNavigate('customer_monitor'),
                                  child: _buildStatCard(
                                    "Today's Orders",
                                    todayOrders.toString(),
                                    Icons.shopping_cart,
                                    const Color(0xFF0D9759),
                                    'Orders placed today',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => onNavigate('data_monitoring'),
                                  child: _buildStatCard(
                                    'Active Carts',
                                    activeCarts.toString(),
                                    Icons.shopping_bag,
                                    Colors.teal,
                                    'Users with items',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => onNavigate('support'),
                                  child: _buildStatCard(
                                    'Pending Callbacks',
                                    pendingCallbacks.toString(),
                                    Icons.phone_callback,
                                    Colors.red,
                                    'Requires attention',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => onNavigate('coupons'),
                                  child: _buildStatCard(
                                    'Active Coupons',
                                    activeCoupons.toString(),
                                    Icons.local_offer,
                                    Colors.pink,
                                    'Live discount codes',
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildQuickAction(
                context,
                'Create User',
                Icons.person_add,
                Colors.blue,
                () => _showCreateUserDialog(context),
              ),
              _buildQuickAction(
                context,
                'Send Notification',
                Icons.notifications,
                Colors.orange,
                () => onNavigate('notifications'),
              ),
              _buildQuickAction(
                context,
                'Create Coupon',
                Icons.local_offer,
                Colors.pink,
                () => _showCreateCouponDialog(context),
              ),
              _buildQuickAction(
                context,
                'View Analytics',
                Icons.bar_chart,
                Colors.purple,
                () => onNavigate('analytics'),
              ),
              _buildQuickAction(
                context,
                'User Management',
                Icons.people,
                const Color(0xFF0D9759),
                () => onNavigate('users'),
              ),
              _buildQuickAction(
                context,
                'Layout Designer',
                Icons.view_quilt,
                Colors.indigo,
                () => onNavigate('layout_designer'),
              ),
              _buildQuickAction(
                context,
                'Customer Support',
                Icons.support_agent,
                Colors.deepOrange,
                () => onNavigate('support'),
              ),
              _buildQuickAction(
                context,
                'Platform Settings',
                Icons.settings,
                Colors.blueGrey,
                () => onNavigate('settings'),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Recent Orders
          Container(
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
                      .limit(5)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No orders yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        
                        return InkWell(
                          onTap: () => _showOrderDetails(context, doc.id, data),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF0D9759),
                              child: Text('#${index + 1}', style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text('Order #${doc.id.substring(0, 8).toUpperCase()}'),
                            subtitle: Text(data['customer_name'] ?? 'Unknown Customer'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${data['total_amount'] ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(data['status']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    data['status'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(data['status']),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showCreateUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateUserDialog(),
    );
  }

  void _showCreateCouponDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateCoupon(),
    );
  }

  void _showOrderDetails(BuildContext context, String orderId, Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D9759),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Order #${orderId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Order Details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(orderData['status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(orderData['status']),
                              color: _getStatusColor(orderData['status']),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              orderData['status'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(orderData['status']),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Customer Info
                      _buildInfoSection('Customer Information', [
                        _buildInfoRow('Name', orderData['customer_name'] ?? 'N/A'),
                        _buildInfoRow('Phone', orderData['customer_phone'] ?? 'N/A'),
                        _buildInfoRow('Address', orderData['delivery_address'] ?? 'N/A'),
                      ]),

                      const SizedBox(height: 20),

                      // Order Details
                      _buildInfoSection('Order Details', [
                        _buildInfoRow('Order ID', orderId),
                        _buildInfoRow('Payment Method', orderData['payment_method'] ?? 'N/A'),
                        _buildInfoRow('Subtotal', '₹${orderData['subtotal'] ?? 0}'),
                        _buildInfoRow('Delivery Fee', '₹${orderData['delivery_fee'] ?? 0}'),
                        _buildInfoRow('Total Amount', '₹${orderData['total_amount'] ?? 0}', isBold: true),
                      ]),

                      const SizedBox(height: 20),

                      // Order Items
                      const Text(
                        'Order Items',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (orderData['items'] != null)
                              ...(orderData['items'] as List).map((item) {
                                return ListTile(
                                  leading: item['imageUrl'] != null
                                      ? Image.network(
                                          item['imageUrl'],
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.shopping_bag),
                                  title: Text(item['name'] ?? 'N/A'),
                                  subtitle: Text('Qty: ${item['quantity'] ?? 1}'),
                                  trailing: Text(
                                    '₹${item['price'] ?? 0}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList()
                            else
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No items'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'Delivered':
        return Icons.check_circle;
      case 'Shipped':
        return Icons.local_shipping;
      case 'Pending':
        return Icons.pending;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}
