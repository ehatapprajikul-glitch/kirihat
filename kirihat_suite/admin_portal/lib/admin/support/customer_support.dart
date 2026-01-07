import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_dashboard_dialog.dart';

class CustomerSupport extends StatefulWidget {
  const CustomerSupport({super.key});

  @override
  State<CustomerSupport> createState() => _CustomerSupportState();
}

class _CustomerSupportState extends State<CustomerSupport> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          'Customer Support',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage callback requests and customer concerns',
          style: TextStyle(color: Colors.grey[600]),
        ),

        const SizedBox(height: 16),

        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by email, phone, or order ID...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (value) => _searchCustomerOrOrder(value.trim()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Search Help'),
                      content: const Text(
                        'You can search by:\n\n'
                        '• Customer Email\n'
                        '• Customer Phone Number\n'
                        '• Order ID (e.g., ORD-12345 or ADMIN-67890)\n\n'
                        'Order search will show order details and customer info.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D9759),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0D9759),
          tabs: const [
            Tab(text: 'Callback Requests'),
            Tab(text: 'Customer Concerns'),
          ],
        ),

        const SizedBox(height: 16),

        // Status Filter
        Row(
          children: [
            const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('All'),
              selected: _statusFilter == 'All',
              onSelected: (selected) => setState(() => _statusFilter = 'All'),
              selectedColor: const Color(0xFF0D9759).withOpacity(0.2),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Pending'),
              selected: _statusFilter == 'pending',
              onSelected: (selected) => setState(() => _statusFilter = 'pending'),
              selectedColor: Colors.orange.withOpacity(0.2),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Resolved'),
              selected: _statusFilter == 'resolved',
              onSelected: (selected) => setState(() => _statusFilter = 'resolved'),
              selectedColor: Colors.green.withOpacity(0.2),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCallbackRequests(),
              _buildCustomerConcerns(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCallbackRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getCallbackStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_callback, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No callback requests',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Sort client-side when filtering (to avoid composite index requirement)
        var docs = snapshot.data!.docs;
        if (_statusFilter != 'All') {
          docs = List.from(docs);
          docs.sort((a, b) {
            var aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            var bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Descending order
          });
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildCallbackCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildCallbackCard(String id, Map<String, dynamic> data) {
    String customerName = data['customer_name'] ?? 'Unknown';
    String customerPhone = data['phone'] ?? 'N/A';
    String reason = data['reason'] ?? 'General query';
    String message = data['message'] ?? '';
    String status = data['status'] ?? 'pending';
    Timestamp? createdAt = data['created_at'];
    String? assignedTo = data['assigned_to'];
    bool isPriority = data['is_priority'] ?? false;
    String? userId = data['user_id'];

    return InkWell(
      onTap: () => _showCustomerDashboard(context, userId, customerName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPriority ? Colors.red : Colors.grey[300]!,
            width: isPriority ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF0D9759),
                    child: Text(customerName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (isPriority) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PRIORITY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Tooltip(
                              message: 'Click to view customer details',
                              child: Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(customerPhone, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              createdAt != null ? _formatDate(createdAt) : 'N/A',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reason,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(message, style: TextStyle(color: Colors.grey[700])),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'pending') ...[
                    OutlinedButton.icon(
                      onPressed: () => _markPriority(id, !isPriority),
                      icon: Icon(
                        isPriority ? Icons.flag : Icons.outlined_flag,
                        size: 16,
                      ),
                      label: Text(isPriority ? 'Unmark' : 'Priority'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _resolveCallback(id),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Mark Resolved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9759),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerConcerns() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getConcernsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feedback, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No customer concerns',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Sort client-side when filtering (to avoid composite index requirement)
        var docs = snapshot.data!.docs;
        if (_statusFilter != 'All') {
          docs = List.from(docs);
          docs.sort((a, b) {
            var aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            var bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Descending order
          });
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildConcernCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildConcernCard(String id, Map<String, dynamic> data) {
    String customerName = data['customer_name'] ?? 'Unknown';
    String orderId = data['order_id'] ?? '';
    String type = data['type'] ?? 'General';
    String message = data['message'] ?? '';
    String status = data['status'] ?? 'pending';
    Timestamp? createdAt = data['created_at'];
    int rating = data['rating'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(customerName[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (orderId.isNotEmpty) ...[
                            const Icon(Icons.receipt, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Order: $orderId', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(width: 16),
                          ],
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            createdAt != null ? _formatDate(createdAt) : 'N/A',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _buildTypeBadge(type),
                if (rating > 0) ...[
                  const SizedBox(width: 12),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            Text(message, style: TextStyle(color: Colors.grey[800])),

            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _resolveConcern(id),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Mark Resolved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9759),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'delivered':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'shipped':
      case 'out for delivery':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getCallbackStream() {
    Query query = FirebaseFirestore.instance.collection('callback_requests');
    
    if (_statusFilter != 'All') {
      query = query.where('status', isEqualTo: _statusFilter);
      // Don't add orderBy here to avoid needing composite index
      // We'll sort client-side in the builder
    } else {
      query = query.orderBy('created_at', descending: true);
    }
    
    return query.snapshots();
  }

  Stream<QuerySnapshot> _getConcernsStream() {
    Query query = FirebaseFirestore.instance.collection('customer_concerns');
    
    if (_statusFilter != 'All') {
      query = query.where('status', isEqualTo: _statusFilter);
      // Don't add orderBy here to avoid needing composite index
    } else {
      query = query.orderBy('created_at', descending: true);
    }
    
    return query.snapshots();
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    Duration diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _markPriority(String id, bool isPriority) async {
    try {
      await FirebaseFirestore.instance
          .collection('callback_requests')
          .doc(id)
          .update({'is_priority': isPriority});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPriority ? 'Marked as priority' : 'Unmarked'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resolveCallback(String id) async {
    try {
      User? admin = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance
          .collection('callback_requests')
          .doc(id)
          .update({
        'status': 'resolved',
        'resolved_by': admin?.uid,
        'resolved_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Callback marked as resolved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resolveConcern(String id) async {
    try {
      User? admin = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance
          .collection('customer_concerns')
          .doc(id)
          .update({
        'status': 'resolved',
        'resolved_by': admin?.uid,
        'resolved_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Concern marked as resolved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _searchCustomerOrOrder(String query) async {
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email, phone, or order ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Check if query looks like an order ID (contains ORD or ADMIN)
      if (query.toUpperCase().contains('ORD') || query.toUpperCase().contains('ADMIN')) {
        // Search for order
        var orders = await FirebaseFirestore.instance
            .collection('orders')
            .where('order_id', isEqualTo: query.toUpperCase())
            .limit(1)
            .get();

        if (orders.docs.isNotEmpty) {
          var orderData = orders.docs.first.data();
          var customerId = orderData['customer_id'];
          
          // Fetch customer data
          var customerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(customerId)
              .get();
          
          if (customerDoc.exists) {
            var customerData = customerDoc.data()!;
            _showOrderDetailsDialog(orders.docs.first.id, orderData, customerData['name'] ?? 'Customer');
          } else {
            _showOrderDetailsDialog(orders.docs.first.id, orderData, 'Unknown Customer');
          }
          return;
        }
      }

      // Otherwise search for customer by email/phone as before
      await _searchCustomer(query);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _searchCustomer(String query) async {
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email or phone number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Search by email first
      var usersByEmail = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: query)
          .limit(1)
          .get();

      if (usersByEmail.docs.isNotEmpty) {
        var userData = usersByEmail.docs.first.data();
        _showCustomerDashboard(
          context,
          usersByEmail.docs.first.id,
          userData['name'] ?? 'Customer',
        );
        return;
      }

      // Search by phone
      var usersByPhone = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: query)
          .limit(1)
          .get();

      if (usersByPhone.docs.isNotEmpty) {
        var userData = usersByPhone.docs.first.data();
        _showCustomerDashboard(
          context,
          usersByPhone.docs.first.id,
          userData['name'] ?? 'Customer',
        );
        return;
      }

      // Try phoneNumber field as fallback
      var usersByPhoneNumber = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: query)
          .limit(1)
          .get();

      if (usersByPhoneNumber.docs.isNotEmpty) {
        var userData = usersByPhoneNumber.docs.first.data();
        _showCustomerDashboard(
          context,
          usersByPhoneNumber.docs.first.id,
          userData['name'] ?? 'Customer',
        );
        return;
      }

      // No customer found
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No customer found with this email or phone'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showOrderDetailsDialog(String orderId, Map<String, dynamic> orderData, String customerName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 700,
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
                    const Icon(Icons.receipt_long, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order: ${orderData['order_id'] ?? orderId.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Customer: $customerName',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCustomerDashboard(context, orderData['customer_id'], customerName);
                      },
                      icon: const Icon(Icons.person, size: 16),
                      label: const Text('View Customer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D9759),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

              // Order Details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      _buildStatusBadge(orderData['status'] ?? 'Unknown'),
                      
                      const SizedBox(height: 24),

                      // Customer Info
                      _buildSectionTitle('Customer Information'),
                      _buildInfoRow('Name', orderData['customer_name'] ?? 'N/A'),
                      _buildInfoRow('Phone', orderData['customer_phone'] ?? 'N/A'),
                      _buildInfoRow('Address', _formatOrderAddress(orderData['delivery_address'])),

                      const SizedBox(height: 20),

                      // Payment Info
                      _buildSectionTitle('Payment Details'),
                      _buildInfoRow('Method', orderData['payment_method'] ?? 'N/A'),
                      _buildInfoRow('Status', orderData['payment_status'] ?? 'Pending'),
                      _buildInfoRow('Subtotal', '₹${orderData['product_total'] ?? orderData['subtotal'] ?? 0}'),
                      _buildInfoRow('Delivery Fee', '₹${orderData['delivery_fee'] ?? 0}'),
                      _buildInfoRow('Total', '₹${orderData['total_amount'] ?? 0}', isBold: true),

                      if (orderData['delivery_pin'] != null)
                        _buildInfoRow('Delivery PIN', orderData['delivery_pin'], isBold: true),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showChangeAddressDialog(orderId, orderData),
                            icon: const Icon(Icons.edit_location, size: 18),
                            label: const Text('Change Address'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showRaiseReturnDialog(orderId, orderData),
                            icon: const Icon(Icons.assignment_return, size: 18),
                            label: const Text('Raise Return'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
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

  String _formatOrderAddress(dynamic address) {
    if (address == null) return 'N/A';
    if (address is String) return address;
    if (address is Map) {
      var addr = address as Map<String, dynamic>;
      List<String> parts = [];
      if (addr['house_no'] != null) parts.add(addr['house_no']);
      if (addr['street'] != null) parts.add(addr['street']);
      if (addr['city'] != null) parts.add(addr['city']);
      if (addr['pincode'] != null) parts.add(addr['pincode']);
      return parts.isNotEmpty ? parts.join(', ') : 'N/A';
    }
    return 'N/A';
  }

  void _showChangeAddressDialog(String orderId, Map<String, dynamic> orderData) {
    final addressController = TextEditingController(
      text: _formatOrderAddress(orderData['delivery_address']),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Delivery Address'),
        content: TextField(
          controller: addressController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'New Address',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(orderId)
                    .update({
                  'delivery_address': addressController.text.trim(),
                  'address_updated_at': FieldValue.serverTimestamp(),
                  'address_updated_by_admin': true,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Address updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9759)),
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  void _showRaiseReturnDialog(String orderId, Map<String, dynamic> orderData) {
    final reasonController = TextEditingController();
    String selectedReason = 'Defective Product';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Raise Return Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Return Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Defective Product', child: Text('Defective Product')),
                    DropdownMenuItem(value: 'Wrong Item', child: Text('Wrong Item')),
                    DropdownMenuItem(value: 'Not as Described', child: Text('Not as Described')),
                    DropdownMenuItem(value: 'Quality Issue', child: Text('Quality Issue')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedReason = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional Details',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Create return request
                    await FirebaseFirestore.instance.collection('return_requests').add({
                      'order_id': orderId,
                      'customer_id': orderData['customer_id'],
                      'customer_name': orderData['customer_name'],
                      'return_reason': selectedReason,
                      'return_details': reasonController.text.trim(),
                      'status': 'Pending',
                      'created_by_admin': true,
                      'created_at': FieldValue.serverTimestamp(),
                    });

                    // Update order status
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderId)
                        .update({
                      'return_requested': true,
                      'return_requested_at': FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Return request created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('RAISE RETURN'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCustomerDashboard(BuildContext context, String? userId, String customerName) {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CustomerDashboardDialog(
        userId: userId,
        customerName: customerName,
      ),
    );
  }
}
