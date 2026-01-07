import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/seller_model.dart';
import '../../services/seller_service.dart';

class SellerBillingScreen extends StatefulWidget {
  final SellerModel seller;

  const SellerBillingScreen({super.key, required this.seller});

  @override
  State<SellerBillingScreen> createState() => _SellerBillingScreenState();
}

class _SellerBillingScreenState extends State<SellerBillingScreen> with SingleTickerProviderStateMixin {
  final SellerService _sellerService = SellerService();
  late TabController _tabController;
  
  // Mock Data for Payouts (Since we don't have a payouts collection yet)
  final List<Map<String, dynamic>> _payouts = [
    // {'id': 'PAY-1001', 'amount': 15000.00, 'date': DateTime.now().subtract(const Duration(days: 7)), 'status': 'Paid'},
    // {'id': 'PAY-1002', 'amount': 8500.50, 'date': DateTime.now().subtract(const Duration(days: 14)), 'status': 'Paid'},
  ];

  double _currentBalance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    // For MVP, Balance = Revenue of Delivered Orders (Assuming 0 commission deduction logic for display simplicity here)
    // In real world: Balance = (Delivered Orders - Commission) - Paid Payouts
    final stats = await _sellerService.getSellerStats(widget.seller.id);
    if (mounted) {
      setState(() {
        _currentBalance = stats['totalRevenue']; // Simplified
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header & Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Billing & Payments', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9759), Color(0xFF0B7A48)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0D9759).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          _isLoading
                              ? const SizedBox(height: 30, width: 30, child: CircularProgressIndicator(color: Colors.white))
                              : Text(
                                  '₹${NumberFormat('#,##0.00').format(_currentBalance)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Next Payout: Mon, Jan 12', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {}, // Withdraw Functionality
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D9759),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Withdraw'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0D9759),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0D9759),
            tabs: const [
              Tab(text: 'Transactions'),
              Tab(text: 'Payouts'),
            ],
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(),
                _buildPayoutsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    // Shows recent credited orders
    return StreamBuilder(
      stream: _sellerService.getSellerOrders(widget.seller.id, limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState('No transactions yet');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
             final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
             final amount = (data['total_amount'] ?? 0).toDouble();
             final status = data['status'];
             // Only show delivered or money-related statuses
             if (status != 'Delivered' && status != 'Completed') return const SizedBox.shrink();

             return Card(
               margin: const EdgeInsets.only(bottom: 12),
               elevation: 0,
               color: Colors.white,
               child: ListTile(
                 leading: CircleAvatar(
                   backgroundColor: Colors.green.shade50,
                   child: const Icon(Icons.arrow_downward, color: Colors.green),
                 ),
                 title: Text('Order Payment #${data['order_id'] ?? "Unknown"}'),
                 subtitle: Text(DateFormat('MMM dd, yyyy').format((data['created_at'] as Timestamp).toDate())),
                 trailing: Text(
                   '+ ₹$amount',
                   style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                 ),
               ),
             );
          },
        );
      },
    );
  }

  Widget _buildPayoutsTab() {
    if (_payouts.isEmpty) return _buildEmptyState('No payouts processed yet');
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payouts.length,
      itemBuilder: (context, index) {
        final payout = _payouts[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.account_balance, color: Colors.white)),
            title: Text('Payout ${payout['id']}'),
            subtitle: Text(DateFormat('MMM dd, yyyy').format(payout['date'])),
            trailing: Text('₹${payout['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }
}
