import 'package:flutter/material.dart';
import '../../models/seller_model.dart';
import '../../models/warehouse_model.dart';
import '../../services/seller_service.dart';

class SellerAreaScreen extends StatefulWidget {
  final SellerModel seller;

  const SellerAreaScreen({super.key, required this.seller});

  @override
  State<SellerAreaScreen> createState() => _SellerAreaScreenState();
}

class _SellerAreaScreenState extends State<SellerAreaScreen> {
  final SellerService _sellerService = SellerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Area',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Location Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9759).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.store, color: Color(0xFF0D9759)),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Your Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Disabled for now as editing requires a separate flow
                        // TextButton.icon(
                        //   onPressed: () {},
                        //   icon: const Icon(Icons.edit),
                        //   label: const Text('Edit'),
                        // ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildInfoRow('City', widget.seller.city),
                    _buildInfoRow('Pincode', widget.seller.pincode),
                    _buildInfoRow('State', widget.seller.state),
                    _buildInfoRow('Full Address', widget.seller.address),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Nearby Warehouses Header
            Row(
              children: [
                const Icon(Icons.warehouse, size: 28, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Text(
                  'Warehouses in ${widget.seller.city}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Warehouses List
            StreamBuilder<List<WarehouseModel>>(
              stream: _sellerService.getNearbyWarehouses(widget.seller.city),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final warehouses = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: warehouses.length,
                  itemBuilder: (context, index) {
                    return _buildWarehouseCard(warehouses[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No warehouses found nearby',
            style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'We are expanding! New warehouses will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          // DEV TOOL: SEED BUTTON
          ElevatedButton.icon(
            onPressed: () async {
              await _sellerService.seedTestWarehouses();
              setState(() {}); // Refresh logic if needed, though stream will auto-update
            },
            icon: const Icon(Icons.science),
            label: const Text('DEV: Seed Test Warehouses'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseCard(WarehouseModel warehouse) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.domain, color: Colors.blue, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warehouse.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    warehouse.address,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.pin_drop, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${warehouse.city}, ${warehouse.pincode}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Text(
                    'Operational',
                    style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cap: ${warehouse.capacity}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
