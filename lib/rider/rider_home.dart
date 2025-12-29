import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isOnline = true;
  String? _realRiderId;

  @override
  void initState() {
    super.initState();
    _findRiderProfile();
  }

  Future<void> _findRiderProfile() async {
    if (user?.email == null) return;
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('riders')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        setState(() => _realRiderId = snapshot.docs.first.id);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: _isOnline ? Colors.blue[700] : Colors.grey[700],
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rider Dashboard",
                style: TextStyle(fontSize: 14, color: Colors.white70)),
            Text(user?.displayName ?? "Duty Mode",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        actions: [
          Switch(
            value: _isOnline,
            activeThumbColor: Colors.greenAccent,
            onChanged: (val) => setState(() => _isOnline = val),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // STATUS BANNER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        _isOnline ? Colors.green[100] : Colors.grey[200],
                    child: Icon(
                        _isOnline ? Icons.power_settings_new : Icons.power_off,
                        color: _isOnline ? Colors.green : Colors.grey,
                        size: 30),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Status",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14)),
                      Text(_isOnline ? "YOU ARE ONLINE" : "YOU ARE OFFLINE",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _isOnline ? Colors.green : Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // LIVE METRICS STREAM
            if (_realRiderId != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('rider_id', isEqualTo: _realRiderId)
                    .where('status', isEqualTo: 'Delivered')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();

                  var docs = snapshot.data!.docs;

                  // --- SYNCED MATH WITH HISTORY TAB ---
                  double lifetimeEarnings = 0;
                  double currentDebt = 0;
                  int trips = docs.length;

                  for (var doc in docs) {
                    var data = doc.data() as Map<String, dynamic>;

                    // 1. Earnings (Commission Only, as per History Tab)
                    double commission =
                        (data['rider_commission'] ?? 0).toDouble();
                    double deliveryFee = (data['delivery_fee'] ?? 0).toDouble();

                    lifetimeEarnings += commission;

                    // 2. Debt Calculation (Include Delivery Fee logic)
                    if (data['is_settled'] != true) {
                      double cashCollected = (data['payment_method'] == 'COD')
                          ? (data['total_amount'] ?? 0).toDouble()
                          : 0;
                      double paidSoFar =
                          (data['amount_paid_so_far'] ?? 0).toDouble();

                      // Debt = Cash - (Commission + DeliveryFee) - Paid
                      double orderDebt =
                          (cashCollected - (commission + deliveryFee)) -
                              paidSoFar;

                      if (orderDebt > 0) currentDebt += orderDebt;
                    }
                  }

                  return Column(
                    children: [
                      // ROW 1: Earnings & Trips
                      Row(
                        children: [
                          _buildStatCard(
                              "Total Earnings",
                              "₹${lifetimeEarnings.toStringAsFixed(0)}",
                              Icons.account_balance_wallet,
                              Colors.purple),
                          const SizedBox(width: 15),
                          _buildStatCard("Trips Done", "$trips",
                              Icons.check_circle, Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // ROW 2: CASH TO DEPOSIT (Cleaned Up)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.redAccent.shade700,
                            Colors.redAccent.shade400
                          ]),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text("CASH TO DEPOSIT",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                            const SizedBox(height: 5),
                            Text("₹${currentDebt.toStringAsFixed(0)}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            const Text("Return this amount to Vendor",
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("Loading Profile..."),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 20,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 15),
            Text(value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
