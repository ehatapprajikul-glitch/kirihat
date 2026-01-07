import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/services/warehouse_service.dart';

class ReceiveShipmentsScreen extends StatefulWidget {
  const ReceiveShipmentsScreen({super.key});

  @override
  State<ReceiveShipmentsScreen> createState() => _ReceiveShipmentsScreenState();
}

class _ReceiveShipmentsScreenState extends State<ReceiveShipmentsScreen> {
  final WarehouseService _warehouseService = WarehouseService();
  String _selectedTab = 'pending_approval'; // pending_approval, approved, delivered_to_warehouse
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Shipments'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Column(
        children: [
          // Status Tabs
          _buildStatusTabs(),
          
          // Shipments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shipments')
                  .where('status', isEqualTo: _selectedTab)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No shipments in ${_selectedTab.replaceAll('_', ' ')}',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final shipment = snapshot.data!.docs[index];
                    final data = shipment.data() as Map<String, dynamic>;
                    return _buildShipmentCard(shipment.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildTabChip('Pending Approval', 'pending_approval'),
            const SizedBox(width: 8),
            _buildTabChip('Approved', 'approved'),
            const SizedBox(width: 8),
            _buildTabChip('At Warehouse', 'delivered_to_warehouse'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, String status) {
    final isSelected = _selectedTab == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedTab = status);
        }
      },
      selectedColor: Colors.blue.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildShipmentCard(String shipmentId, Map<String, dynamic> data) {
    final status = data['status'] ?? '';
    final sellerName = data['seller_name'] ?? 'Unknown Seller';
    final totalItems = (data['items'] as List?)?.length ?? 0;
    final createdAt = (data['created_at'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: _getStatusIcon(status),
        title: Text(
          'Shipment #${shipmentId.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seller: $sellerName'),
            Text('$totalItems items • ${_formatDate(createdAt)}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Items List
                const Text(
                  'Products:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._buildItemsList(data['items'] as List?),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                _buildActionButtons(shipmentId, status, data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'pending_approval':
        return const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.pending, color: Colors.white),
        );
      case 'approved':
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.check_circle, color: Colors.white),
        );
      case 'delivered_to_warehouse':
        return const CircleAvatar(
          backgroundColor: Colors.purple,
          child: Icon(Icons.warehouse, color: Colors.white),
        );
      default:
        return const CircleAvatar(
          child: Icon(Icons.inventory),
        );
    }
  }

  List<Widget> _buildItemsList(List? items) {
    if (items == null || items.isEmpty) {
      return [const Text('No items')];
    }

    return items.map((item) {
      final productName = item['product_name'] ?? 'Unknown Product';
      final quantity = item['quantity'] ?? 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 6),
            const SizedBox(width: 8),
            Expanded(child: Text(productName)),
            Text(
              'Qty: $quantity',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildActionButtons(String shipmentId, String status, Map<String, dynamic> data) {
    if (status == 'pending_approval') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _rejectShipment(shipmentId),
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _approveShipment(shipmentId),
              icon: const Icon(Icons.check),
              label: const Text('Approve & Schedule Van'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    } else if (status == 'approved') {
      return ElevatedButton.icon(
        onPressed: () => _markDeliveredToWarehouse(shipmentId),
        icon: const Icon(Icons.local_shipping),
        label: const Text('Mark as Delivered to Warehouse'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      );
    } else if (status == 'delivered_to_warehouse') {
      return ElevatedButton.icon(
        onPressed: () => _verifyAndReceive(shipmentId, data),
        icon: const Icon(Icons.verified),
        label: const Text('Verify & Receive into Stock'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _approveShipment(String shipmentId) async {
    try {
      await FirebaseFirestore.instance.collection('shipments').doc(shipmentId).update({
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': FirebaseAuth.instance.currentUser?.uid,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipment approved. Van scheduled for collection.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectShipment(String shipmentId) async {
    final reason = await _showReasonDialog('Reason for rejection:');
    if (reason == null || reason.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('shipments').doc(shipmentId).update({
        'status': 'rejected',
        'rejection_reason': reason,
        'rejected_at': FieldValue.serverTimestamp(),
        'rejected_by': FirebaseAuth.instance.currentUser?.uid,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipment rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markDeliveredToWarehouse(String shipmentId) async {
    try {
      await FirebaseFirestore.instance.collection('shipments').doc(shipmentId).update({
        'status': 'delivered_to_warehouse',
        'delivered_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as delivered. Ready for verification.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _verifyAndReceive(String shipmentId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify & Receive'),
        content: const Text('Confirm that all items have been verified and are ready to be added to warehouse stock?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final items = data['items'] as List?;
      if (items == null || items.isEmpty) {
        throw Exception('No items in shipment');
      }

      // Process each item
      for (var item in items) {
        final productId = item['product_id'];
        final productName = item['product_name'];
        final quantity = item['quantity'] as int;

        await _warehouseService.receiveShipment(
          shipmentId: shipmentId,
          productId: productId,
          productName: productName,
          quantity: quantity,
          adminId: FirebaseAuth.instance.currentUser!.uid,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shipment received! Stock updated.'),
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

  Future<String?> _showReasonDialog(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter reason...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}
