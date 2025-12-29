import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'rider_history.dart'; // Links to the full history list

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String? _realRiderId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _findRiderProfile();
  }

  Future<void> _findRiderProfile() async {
    if (user?.email == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('riders')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();

      if (mounted) {
        if (snapshot.docs.isNotEmpty) {
          setState(() {
            _realRiderId = snapshot.docs.first.id;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_realRiderId == null) {
      return const Scaffold(body: Center(child: Text("Profile Not Linked")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Wallet"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('rider_id', isEqualTo: _realRiderId)
            .where('status', isEqualTo: 'Delivered')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // FIX: Convert to modifiable list to prevent "Read-Only List" crash
          var docs = snapshot.data!.docs.toList();

          // --- 1. CALCULATE TOTALS ---
          double totalDebt = 0;
          double lifetimeEarnings = 0;

          // Data for Graph
          Map<int, double> weeklyEarnings = {};
          DateTime now = DateTime.now();
          for (int i = 0; i < 7; i++) {
            weeklyEarnings[now.subtract(Duration(days: i)).weekday] = 0;
          }

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;

            // Financials
            double commission = (data['rider_commission'] ?? 0).toDouble();
            double deliveryFee = (data['delivery_fee'] ?? 0).toDouble();
            // Earnings = Commission (Rider keeps fee, but for stats we usually track commission)
            // If you want earnings to be Commission + Fee, uncomment next line:
            // double totalEarningsForOrder = commission + deliveryFee;
            double totalEarningsForOrder = commission;

            lifetimeEarnings += totalEarningsForOrder;

            // Debt Logic
            if (data['is_settled'] != true) {
              double cashCollected = (data['payment_method'] == 'COD')
                  ? (data['total_amount'] ?? 0).toDouble()
                  : 0;
              double paidSoFar = (data['amount_paid_so_far'] ?? 0).toDouble();

              // Debt = Cash - (Commission + DeliveryFee) - Paid
              double orderDebt =
                  (cashCollected - (commission + deliveryFee)) - paidSoFar;

              if (orderDebt > 0) totalDebt += orderDebt;
            }

            // Graph Logic
            Timestamp? deliveredAt = data['delivered_at'];
            if (deliveredAt != null) {
              DateTime date = deliveredAt.toDate();
              if (now.difference(date).inDays < 7) {
                weeklyEarnings[date.weekday] =
                    (weeklyEarnings[date.weekday] ?? 0) + totalEarningsForOrder;
              }
            }
          }

          // Sort docs for Recent List (Newest First)
          docs.sort((a, b) {
            Timestamp t1 = (a.data() as Map)['delivered_at'] ?? Timestamp.now();
            Timestamp t2 = (b.data() as Map)['delivered_at'] ?? Timestamp.now();
            return t2.compareTo(t1);
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 2. HERO CARD (Financial Status) ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.blue.shade900, Colors.blue.shade600]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Current Debt (To Deposit)",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text("₹${totalDebt.toStringAsFixed(0)}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      // --- UPDATED ROW: ONLY LIFETIME EARNINGS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text("Lifetime Earnings",
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                              Text("₹${lifetimeEarnings.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- 3. WEEKLY PERFORMANCE GRAPH ---
                const Text("Last 7 Days Earnings",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(15),
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: _buildWeeklyBarChart(weeklyEarnings),
                ),

                const SizedBox(height: 25),

                // --- 4. RECENT TRANSACTIONS HEADER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Recent Transactions",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        // Navigate to the FULL history screen
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RiderHistoryScreen()));
                      },
                      child: const Text("View All"),
                    ),
                  ],
                ),

                // --- 5. RECENT LIST (Max 5 items) ---
                if (docs.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text("No transactions yet.")))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length > 5 ? 5 : docs.length, // Limit to 5
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      double commission =
                          (data['rider_commission'] ?? 0).toDouble();
                      String displayOrderId = data['order_id']?.toString() ??
                          "KIRI-${docs[index].id.substring(0, 4).toUpperCase()}";

                      Timestamp? ts = data['delivered_at'];
                      String dateStr = ts != null
                          ? DateFormat('dd MMM').format(ts.toDate())
                          : "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.blue.shade50,
                                  child: const Icon(Icons.receipt_long,
                                      size: 18, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Order #$displayOrderId",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(dateStr,
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            Text("+ ₹${commission.toStringAsFixed(0)}",
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- CUSTOM BAR CHART WIDGET ---
  Widget _buildWeeklyBarChart(Map<int, double> data) {
    // 1. Find Max Earning to Normalize Height
    double maxVal = 0;
    data.forEach((k, v) {
      if (v > maxVal) maxVal = v;
    });
    if (maxVal == 0) maxVal = 100; // Avoid division by zero

    List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];
    DateTime today = DateTime.now();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        // Calculate correct day order ending with Today
        int dayIndex = (today.weekday - 1 - (6 - index));
        if (dayIndex < 0) dayIndex += 7;

        // Firestore Weekday: 1=Mon, 7=Sun
        int firestoreWeekday = dayIndex + 1;
        double earning = data[firestoreWeekday] ?? 0;

        // Height Percentage (Max height 100px)
        double barHeight = (earning / maxVal) * 100;
        if (barHeight < 5 && earning > 0) barHeight = 5; // Min visible height

        bool isToday = index == 6;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (earning > 0)
              Text("₹${earning.toInt()}",
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            const SizedBox(height: 5),
            Container(
              width: 12,
              height: barHeight == 0 ? 2 : barHeight,
              decoration: BoxDecoration(
                color: isToday ? Colors.blue : Colors.blue.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(weekDays[dayIndex],
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
          ],
        );
      }),
    );
  }
}
