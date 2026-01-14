import 'package:flutter/material.dart';
import 'package:kirihat_core/services/warehouse_service.dart';

class WarehouseDashboard extends StatefulWidget {
  final Function(String) onNavigate;
  const WarehouseDashboard({super.key, required this.onNavigate});

  @override
  State<WarehouseDashboard> createState() => _WarehouseDashboardState();
}

class _WarehouseDashboardState extends State<WarehouseDashboard> {
  final WarehouseService _warehouseService = WarehouseService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await _warehouseService.getWarehouseStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             const Text(
               'Warehouse Overview',
               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
             ),
             ElevatedButton.icon(
                onPressed: () => widget.onNavigate('warehouse_setup'),
                icon: const Icon(Icons.settings),
                label: const Text('Configure Warehouses'),
                style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.white,
                   foregroundColor: const Color(0xFF1E293B),
                   elevation: 0,
                   side: const BorderSide(color: Color(0xFFCBD5E1))
                ),
             )
           ],
        ),
        const SizedBox(height: 24),

        // Alerts
        if ((_stats['low_stock_count'] ?? 0) > 0) ...[
          _buildAlertBanner(),
          const SizedBox(height: 24),
        ],

        // Stats Grid
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              crossAxisCount: constraints.maxWidth > 1100 ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                    'Total SKU',
                    '${_stats['total_products'] ?? 0}',
                    Icons.inventory_2,
                    Colors.blue
                ),
                _buildStatCard(
                    'Total Quantity',
                    '${_stats['total_quantity'] ?? 0}',
                    Icons.numbers,
                    Colors.green
                ),
                _buildStatCard(
                    'Low Stock',
                    '${_stats['low_stock_count'] ?? 0}',
                    Icons.warning,
                    Colors.orange,
                    isAlert: true
                ),
                _buildStatCard(
                    'Pending Requests',
                    '${_stats['pending_requests'] ?? 0}',
                    Icons.pending_actions,
                    Colors.purple
                ),
              ],
            );
          }
        ),
        
        const SizedBox(height: 32),
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                 crossAxisCount: constraints.maxWidth > 1100 ? 4 : 2, // Responsive columns
                 childAspectRatio: 2.5, // Adjusted aspect ratio
                 crossAxisSpacing: 16,
                 mainAxisSpacing: 16,
                 children: [
                    _buildActionCard(
                      'Receive Shipments',
                      'Process incoming stock',
                      Icons.input,
                      Colors.blue,
                      () => widget.onNavigate('receive_shipments')
                    ),
                    _buildActionCard(
                      'Inventory Management',
                      'Adjust stock levels',
                      Icons.inventory,
                      Colors.green,
                      () => widget.onNavigate('warehouse_inventory')
                    ),
                    _buildActionCard(
                      'Vendor Requests',
                      'Approve stock transfers',
                      Icons.store,
                      Colors.purple,
                      () => widget.onNavigate('vendor_requests')
                    ),
                    _buildActionCard(
                      'Incoming Shipments',
                      'Monitor logistics',
                      Icons.local_shipping,
                      Colors.orange,
                      () => widget.onNavigate('incoming_shipments')
                    ),
                 ],
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFC2410C)),
          const SizedBox(width: 12),
          Text(
            '${_stats['low_stock_count']} items are below minimum stock level.',
            style: const TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => widget.onNavigate('warehouse_inventory'),
             child: const Text('View Inventory'),
             style: TextButton.styleFrom(foregroundColor: const Color(0xFFC2410C)),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isAlert ? Border.all(color: color.withOpacity(0.5), width: 2) : Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(
               color: color.withOpacity(0.1),
               borderRadius: BorderRadius.circular(10),
             ),
             child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
             Container(
               width: 48, height: 48,
               decoration: BoxDecoration(
                 color: color.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(12)
               ),
               child: Icon(icon, color: color),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                 ],
               ),
             ),
             const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
