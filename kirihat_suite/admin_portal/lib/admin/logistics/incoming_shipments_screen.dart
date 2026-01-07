import 'package:flutter/material.dart';
import 'package:kirihat_core/models/shipment_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'package:intl/intl.dart';

class IncomingShipmentsScreen extends StatefulWidget {
  const IncomingShipmentsScreen({super.key});

  @override
  State<IncomingShipmentsScreen> createState() => _IncomingShipmentsScreenState();
}

class _IncomingShipmentsScreenState extends State<IncomingShipmentsScreen> {
  final SellerService _sellerService = SellerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Incoming Shipments / Logistics',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage incoming stock from active sellers.',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: StreamBuilder<List<ShipmentModel>>(
                stream: _sellerService.getAllShipments(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    // Fallback for index error or permission error
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildShipmentTable(snapshot.data!);
                },
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
          Icon(Icons.monitor_heart_outlined, size: 60, color: Colors.grey[300]),
           const SizedBox(height: 16),
          const Text('No shipments found', style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
     );
  }

  Widget _buildShipmentTable(List<ShipmentModel> shipments) {
    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Shipment ID')),
            DataColumn(label: Text('From (Seller ID)')), // Ideally fetch name
            DataColumn(label: Text('To Warehouse')),
            DataColumn(label: Text('Items')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: shipments.map((shipment) {
            final isPending = shipment.status == 'pending' || shipment.status == 'shipped';
            return DataRow(
              cells: [
                DataCell(Text(DateFormat('MMM dd, HH:mm').format(shipment.createdAt))),
                DataCell(Text(shipment.id.substring(0, 8), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(shipment.sellerId)), // TODO: Fetch Seller Name map
                DataCell(Text(shipment.warehouseName)),
                DataCell(Text('${shipment.items.length} skus')),
                DataCell(_buildStatusBadge(shipment.status)),
                DataCell(
                  isPending 
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9759),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => _confirmReceive(shipment),
                      child: const Text('Receive'),
                    )
                  : const Text('-'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'received': color = Colors.green; break;
      case 'cancelled': color = Colors.red; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  void _confirmReceive(ShipmentModel shipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark shipment ${shipment.id.substring(0,8)} as received?'),
            const SizedBox(height: 16),
            const Text('Contents:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 150,
              width: double.maxFinite,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: shipment.items.length,
                itemBuilder: (context, index) {
                   final item = shipment.items[index];
                   return ListTile(
                     dense: true,
                     title: Text(item.productName),
                     trailing: Text('${item.quantity} ${item.productUnit}'),
                   );
                },
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9759), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _sellerService.receiveShipment(shipment.id);
               if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Shipment marked as Received')),
                 );
               }
            },
            child: const Text('Confirm Receive'),
          ),
        ],
      ),
    );
  }
}
