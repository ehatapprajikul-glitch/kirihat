import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UniqueOrderStatusTracker extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const UniqueOrderStatusTracker({
    super.key,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    final status = orderData['status'] ?? 'Pending';
    final stages = _buildStages();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFF0D9759).withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9759).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF0D9759),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Journey',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C1C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Horizontal Scrollable Timeline
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < stages.length; i++) ...[
                  _buildStageNode(stages[i], i == stages.length - 1),
                  if (i < stages.length - 1)
                    _buildConnector(stages[i].isCompleted),
                ],
              ],
            ),
          ),
          
          // Current Status Info
          const SizedBox(height: 20),
          _buildCurrentStatusInfo(stages),
        ],
      ),
    );
  }

  List<OrderStage> _buildStages() {
    final status = orderData['status'] ?? 'Pending';
    final isReturnFlow = orderData['return_status'] != null;
    
    if (isReturnFlow) {
      return _buildReturnStages();
    }
    
    return _buildNormalStages();
  }

  List<OrderStage> _buildNormalStages() {
    final status = orderData['status'] ?? 'Pending';
    
    return [
      OrderStage(
        title: 'Placed',
        subtitle: _formatTimestamp(orderData['created_at']),
        icon: Icons.check_circle,
        isCompleted: true,
        isActive: status == 'Pending',
        color: const Color(0xFF0D9759),
      ),
      OrderStage(
        title: 'Shipped',
        subtitle: _formatTimestamp(orderData['shipped_at']),
        icon: Icons.inventory_2_outlined,
        isCompleted: _isStatusReached(status, ['Shipped', 'Out for Delivery', 'Delivered']),
        isActive: status == 'Shipped',
        color: const Color(0xFF0D9759),
      ),
      OrderStage(
        title: 'Out for Delivery',
        subtitle: _formatTimestamp(orderData['out_for_delivery_at']),
        icon: Icons.local_shipping,
        isCompleted: _isStatusReached(status, ['Out for Delivery', 'Delivered']),
        isActive: status == 'Out for Delivery',
        color: const Color(0xFF0D9759),
        extraInfo: status == 'Out for Delivery' && orderData['rider_phone'] != null
            ? '📞 ${orderData['rider_phone']}'
            : null,
      ),
      OrderStage(
        title: 'Delivered',
        subtitle: _formatTimestamp(orderData['delivered_at']),
        icon: Icons.home_outlined,
        isCompleted: status == 'Delivered',
        isActive: status == 'Delivered',
        color: const Color(0xFF0D9759),
      ),
    ];
  }

  List<OrderStage> _buildReturnStages() {
    final returnStatus = orderData['return_status'] ?? '';
    
    return [
      OrderStage(
        title: 'Delivered',
        subtitle: _formatTimestamp(orderData['delivered_at']),
        icon: Icons.check_circle,
        isCompleted: true,
        isActive: false,
        color: const Color(0xFF0D9759),
      ),
      OrderStage(
        title: 'Return Request',
        subtitle: _formatTimestamp(orderData['return_requested_at']),
        icon: Icons.assignment_return,
        isCompleted: true,
        isActive: returnStatus == 'Requested',
        color: Colors.orange,
      ),
      OrderStage(
        title: returnStatus == 'Approved' ? 'Approved' : 'Review',
        subtitle: _formatTimestamp(orderData['return_reviewed_at']),
        icon: returnStatus == 'Approved' ? Icons.check_circle_outline : Icons.pending_outlined,
        isCompleted: _isReturnStatusReached(returnStatus, ['Approved', 'PickupScheduled', 'PickedUp', 'Returned']),
        isActive: returnStatus == 'Requested' || returnStatus == 'Approved',
        color: returnStatus == 'Rejected' ? Colors.red : Colors.orange,
      ),
      OrderStage(
        title: 'Rider Arriving',
        subtitle: _formatTimestamp(orderData['pickup_scheduled_at']),
        icon: Icons.directions_bike,
        isCompleted: _isReturnStatusReached(returnStatus, ['PickupScheduled', 'PickedUp', 'Returned']),
        isActive: returnStatus == 'PickupScheduled',
        color: Colors.blue,
        extraInfo: returnStatus == 'PickupScheduled' && orderData['return_rider_phone'] != null
            ? '📞 ${orderData['return_rider_phone']}'
            : null,
      ),
      OrderStage(
        title: 'Returned',
        subtitle: _formatTimestamp(orderData['returned_at']),
        icon: Icons.inventory_outlined,
        isCompleted: returnStatus == 'Returned',
        isActive: returnStatus == 'Returned',
        color: const Color(0xFF0D9759),
      ),
    ];
  }

  Widget _buildStageNode(OrderStage stage, bool isLast) {
    return Container(
      width: 140,
      child: Column(
        children: [
          // Icon Circle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stage.isCompleted || stage.isActive
                  ? stage.color
                  : Colors.grey.shade200,
              boxShadow: stage.isActive
                  ? [
                      BoxShadow(
                        color: stage.color.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                stage.icon,
                color: stage.isCompleted || stage.isActive
                    ? Colors.white
                    : Colors.grey.shade400,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Title
          Text(
            stage.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: stage.isActive ? FontWeight.bold : FontWeight.w600,
              color: stage.isCompleted || stage.isActive
                  ? const Color(0xFF1C1C1C)
                  : Colors.grey.shade500,
            ),
          ),
          
          // Subtitle (Time)
          if (stage.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              stage.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          
          // Extra Info (Phone)
          if (stage.extraInfo != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: stage.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: stage.color.withOpacity(0.3)),
              ),
              child: Text(
                stage.extraInfo!,
                style: TextStyle(
                  fontSize: 10,
                  color: stage.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnector(bool isCompleted) {
    return Container(
      width: 40,
      height: 3,
      margin: const EdgeInsets.only(bottom: 80),
      decoration: BoxDecoration(
        gradient: isCompleted
            ? const LinearGradient(
                colors: [Color(0xFF0D9759), Color(0xFF0D9759)],
              )
            : LinearGradient(
                colors: [Colors.grey.shade300, Colors.grey.shade300],
              ),
      ),
    );
  }

  Widget _buildCurrentStatusInfo(List<OrderStage> stages) {
    final activeStage = stages.firstWhere(
      (s) => s.isActive,
      orElse: () => stages.last,
    );
    
    String message = '';
    Color bgColor = const Color(0xFF0D9759).withOpacity(0.1);
    Color textColor = const Color(0xFF0D9759);
    
    switch (orderData['status']) {
      case 'Pending':
        message = '⏳ Waiting for vendor to ship your order';
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange.shade700;
        break;
      case 'Shipped':
        message = '📦 Your order has been shipped and will be out for delivery soon';
        break;
      case 'Out for Delivery':
        message = '🚚 Your order is on the way! Rider will contact you shortly';
        bgColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue.shade700;
        break;
      case 'Delivered':
        message = '✅ Order successfully delivered. Thank you for shopping!';
        break;
      case 'Cancelled':
        String cancelledBy = orderData['cancelled_by'] ?? 'Unknown';
        String reason = orderData['cancellation_reason'] ?? 'No reason provided';
        String time = _formatTimestamp(orderData['cancelled_at']); // Use existing timestamp formatter or raw timestamp if needed, but _formatTimestamp returns "X ago". 
        // Actually, for "Cancelled on [Date]", maybe we want a specific date format?
        // The user asked "who cancelled the order when, why".
        
        // Let's refine the message construction.
        String actor = cancelledBy == 'Customer' ? 'You' : cancelledBy;
        
        // If we want exact date:
        String dateStr = '';
        if (orderData['cancelled_at'] != null) {
           dateStr = DateFormat('dd MMM yyyy, hh:mm a').format((orderData['cancelled_at'] as Timestamp).toDate());
        }

        message = '❌ Cancelled by $actor.\nReason: $reason\nat: $dateStr';
        
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red.shade700;
        break;
      default:
        if (orderData['return_status'] != null) {
          final returnStatus = orderData['return_status'];
          if (returnStatus == 'Requested') {
            message = '🔄 Return request submitted. Awaiting approval';
            bgColor = Colors.orange.withOpacity(0.1);
            textColor = Colors.orange.shade700;
          } else if (returnStatus == 'Approved') {
            message = '✓ Return approved. Pickup will be scheduled soon';
          } else if (returnStatus == 'PickupScheduled') {
            message = '🚴 Rider is on the way to collect your return';
            bgColor = Colors.blue.withOpacity(0.1);
            textColor = Colors.blue.shade700;
          } else if (returnStatus == 'Returned') {
            message = '✅ Item successfully returned';
          } else if (returnStatus == 'Rejected') {
            message = '❌ Return request was rejected';
            bgColor = Colors.red.withOpacity(0.1);
            textColor = Colors.red.shade700;
          }
        }
    }
    
    if (message.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final DateTime date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM dd').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  bool _isStatusReached(String currentStatus, List<String> statuses) {
    return statuses.contains(currentStatus);
  }

  bool _isReturnStatusReached(String currentStatus, List<String> statuses) {
    return statuses.contains(currentStatus);
  }
}

class OrderStage {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;
  final bool isActive;
  final Color color;
  final String? extraInfo;

  OrderStage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
    required this.isActive,
    required this.color,
    this.extraInfo,
  });
}