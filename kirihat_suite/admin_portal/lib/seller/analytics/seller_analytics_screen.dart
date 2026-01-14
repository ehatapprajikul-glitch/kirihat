import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'seller_report_service.dart';

class SellerAnalyticsScreen extends StatefulWidget {
  final SellerModel seller;

  const SellerAnalyticsScreen({super.key, required this.seller});

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  final SellerService _sellerService = SellerService();
  final SellerReportService _reportService = SellerReportService();
  
  // State
  String _selectedRange = 'Today'; // Today, Week, Month
  Map<String, dynamic> _stats = {
    'totalRevenue': 0.0,
    'totalOrders': 0,
    'pendingOrders': 0,
    'deliveredOrders': 0,
    'cancelledOrders': 0,
  };
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    // Calculate Date Range
    DateTime now = DateTime.now();
    DateTime start;
    if (_selectedRange == 'Today') {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedRange == 'Week') {
      start = now.subtract(const Duration(days: 7));
    } else {
      start = now.subtract(const Duration(days: 30));
    }

    try {
      // Fetch Orders
      // Note: In a real app, use a query with startAt/endAt on 'created_at'
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('seller_ids', arrayContains: widget.seller.id)
          .orderBy('created_at', descending: true)
          .get();

      List<Map<String, dynamic>> filteredOrders = [];
      double revenue = 0;
      int pending = 0;
      int delivered = 0;
      int cancelled = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final created = (data['created_at'] as Timestamp).toDate();
        
        if (created.isAfter(start)) {
          // Process Order Items for this seller
          final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
          final myItems = items.where((i) => i['seller_id'] == widget.seller.id).toList();
          
          double orderTotal = 0;
          for (var item in myItems) {
            orderTotal += ((item['selling_price'] ?? 0) * (item['quantity'] ?? 1)).toDouble();
          }

          if (myItems.isNotEmpty) {
             final status = data['status'] ?? 'Pending';
             
             // Update Stats
             if (status == 'Delivered') {
               revenue += orderTotal;
               delivered++;
             } else if (status == 'Cancelled') {
               cancelled++;
             } else {
               pending++;
             }

             // Add to list
             filteredOrders.add({
               'order_id': data['order_id'] ?? doc.id,
               'created_at': created,
               'status': status,
               'total': orderTotal,
               'items': myItems,
             });
          }
        }
      }

      if (mounted) {
        setState(() {
          _stats = {
            'totalRevenue': revenue,
            'totalOrders': filteredOrders.length,
            'pendingOrders': pending,
            'deliveredOrders': delivered,
            'cancelledOrders': cancelled,
          };
          _orders = filteredOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateReport() async {
    // Show Loading
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Report...')));
    
    DateTime now = DateTime.now();
    DateTime start;
    if (_selectedRange == 'Today') {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedRange == 'Week') {
      start = now.subtract(const Duration(days: 7));
    } else {
      start = now.subtract(const Duration(days: 30));
    }

    // Platform Fee Logic (Example: 10%)
    double gross = _stats['totalRevenue'];
    double fees = gross * 0.10;
    double net = gross - fees;

    await _reportService.generatePdfReport(
      seller: widget.seller,
      orders: _orders,
      startDate: start,
      endDate: now,
      totalRevenue: gross,
      platformFees: fees,
      netEarnings: net,
    );
     // Success is handled by printing package UI usually, or file saved
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Professional light background
      body: CustomScrollView(
        slivers: [
          // 1. Modern Header
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D9759), Color(0xFF075E3B)], // Kirihat Green
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sales Dashboard', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Here\'s how your business is performing ${_selectedRange.toLowerCase()}.', 
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
               preferredSize: const Size.fromHeight(60),
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                 decoration: const BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                 ),
                 child: Row(
                   children: [
                     _buildRangeChip('Today'),
                     const SizedBox(width: 12),
                     _buildRangeChip('Week'),
                     const SizedBox(width: 12),
                     _buildRangeChip('Month'),
                     const Spacer(),
                     IconButton(
                       onPressed: _generateReport,
                       icon: const Icon(Icons.download_rounded, color: Color(0xFF0D9759)),
                       tooltip: 'Export Report',
                     ),
                   ],
                 ),
               ),
            ),
          ),

          // 2. Dashboard Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_isLoading) 
                   const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                else ...[
                  // Scorecards
                  Row(
                    children: [
                      Expanded(child: _buildScoreCard('Revenue', '₹${NumberFormat('#,##0').format(_stats['totalRevenue'])}', Icons.currency_rupee, Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildScoreCard('Orders', '${_stats['totalOrders']}', Icons.shopping_bag, Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildScoreCard('Returns', '0', Icons.assignment_return, Colors.red)), // Placeholder
                      const SizedBox(width: 12),
                      Expanded(child: _buildScoreCard('Pending', '${_stats['pendingOrders']}', Icons.hourglass_empty, Colors.orange)),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // Financial Breakdown
                  _buildFinancialBreakdown(),
                  
                  const SizedBox(height: 24),

                  // Recent Transactions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Sells', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: (){}, child: const Text('View All')),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Transactions List
                  if (_orders.isEmpty)
                    _buildEmptyState()
                  else
                    ..._orders.take(5).map((order) => _buildTransactionCard(order)),
                    
                  const SizedBox(height: 80), // Bottom padding
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChip(String label) {
    final isSelected = _selectedRange == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedRange = label);
        _fetchData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9759) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0D9759) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 18,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFinancialBreakdown() {
    double gross = _stats['totalRevenue'];
    double fees = gross * 0.10; // 10% Platform Fee
    double tax = gross * 0.05; // 5% Tax Est
    double net = gross - fees - tax;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payout Estimate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(height: 30),
          _buildFinanceRow('Gross Sales', gross, Colors.black),
          const SizedBox(height: 12),
          _buildFinanceRow('Platform Fees (10%)', -fees, Colors.orange),
          const SizedBox(height: 12),
          _buildFinanceRow('Tax Est. (5%)', -tax, Colors.red[300]!),
          const Divider(height: 30),
          _buildFinanceRow('Net Earnings', net, const Color(0xFF0D9759), isBold: true),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(String label, double amount, Color color, {bool isBold = false}) {
    final formatted = NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(amount.abs());
    final display = amount < 0 ? '- $formatted' : formatted;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        Text(
          display, 
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 16 : 14,
            color: color
          )
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> order) {
    final status = order['status'];
    Color statusColor = Colors.grey;
    if (status == 'Delivered') statusColor = Colors.green;
    else if (status == 'Pending') statusColor = Colors.orange;
    else if (status == 'Cancelled') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
           Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
             child: const Icon(Icons.shopping_cart_outlined, size: 20),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('Order #${order['order_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                 Text(
                   DateFormat('MMM dd, hh:mm a').format(order['created_at']),
                   style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                 ),
               ],
             ),
           ),
           Column(
             crossAxisAlignment: CrossAxisAlignment.end,
             children: [
               Text(
                 '₹${NumberFormat('#,##0').format(order['total'])}', 
                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
               ),
               const SizedBox(height: 4),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(
                   color: statusColor.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(4),
                 ),
                 child: Text(
                   status.toUpperCase(),
                   style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                 ),
               ),
             ],
           ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No analytics data for $_selectedRange', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

