import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/models/shipment_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'create_shipment_screen.dart';

class SellerShipmentsScreen extends StatelessWidget {
  final SellerModel seller;

  const SellerShipmentsScreen({super.key, required this.seller});

  @override
  Widget build(BuildContext context) {
    final SellerService sellerService = SellerService();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          // Use icon-only FAB on very small screens
          if (MediaQuery.of(context).size.width < 400) {
            return FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateShipmentScreen(seller: seller),
                  ),
                );
              },
              backgroundColor: const Color(0xFF0D9759),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            );
          }
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateShipmentScreen(seller: seller),
                ),
              );
            },
            backgroundColor: const Color(0xFF0D9759),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Create Shipment'),
          );
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;
          
          return Padding(
            padding: EdgeInsets.all(isSmall ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Shipments',
                  style: TextStyle(
                    fontSize: isSmall ? 22 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track and manage your stock shipments to warehouses',
                  style: TextStyle(
                    fontSize: isSmall ? 14 : 16,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: isSmall ? 16 : 24),
                Expanded(
                  child: StreamBuilder<List<ShipmentModel>>(
                    stream: sellerService.getSellerShipments(seller.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _buildEmptyState();
                      }

                      final shipments = snapshot.data!;
                      return ListView.builder(
                        itemCount: shipments.length,
                        itemBuilder: (context, index) {
                          return _buildShipmentCard(shipments[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No shipments yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a shipment to send stock to a warehouse',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentCard(ShipmentModel shipment) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    // Updated for warehouse workflow
    switch (shipment.status) {
      case 'pending_approval':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusLabel = 'Pending Approval';
        break;
      case 'approved':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle;
        statusLabel = 'Approved - Van Scheduled';
        break;
      case 'in_transit':
        statusColor = Colors.purple;
        statusIcon = Icons.local_shipping;
        statusLabel = 'In Transit';
        break;
      case 'delivered_to_warehouse':
        statusColor = Colors.indigo;
        statusIcon = Icons.warehouse;
        statusLabel = 'At Warehouse';
        break;
      case 'verified':
        statusColor = Colors.teal;
        statusIcon = Icons.verified;
        statusLabel = 'Verified';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.done_all;
        statusLabel = 'Completed';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusLabel = 'Rejected';
        break;
      // Legacy statuses
      case 'shipped':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        statusLabel = 'Shipped';
        break;
      case 'received':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = 'Received';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusLabel = shipment.status.toUpperCase();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To: ${shipment.warehouseName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Items: ${shipment.items.length} | Created: ${DateFormat('MMM dd, yyyy').format(shipment.createdAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Preview Item List (First 2 items)
            ...shipment.items.take(2).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '• ${item.productName}',
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                )),
            if (shipment.items.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${shipment.items.length - 2} more items',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
