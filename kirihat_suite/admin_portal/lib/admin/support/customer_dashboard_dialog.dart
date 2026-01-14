import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kirihat_core/services/service_area_service.dart';

class CustomerDashboardDialog extends StatefulWidget {
  final String? userId;
  final String customerName;

  const CustomerDashboardDialog({
    super.key,
    required this.userId,
    required this.customerName,
  });

  @override
  State<CustomerDashboardDialog> createState() => _CustomerDashboardDialogState();
}

class _CustomerDashboardDialogState extends State<CustomerDashboardDialog> {
  late Future<DocumentSnapshot> _userFuture;
  late Future<QuerySnapshot> _ordersFuture;
  late Future<QuerySnapshot> _addressFuture;
  late Future<Map<String, dynamic>> _activityFuture;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _userFuture = FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      _ordersFuture = FirebaseFirestore.instance
          .collection('orders')
          .where('customer_id', isEqualTo: widget.userId)
          .get()
          .then((snapshot) {
            // Sort manually
            var docs = snapshot.docs.toList();
            docs.sort((a, b) {
              var aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
              var bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
            return snapshot; // We can return the snapshot, but we are just using docs mostly. 
            // Actually, to keep types consistent for builder, we can't easily modify snapshot structure.
            // So we'll just handle sorting in builder or here and return list.
            // Let's keep it simple: just return snapshot and sort in builder or return List<DocumentSnapshot>
            // But builder expects Future<QuerySnapshot>. 
            // Let's just return snapshot and sort in builder to be safe with types.
            return snapshot;
          });
      
      _addressFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('addresses')
          .limit(1)
          .get();

      _activityFuture = _getCustomerActivity(widget.userId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return AlertDialog(
        title: const Text('Error'),
        content: const Text('Customer ID not found'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return Dialog(
      child: Container(
        width: 900,
        height: 700,
        child: FutureBuilder<DocumentSnapshot>(
          future: _userFuture,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

            return Column(
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
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          widget.customerName.isNotEmpty ? widget.customerName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D9759),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customerName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              userData['email'] ?? 'No email',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      // Create Order button removed

                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Customer Info Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          Icons.phone,
                          'Phone',
                          _getPhone(userData),
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<QuerySnapshot>(
                          future: _addressFuture,
                          builder: (context, addressSnapshot) {
                            String address = 'N/A';
                            if (addressSnapshot.hasData && addressSnapshot.data!.docs.isNotEmpty) {
                              var addrData = addressSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                              address = '${addrData['city'] ?? ''}, ${addrData['state'] ?? ''}'.trim();
                              if (address == ',') address = addrData['full_address'] ?? 'N/A';
                            }
                            return _buildInfoCard(
                              Icons.location_on,
                              'Location',
                              address,
                              Colors.orange,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          Icons.calendar_today,
                          'Member Since',
                          _formatMemberSince(userData['created_at']),
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs for History
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: Color(0xFF0D9759),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Color(0xFF0D9759),
                          tabs: [
                            Tab(text: 'Order History'),
                            Tab(text: 'Cart'),
                            Tab(text: 'Activity'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildOrderHistory(),
                              _buildCartHistory(widget.userId!),
                              _buildActivityHistory(),
                            ],
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
      ),
    );
  }

  String _getPhone(Map<String, dynamic> data) {
    if (data['phone'] != null && data['phone'].toString().isNotEmpty) return data['phone'];
    if (data['phoneNumber'] != null && data['phoneNumber'].toString().isNotEmpty) return data['phoneNumber'];
    if (data['mobile'] != null && data['mobile'].toString().isNotEmpty) return data['mobile'];
    return 'N/A';
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistory() {
    return FutureBuilder<QuerySnapshot>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No orders yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // Manual sort to ensure it's correct
        var orders = snapshot.data!.docs.toList();
        orders.sort((a, b) {
           var aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
           var bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
           if (aTime == null || bTime == null) return 0;
           return bTime.compareTo(aTime);
        });

        // Take only first 10 orders
        orders = orders.take(10).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            var orderDoc = orders[index];
            var order = orderDoc.data() as Map<String, dynamic>;
            
            return InkWell(
              onTap: () => _showOrderDetails(context, orderDoc.id, order),
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(order['status']),
                    child: const Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                  ),
                  title: Text('Order #${order['order_id'] ?? orderDoc.id.substring(0, 8).toUpperCase()}'),
                  subtitle: Text('${order['status'] ?? 'Unknown'} • ₹${order['total_amount'] ?? 0}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimestamp(order['created_at']),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
                      'Order #${orderData['order_id'] ?? orderId.substring(0, 8).toUpperCase()}',
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
                      // Status
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
                      const Text(
                        'Customer Information',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Name', orderData['customer_name'] ?? 'N/A'),
                      _buildDetailRow('Phone', orderData['customer_phone'] ?? 'N/A'),
                      _buildDetailRow('Address', _formatAddress(orderData['delivery_address'])),

                      const SizedBox(height: 20),

                      // Order Info
                      const Text(
                        'Order Details',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Payment Method', orderData['payment_method'] ?? 'N/A'),
                      _buildDetailRow('Subtotal', '₹${orderData['product_total'] ?? orderData['subtotal'] ?? 0}'),
                      _buildDetailRow('Delivery Fee', '₹${orderData['delivery_fee'] ?? 0}'),
                      _buildDetailRow('Total Amount', '₹${orderData['total_amount'] ?? 0}', isBold: true),
                      if (orderData['delivery_pin'] != null && (orderData['status'] == 'Shipped' || orderData['status'] == 'Out for Delivery'))
                        _buildDetailRow('Delivery PIN', orderData['delivery_pin'], isBold: true),
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

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'N/A';
    if (address is String) return address;
    if (address is Map) {
      var addr = address as Map<String, dynamic>;
      List<String> parts = [];
      if (addr['house_no'] != null && addr['house_no'].toString().isNotEmpty) parts.add(addr['house_no']);
      if (addr['street'] != null && addr['street'].toString().isNotEmpty) parts.add(addr['street']);
      if (addr['city'] != null && addr['city'].toString().isNotEmpty) parts.add(addr['city']);
      if (addr['pincode'] != null && addr['pincode'].toString().isNotEmpty) parts.add(addr['pincode']);
      return parts.isNotEmpty ? parts.join(', ') : 'N/A';
    }
    return 'N/A';
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

  Widget _buildCartHistory(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Cart is empty'));
        }

        double cartTotal = 0;
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          var price = _parseAmount(data['price']);
          var qty = (data['quantity'] ?? 1) as int;
          cartTotal += price * qty;
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${snapshot.data!.docs.length} items in cart',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: ₹${cartTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9759),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var item = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  var price = _parseAmount(item['price']);
                  var qty = (item['quantity'] ?? 1) as int;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: item['imageUrl'] != null
                          ? Image.network(item['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.shopping_bag),
                      title: Text(item['name'] ?? 'Unknown Product'),
                      subtitle: Text('Qty: $qty • ₹$price'),
                      trailing: Text(
                        '₹${price * qty}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityHistory() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _activityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No activity data'));
        }

        var activity = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: () => _showDetailedOrders(context, widget.userId!, 'All'),
              child: _buildActivityCard('Total Orders', activity['totalOrders'].toString(), Icons.shopping_cart, Colors.blue),
            ),
            InkWell(
              onTap: () => _showDetailedOrders(context, widget.userId!, 'Delivered'),
              child: _buildActivityCard('Delivered Orders', activity['deliveredOrders'].toString(), Icons.check_circle, Colors.green),
            ),
            InkWell(
              onTap: () => _showDetailedOrders(context, widget.userId!, 'Cancelled'),
              child: _buildActivityCard('Cancelled Orders', activity['cancelledOrders'].toString(), Icons.cancel, Colors.red),
            ),
            _buildActivityCard('Total Spent', '₹${activity['totalSpent'].toStringAsFixed(0)}', Icons.attach_money, Colors.purple),
            InkWell(
              onTap: () => _showWishlist(context, widget.userId!),
              child: _buildActivityCard('Wishlist Items', activity['wishlistCount'].toString(), Icons.favorite, Colors.pink),
            ),
            InkWell(
              onTap: () => _showAddresses(context, widget.userId!),
              child: _buildActivityCard('Addresses Saved', activity['addressCount'].toString(), Icons.location_on, Colors.orange),
            ),
          ],
        );
      },
    );
  }

  void _showDetailedOrders(BuildContext context, String userId, String filterStatus) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$filterStatus Orders',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('orders')
                      .where('customer_id', isEqualTo: userId)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var orders = snapshot.data!.docs;
                    if (filterStatus != 'All') {
                      orders = orders.where((doc) => 
                        (doc.data() as Map<String, dynamic>)['status'] == filterStatus
                      ).toList();
                    }

                    if (orders.isEmpty) {
                      return const Center(child: Text('No orders'));
                    }

                    return ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        var order = orders[index].data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text('Order #${order['order_id'] ?? orders[index].id.substring(0, 8).toUpperCase()}'),
                          subtitle: Text('${order['status']} • ₹${order['total_amount']}'),
                          trailing: Text(_formatTimestamp(order['created_at'])),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWishlist(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Wishlist Items',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('wishlist')
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No wishlist items'));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var item = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: item['imageUrl'] != null
                              ? Image.network(item['imageUrl'], width: 50)
                              : const Icon(Icons.favorite),
                          title: Text(item['name'] ?? 'Product'),
                          subtitle: Text('₹${item['price'] ?? 0}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddresses(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => _AddressManagementDialog(userId: userId),
    );
  }

  Widget _buildActivityCard(String label, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getCustomerActivity(String userId) async {
    try {
      var orders = await FirebaseFirestore.instance
          .collection('orders')
          .where('customer_id', isEqualTo: userId)
          .get();

      int totalOrders = orders.docs.length;
      int deliveredOrders = orders.docs.where((doc) => (doc.data()['status'] ?? '') == 'Delivered').length;
      int cancelledOrders = orders.docs.where((doc) => (doc.data()['status'] ?? '') == 'Cancelled').length;
      
      double totalSpent = 0;
      for (var doc in orders.docs) {
        if ((doc.data()['status'] ?? '') == 'Delivered') {
          totalSpent += _parseAmount(doc.data()['total_amount']);
        }
      }

      var wishlist = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .get();

      var addresses = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .get();

      return {
        'totalOrders': totalOrders,
        'deliveredOrders': deliveredOrders,
        'cancelledOrders': cancelledOrders,
        'totalSpent': totalSpent,
        'wishlistCount': wishlist.docs.length,
        'addressCount': addresses.docs.length,
      };
    } catch (e) {
      print('Error calculating activity: $e');
      return {
        'totalOrders': 0,
        'deliveredOrders': 0,
        'cancelledOrders': 0,
        'totalSpent': 0.0,
        'wishlistCount': 0,
        'addressCount': 0,
      };
    }
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Shipped':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }

  String _formatMemberSince(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }

  void _showCreateOrderDialog(BuildContext context, String userId, String customerName, Map<String, dynamic> userData) {
    // Removed
  }
}

class _AddressManagementDialog extends StatefulWidget {
  final String userId;

  const _AddressManagementDialog({required this.userId});

  @override
  State<_AddressManagementDialog> createState() => _AddressManagementDialogState();
}

class _AddressManagementDialogState extends State<_AddressManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Logic & State
  bool _isAdding = false;
  String? _editingId;
  bool _isLoading = false;
  bool _isFetchingPin = false;
  List<String> _availableAreas = [];
  String? _selectedArea;
  final ServiceAreaService _serviceAreaService = ServiceAreaService();

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _houseController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _marketController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinController = TextEditingController();
  
  bool _isDefault = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _houseController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _marketController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 900, // Widened for detailed form
        height: 700,
        constraints: const BoxConstraints(maxHeight: 800),
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
                    const Icon(Icons.location_on, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      'Manage Addresses',
                      style: TextStyle(
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

              Expanded(
                child: Row(
                  children: [
                    // --- LEFT: ADDRESS LIST ---
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: Colors.grey.shade300)),
                          color: Colors.grey.shade50,
                        ),
                        child: Column(
                          children: [
                             Padding(
                               padding: const EdgeInsets.all(12),
                               child: ElevatedButton.icon(
                                 onPressed: _resetForm,
                                 icon: const Icon(Icons.add),
                                 label: const Text('Add New Address'),
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: const Color(0xFF0D9759),
                                   foregroundColor: Colors.white,
                                   minimumSize: const Size(double.infinity, 45),
                                 ),
                               ),
                             ),
                             Expanded(child: _buildAddressList()),
                          ],
                        ),
                      ),
                    ),

                    // --- RIGHT: ADDRESS FORM ---
                    Expanded(
                      flex: 6,
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isAdding 
                                      ? 'Add New Address' 
                                      : _editingId != null 
                                          ? 'Edit Address' 
                                          : 'Select or Add Address',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 24),
                                
                                if (_isAdding || _editingId != null) ...[
                                  // --- Contact Details ---
                                  const Text("Contact Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 12),
                                  _buildTextField(_nameController, "Receiver's Full Name *", Icons.person, isMandatory: true),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(child: _buildTextField(_phoneController, "Mobile Number *", Icons.phone, isMandatory: true, isNumber: true)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildTextField(_altPhoneController, "Alt Mobile", Icons.phone_android, isNumber: true)),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // --- Address Details ---
                                  const Text("Address Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 12),
                                  
                                  // Pincode & Service Area
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // PIN Code
                                      Expanded(
                                        child: TextFormField(
                                          controller: _pinController,
                                          keyboardType: TextInputType.number,
                                          maxLength: 6,
                                          onChanged: (val) {
                                            if (val.length == 6) _fetchPinDetails(val);
                                          },
                                          validator: (val) => (val == null || val.length != 6) ? "Invalid PIN" : null,
                                          decoration: InputDecoration(
                                            labelText: "PIN Code *",
                                            prefixIcon: const Icon(Icons.pin_drop, color: Color(0xFF0D9759)),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            counterText: "",
                                            suffixIcon: _isFetchingPin
                                                ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                                                : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Service Area
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedArea,
                                          decoration: InputDecoration(
                                            labelText: "Service Area *",
                                            prefixIcon: const Icon(Icons.location_city, color: Color(0xFF0D9759)),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          items: _availableAreas.map((area) {
                                            return DropdownMenuItem(value: area, child: Text(area));
                                          }).toList(),
                                          onChanged: _availableAreas.isEmpty ? null : (val) => setState(() => _selectedArea = val),
                                          validator: (val) => val == null ? "Required" : null,
                                          hint: Text(_availableAreas.isEmpty ? "Enter PIN first" : "Select Area"),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // House & Street
                                  _buildTextField(_houseController, "House No / Building *", Icons.home, isMandatory: true),
                                  const SizedBox(height: 16),
                                  _buildTextField(_streetController, "Street / Area / Colony *", Icons.add_road, isMandatory: true),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Landmark & Market
                                  Row(
                                    children: [
                                      Expanded(child: _buildTextField(_landmarkController, "Landmark *", Icons.store, isMandatory: true)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildTextField(_marketController, "Nearby Market *", Icons.shopping_basket, isMandatory: true)),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // District & State (Read-only)
                                  Row(
                                    children: [
                                      Expanded(child: _buildTextField(_districtController, "District", Icons.map, isReadOnly: true)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildTextField(_stateController, "State", Icons.flag, isReadOnly: true)),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Actions
                                  CheckboxListTile(
                                    value: _isDefault,
                                    onChanged: (val) => setState(() => _isDefault = val!),
                                    title: const Text('Set as Default Address'),
                                    activeColor: const Color(0xFF0D9759),
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (_editingId != null)
                                        TextButton.icon(
                                          onPressed: () => _deleteAddress(_editingId!),
                                          icon: const Icon(Icons.delete, size: 18),
                                          label: const Text('Delete'),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: _saveAddress,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0D9759),
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                        child: Text(
                                          _editingId == null ? 'SAVE ADDRESS' : 'UPDATE ADDRESS',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.touch_app, size: 64, color: Colors.grey.shade300),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Select an address to edit\nor click "Add New Address"',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ],
                            ),
                          ),
                        ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // --- UI Helpers ---
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, 
      {bool isMandatory = false, bool isReadOnly = false, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      readOnly: isReadOnly,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      maxLength: (isNumber && label.contains("Mobile")) ? 10 : null,
      validator: (val) {
        if (isMandatory && (val == null || val.trim().isEmpty)) return "$label is required";
        if (isNumber && label.contains("Mobile") && val != null && val.isNotEmpty && val.length != 10) return "Must be 10 digits";
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0D9759)),
        filled: isReadOnly,
        fillColor: isReadOnly ? Colors.grey[100] : Colors.white,
        counterText: "",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildAddressList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('addresses')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No addresses found'));

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            bool isDefault = data['is_default'] == true; // Keeping older flag for fallback
            // Check if default via user doc would be better but expensive here.
            
            bool isSelected = _editingId == docs[index].id;

            return ListTile(
              selected: isSelected,
              selectedTileColor: const Color(0xFF0D9759).withOpacity(0.1),
              onTap: () => _loadAddressForEdit(docs[index].id, data),
              leading: CircleAvatar(
                backgroundColor: isDefault ? const Color(0xFF0D9759) : Colors.grey.shade200,
                child: Icon(Icons.location_on, color: isDefault ? Colors.white : Colors.grey),
              ),
              title: Text(
                data['landmark'] ?? 'Address ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name'] ?? 'Unknown User', style: const TextStyle(fontSize: 12)),
                  Text(
                    '${data['house_no']}, ${data['street']}\n${data['service_area'] ?? data['city']} - ${data['pincode']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }
  
  // --- Logic Implementations ---
  
  void _resetForm() {
    setState(() {
      _isAdding = true;
      _editingId = null;
      _selectedArea = null;
      _availableAreas = [];
      
      _nameController.clear();
      _phoneController.clear();
      _altPhoneController.clear();
      _houseController.clear();
      _streetController.clear();
      _landmarkController.clear();
      _marketController.clear();
      _districtController.clear();
      _stateController.clear();
      _pinController.clear();
      
      _isDefault = false;
    });
  }

  void _loadAddressForEdit(String id, Map<String, dynamic> data) async {
    // If we have pincode, we might need to fetch areas to populate dropdown
    String pin = data['pincode'] ?? '';
    if (pin.length == 6) {
      await _fetchPinDetails(pin, preserveSelection: true);
    }

    setState(() {
       _isAdding = false;
       _editingId = id;
       
       _nameController.text = data['name'] ?? '';
       _phoneController.text = data['phone'] ?? '';
       _altPhoneController.text = data['alt_phone'] ?? '';
       _houseController.text = data['house_no'] ?? '';
       _streetController.text = data['street'] ?? '';
       _landmarkController.text = data['landmark'] ?? '';
       _marketController.text = data['nearby_market'] ?? '';
       _districtController.text = data['district'] ?? '';
       _stateController.text = data['state'] ?? '';
       _pinController.text = pin;
       
       // Try to select the area from data
       String? area = data['service_area'];
       if (area != null && _availableAreas.contains(area)) {
         _selectedArea = area;
       } else if (_availableAreas.isNotEmpty) {
         _selectedArea = _availableAreas.first; // Fallback
       } else {
         _selectedArea = null; // Should ideally prevent editing if area invalid
         if (area != null) {
            _availableAreas = [area]; // Hack to show current val even if not in fetch
            _selectedArea = area;
         }
       }
       
       // _isDefault logic handled via 'current_address' check usually
       _isDefault = data['is_default'] == true;
    });
  }

  Future<void> _fetchPinDetails(String pin, {bool preserveSelection = false}) async {
    if (pin.length != 6) return;
    
    // Remember current if we want to keep it
    final previousSelection = _selectedArea;
    
    if (mounted) setState(() => _isFetchingPin = true);
    
    try {
      // 1. India Post API
      final url = Uri.parse('https://api.postalpincode.in/pincode/$pin');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[0]['Status'] == 'Success') {
          final postOffice = data[0]['PostOffice'][0];
          if (mounted) {
            setState(() {
              _districtController.text = postOffice['District'];
              _stateController.text = postOffice['State'];
            });
          }
        }
      }
      
      // 2. Service Areas
      final serviceAreas = await _serviceAreaService.getServiceAreasForPincode(pin);
      
      Set<String> areas = {};
      for (var zone in serviceAreas) {
        if (zone['areas'] != null) {
          areas.addAll(List<String>.from(zone['areas']));
        }
      }
      final areasList = areas.toList()..sort();
      
      if (mounted) {
        setState(() {
          _availableAreas = areasList;
          _isFetchingPin = false;
          
          if (preserveSelection && previousSelection != null && areasList.contains(previousSelection)) {
             _selectedArea = previousSelection;
          } else if (areasList.length == 1) {
             _selectedArea = areasList.first;
          } else {
             _selectedArea = null;
          }
        });
        
        if (areasList.isEmpty && !preserveSelection) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No service available in this pincode')));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingPin = false);
      print("Error fetching PIN: $e");
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Service Area')));
       return;
    }

    setState(() => _isLoading = true);

    try {
      var collection = FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('addresses');
      
      Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'alt_phone': _altPhoneController.text.trim(),
        'house_no': _houseController.text.trim(),
        'street': _streetController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'nearby_market': _marketController.text.trim(),
        'service_area': _selectedArea,
        'district': _districtController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pinController.text.trim(),
        'is_default': _isDefault,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Save Address
      if (_editingId != null) {
        await collection.doc(_editingId).update(data);
      } else {
        data['created_at'] = FieldValue.serverTimestamp();
        await collection.add(data);
      }

      // Handle Default
      if (_isDefault) {
         // Set as current_address in user profile
         await FirebaseFirestore.instance.collection('users').doc(widget.userId).set({
            'current_address': data
         }, SetOptions(merge: true));
         
         // Unset other defaults in collection
         var defaults = await collection.where('is_default', isEqualTo: true).get();
         for (var doc in defaults.docs) {
           if (_editingId != null && doc.id == _editingId) continue;
           await doc.reference.update({'is_default': false});
         }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address saved successfully')));
        _resetForm(); // Reset to "Add New" state
        setState(() => _isLoading = false);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteAddress(String id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
        setState(() => _isLoading = true);
        
        // 1. Get Address Data to check if default
        var doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('addresses').doc(id).get();
        var addressData = doc.data();
        
        // 2. Delete
        await doc.reference.delete();
        
        // 3. Check and clean up defaults
        if (addressData != null) {
           var userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
           if (userDoc.exists && userDoc.data()!.containsKey('current_address')) {
              var current = userDoc.data()!['current_address'] as Map<String, dynamic>;
              // Heuristic match
              if (current['created_at'] == addressData['created_at'] || current['full_address'] == addressData['full_address']) {
                  // It was the default. Clear it.
                  await userDoc.reference.update({'current_address': FieldValue.delete()});
                  
                  // Optional: promote next one? leaving as delete-only for now for safety.
              }
           }
        }
      
      if (mounted) {
        _resetForm();
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address deleted')));
      }
    }
  }

}
