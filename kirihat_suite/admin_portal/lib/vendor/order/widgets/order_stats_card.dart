import 'package:flutter/material.dart';
import '../models/order_model.dart';

class OrderStatsCard extends StatelessWidget {
  final List<OrderModel> orders;
  final VoidCallback onDismiss;

  const OrderStatsCard({
    super.key,
    required this.orders,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final pending = orders.where((o) => o.status == 'Pending').length;
    final processing = orders.where((o) => o.status == 'Processing').length;
    final shipped = orders.where((o) => o.status == 'Shipped').length;
    final delivered = orders.where((o) => o.isDelivered).length;
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayOrders = orders.where((o) => o.createdAt.isAfter(todayStart)).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quick Stats',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStat('Pending', pending, Icons.schedule),
              ),
              Expanded(
                child: _buildStat('Processing', processing, Icons.sync),
              ),
              Expanded(
                child: _buildStat('Shipped', shipped, Icons.local_shipping),
              ),
              Expanded(
                child: _buildStat('Delivered', delivered, Icons.check_circle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.today, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Today: $todayOrders orders',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
