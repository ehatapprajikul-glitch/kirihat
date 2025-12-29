import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderTimer extends StatefulWidget {
  final Timestamp createdAt;
  final String deliveryMode; // 'Standard' or 'Instant'
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
  Duration _timeLeft = Duration.zero;
  Color _timerColor = Colors.green;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    // Update every minute to save resources, or second for precision
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _calculateTime();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _calculateTime() {
    DateTime created = widget.createdAt.toDate();
    DateTime now = DateTime.now();
    DateTime deadline;

    // 1. SET DEADLINE BASED ON MODE
    if (widget.deliveryMode == 'Instant') {
      deadline = created.add(const Duration(minutes: 20));
    } else {
      deadline = created.add(const Duration(hours: 2));
    }

    // 2. CALCULATE DIFFERENCE
    Duration diff = deadline.difference(now);

    if (diff.isNegative) {
      setState(() {
        _isExpired = true;
        _timeLeft = Duration.zero;
        _timerColor = Colors.red;
      });
    } else {
      // 3. DETERMINE COLOR
      double totalMinutes = (widget.deliveryMode == 'Instant') ? 20.0 : 120.0;
      double remainingMinutes = diff.inMinutes.toDouble();
      Color color = Colors.green;

      if (remainingMinutes < (totalMinutes * 0.25)) {
        color = Colors.red; // Last 25%
      } else if (remainingMinutes < (totalMinutes * 0.5)) {
        color = Colors.orange; // Last 50%
      }

      setState(() {
        _isExpired = false;
        _timeLeft = diff;
        _timerColor = color;
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // If order is done, don't show timer
    if (widget.status == 'Delivered' || widget.status == 'Cancelled') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
        child: Text(widget.status,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _timerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _timerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 14, color: _timerColor),
          const SizedBox(width: 4),
          Text(
            _isExpired ? "LATE" : _formatDuration(_timeLeft),
            style: TextStyle(
                color: _timerColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
