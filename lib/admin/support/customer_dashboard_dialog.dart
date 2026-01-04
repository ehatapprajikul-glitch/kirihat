import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
                      ElevatedButton.icon(
                        onPressed: () => _showCreateOrderDialog(context, widget.userId!, widget.customerName, userData),
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Create Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D9759),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
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
                    'Saved Addresses',
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
                      .collection('addresses')
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No saved addresses'));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var addr = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.orange),
                            title: Text(addr['label'] ?? 'Address ${index + 1}'),
                            subtitle: Text(addr['full_address'] ?? '${addr['city']}, ${addr['state']}'),
                          ),
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
    final amountController = TextEditingController();
    final itemsController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController(text: userData['phone'] ?? '');
    String paymentMethod = 'COD';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.add_shopping_cart, color: Color(0xFF0D9759)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Create Order for $customerName'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: itemsController,
                    decoration: const InputDecoration(
                      labelText: 'Items Description *',
                      hintText: 'e.g., 2x Rice, 1x Sugar',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Amount (₹) *',
                      border: OutlineInputBorder(),
                      prefixText: '₹',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Address *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'COD', child: Text('Cash on Delivery')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI/Online')),
                      DropdownMenuItem(value: 'Paid', child: Text('Already Paid')),
                    ],
                    onChanged: (value) {
                      setState(() => paymentMethod = value!);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (itemsController.text.isEmpty || 
                      amountController.text.isEmpty ||
                      phoneController.text.isEmpty ||
                      addressController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all required fields')),
                    );
                    return;
                  }

                  try {
                    double amount = double.parse(amountController.text);
                    
                    await FirebaseFirestore.instance.collection('orders').add({
                      'order_id': 'ADMIN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      'customer_id': userId,
                      'customer_name': customerName,
                      'customer_phone': phoneController.text.trim(),
                      'items': [
                        {
                          'name': itemsController.text.trim(),
                          'quantity': 1,
                          'price': amount,
                        }
                      ],
                      'product_total': amount,
                      'delivery_fee': 0,
                      'total_amount': amount,
                      'payment_method': paymentMethod,
                      'payment_status': paymentMethod == 'Paid' ? 'Paid' : 'Pending',
                      'delivery_mode': 'Standard',
                      'status': 'Pending',
                      'delivery_address': addressController.text.trim(),
                      'created_at': FieldValue.serverTimestamp(),
                      'created_by_admin': true,
                      'is_settled': false,
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order created successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                ),
                child: const Text('CREATE ORDER'),
              ),
            ],
          );
        },
      ),
    );
  }
}
