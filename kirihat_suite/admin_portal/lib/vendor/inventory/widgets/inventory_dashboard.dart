import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import 'product_metrics_card.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

/// Comprehensive inventory dashboard with metrics and insights
class InventoryDashboard extends StatelessWidget {
  final String vendorId;
  final InventoryService _inventoryService = InventoryService();

  InventoryDashboard({
    super.key,
    required this.vendorId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _inventoryService.calculateMetrics(vendorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading metrics: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final metrics = snapshot.data!;

        return Container(
          margin: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Inventory Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  ProductMetricCard(
                    title: 'Total Products',
                    value: '${metrics['total']}',
                    icon: Icons.inventory_2,
                    color: Colors.blue,
                  ),
                  ProductMetricCard(
                    title: 'Low Stock Items',
                    value: '${metrics['lowStock']}',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                  ),
                  ProductMetricCard(
                    title: 'Out of Stock',
                    value: '${metrics['outOfStock']}',
                    icon: Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  ProductMetricCard(
                    title: 'Inventory Value',
                    value: CurrencyHelper.format(metrics['totalValue']),
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Additional metrics row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniMetric(
                      'Categories',
                      '${metrics['categoriesCount']}',
                      Icons.category,
                      Colors.purple,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    _buildMiniMetric(
                      'Added This Month',
                      '${metrics['productsThisMonth']}',
                      Icons.add_circle_outline,
                      Colors.teal,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    _buildMiniMetric(
                      'Avg. Stock',
                      '${metrics['averageStock']}',
                      Icons.trending_up,
                      Colors.indigo,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniMetric(
      String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}
