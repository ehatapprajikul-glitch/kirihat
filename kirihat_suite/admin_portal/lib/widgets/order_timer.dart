import 'package:flutter/material.dart';
import 'dart:async';

class OrderTimer extends StatefulWidget {
  final DateTime createdAt;
  final String deliveryMode;
  final String status;

  const OrderTimer({
    super.key,
    required this.createdAt,
    required this.deliveryMode,
    required this.status,
  });

  @override
  State<OrderTimer> createState() => _OrderTimerState();
}

class _OrderTimerState extends State<OrderTimer> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateElapsed();
        });
      }
    });
  }

  void _updateElapsed() {
    _elapsed = DateTime.now().difference(widget.createdAt);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show timer for completed/cancelled orders
    if (widget.status == 'Delivered' || 
        widget.status == 'Completed' || 
        widget.status == 'Cancelled') {
      return _buildCompletedInfo();
    }

    final isUrgent = _isUrgent();
    final timeLeft = _getTimeLeft();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time,
          size: 14,
          color: isUrgent ? Colors.red : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          _formatElapsed(),
          style: TextStyle(
            fontSize: 12,
            color: isUrgent ? Colors.red : Colors.grey[600],
            fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (timeLeft != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isUrgent ? Colors.red.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isUrgent ? Colors.red : Colors.orange,
              ),
            ),
            child: Text(
              timeLeft,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isUrgent ? Colors.red : Colors.orange,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletedInfo() {
    String text;
    IconData icon;
    Color color;

    switch (widget.status) {
      case 'Delivered':
      case 'Completed':
        text = 'Delivered';
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'Cancelled':
        text = 'Cancelled';
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        text = widget.status;
        icon = Icons.info;
        color = Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatElapsed() {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ago';
    } else if (minutes > 0) {
      return '${minutes}m ago';
    } else {
      return 'Just now';
    }
  }

  bool _isUrgent() {
    if (widget.deliveryMode == 'Express') {
      // Express delivery: 30 minutes
      return _elapsed.inMinutes > 30;
    } else {
      // Standard delivery: 2 hours
      return _elapsed.inHours > 2;
    }
  }

  String? _getTimeLeft() {
    final targetMinutes = widget.deliveryMode == 'Express' ? 30 : 120;
    final remainingMinutes = targetMinutes - _elapsed.inMinutes;
    
    if (remainingMinutes <= 0) {
      return 'OVERDUE';
    }
    
    if (remainingMinutes <= 10) {
      return '$remainingMinutes min left';
    }
    
    return null; // Don't show time left if more than 10 minutes
  }
}
