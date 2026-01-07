import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VendorEarningsScreen extends StatelessWidget {
  const VendorEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final currencyFormat = NumberFormat.currency(
        symbol: '₹', decimalDigits: 0); // No decimals for cleaner look

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Financial Overview"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .snapshots(), // Listening to all orders to filter client-side
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No financial data yet."));
          }

          var allDocs = snapshot.data!.docs;

          // 1. Filter for THIS Vendor
          var vendorDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['vendor_id'] == user?.uid ||
                data['vendor_id'] == user?.email;
          }).toList();

          // 2. Sort by Date (Newest First)
          vendorDocs.sort((a, b) {
            Timestamp t1 = (a.data() as Map)['created_at'] ?? Timestamp.now();
            Timestamp t2 = (b.data() as Map)['created_at'] ?? Timestamp.now();
            return t2.compareTo(t1);
          });

          // --- FINANCIAL CALCULATIONS (The "Smart" Logic) ---
          double totalVendorRevenue =
              0; // Net profit (Product Price - Commission)
          double cashCurrentlyWithRiders = 0; // Money riders owe you RIGHT NOW
          double totalLifeTimeSales = 0; // Gross Sales

          for (var doc in vendorDocs) {
            var data = doc.data() as Map<String, dynamic>;
            String status = data['status'] ?? 'Pending';

            // Financial Values
            double totalOrderAmount = (data['total_amount'] ?? 0).toDouble();
            double riderComm = (data['rider_commission'] ?? 0).toDouble();
            double deliveryFee = (data['delivery_fee'] ?? 0).toDouble();

            // 1. Lifetime Sales (Gross)
            if (status == 'Delivered') {
              totalLifeTimeSales += totalOrderAmount;

              // 2. Vendor Revenue (Your Share)
              // You get: Total - (RiderCommission + DeliveryFee)
              double yourShare = totalOrderAmount - (riderComm + deliveryFee);
              totalVendorRevenue += yourShare;

              // 3. Cash with Riders (Debt Logic)
              if (data['is_settled'] != true) {
                double cashCollected =
                    (data['payment_method'] == 'COD') ? totalOrderAmount : 0;
                double paidSoFar = (data['amount_paid_so_far'] ?? 0).toDouble();

                // Debt = CashCollected - (RiderEarnings) - PaidSoFar
                // RiderEarnings = Commission + DeliveryFee
                double debtOnOrder =
                    (cashCollected - (riderComm + deliveryFee)) - paidSoFar;

                if (debtOnOrder > 0) {
                  cashCurrentlyWithRiders += debtOnOrder;
                }
              }
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. MAIN REVENUE CARD
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade900, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text("NET EARNINGS (Your Share)",
                          style: TextStyle(
                              color: Colors.white70,
                              letterSpacing: 1.0,
                              fontSize: 12)),
                      const SizedBox(height: 10),
                      Text(currencyFormat.format(totalVendorRevenue),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Container(height: 1, color: Colors.white24),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBalanceSubItem("Gross Sales",
                              currencyFormat.format(totalLifeTimeSales)),
                          _buildBalanceSubItem("Cash with Riders",
                              currencyFormat.format(cashCurrentlyWithRiders),
                              isWarning: true),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. ACTIONS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Payout Request Sent")));
                          },
                          icon: const Icon(Icons.account_balance),
                          label: const Text("Withdraw"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to Settlements Page
                            // Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorSettlementsScreen()));
                          },
                          icon: const Icon(Icons.people_alt),
                          label: const Text("Settlements"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // 3. RECENT TRANSACTIONS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text("Recent Orders",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vendorDocs.length > 10
                      ? 10
                      : vendorDocs.length, // Show max 10
                  itemBuilder: (context, index) {
                    var data = vendorDocs[index].data() as Map<String, dynamic>;
                    String orderId =
                        vendorDocs[index].id.substring(0, 4).toUpperCase();
                    double total = (data['total_amount'] ?? 0).toDouble();
                    String status = data['status'] ?? 'Pending';
                    Timestamp created = data['created_at'] ?? Timestamp.now();
                    String dateStr =
                        DateFormat('MMM d').format(created.toDate());

                    // Calculate Vendor Share for this specific item
                    double comm = (data['rider_commission'] ?? 0).toDouble();
                    double fee = (data['delivery_fee'] ?? 0).toDouble();
                    double netShare = total - (comm + fee);

                    IconData icon = Icons.access_time;
                    Color color = Colors.grey;
                    if (status == 'Delivered') {
                      icon = Icons.check_circle;
                      color = Colors.green;
                    } else if (status == 'Cancelled') {
                      icon = Icons.cancel;
                      color = Colors.red;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text("Order #$orderId"),
                        subtitle: Text("$dateStr • $status"),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("+${currencyFormat.format(netShare)}",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: status == 'Delivered'
                                        ? Colors.black
                                        : Colors.grey)),
                            if (status == 'Delivered')
                              Text("Gross: ${currencyFormat.format(total)}",
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceSubItem(String label, String value,
      {bool isWarning = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: isWarning ? Colors.orangeAccent : Colors.white70,
                fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ],
    );
  }
}
