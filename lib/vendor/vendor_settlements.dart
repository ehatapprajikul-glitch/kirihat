import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rider_settlement_history.dart';

class VendorSettlementsScreen extends StatefulWidget {
  const VendorSettlementsScreen({super.key});

  @override
  State<VendorSettlementsScreen> createState() =>
      _VendorSettlementsScreenState();
}

class _VendorSettlementsScreenState extends State<VendorSettlementsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null)
      return const Scaffold(body: Center(child: Text("Login Required")));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Rider Settlements"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('riders')
            .where('vendor_id', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var riders = snapshot.data!.docs;

          if (riders.isEmpty)
            return const Center(child: Text("No Riders Linked"));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: riders.length,
            itemBuilder: (context, index) {
              var riderData = riders[index].data() as Map<String, dynamic>;
              String riderId = riders[index].id;

              return _RiderDebtCard(
                riderId: riderId,
                riderName: riderData['name'] ?? "Unknown Rider",
                riderPhone: riderData['phone'] ?? "No Phone",
                vendorId: user!.uid,
              );
            },
          );
        },
      ),
    );
  }
}

class _RiderDebtCard extends StatelessWidget {
  final String riderId;
  final String riderName;
  final String riderPhone;
  final String vendorId;

  const _RiderDebtCard({
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.vendorId,
  });

  // --- LOGIC: SMART PARTIAL SETTLEMENT ---
  Future<void> _showSettlementDialog(BuildContext context,
      List<QueryDocumentSnapshot> orders, double totalDebt) async {
    final TextEditingController amountCtrl =
        TextEditingController(text: totalDebt.toStringAsFixed(0));

    // Sort Oldest First
    orders.sort((a, b) {
      Timestamp t1 = (a.data() as Map)['delivered_at'] ?? Timestamp.now();
      Timestamp t2 = (b.data() as Map)['delivered_at'] ?? Timestamp.now();
      return t1.compareTo(t2);
    });

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Collect Cash from $riderName"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Outstanding: ₹${totalDebt.toStringAsFixed(0)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 16)),
            const SizedBox(height: 15),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Enter Amount Received",
                prefixText: "₹ ",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 5),
            const Text("System will settle oldest orders first.",
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              double enteredAmount = double.tryParse(amountCtrl.text) ?? 0;
              if (enteredAmount <= 0) return;
              if (enteredAmount > totalDebt + 10) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Amount cannot be more than total debt")));
                return;
              }

              Navigator.pop(context);
              _processSettlement(context, orders, enteredAmount, totalDebt);
            },
            child: const Text("Settle Now"),
          )
        ],
      ),
    );
  }

  Future<void> _processSettlement(
      BuildContext context,
      List<QueryDocumentSnapshot> orders,
      double amountPayable,
      double totalDebtAtTime) async {
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      double remainingMoney = amountPayable;
      int settledCount = 0;

      for (var doc in orders) {
        if (remainingMoney <= 0) break;

        var data = doc.data() as Map<String, dynamic>;

        // --- NEW MATH ---
        double commission = (data['rider_commission'] ?? 0).toDouble();
        double deliveryFee =
            (data['delivery_fee'] ?? 0).toDouble(); // Rider keeps this too
        double cashCollected = (data['payment_method'] == 'COD')
            ? (data['total_amount'] ?? 0).toDouble()
            : 0;
        double paidSoFar = (data['amount_paid_so_far'] ?? 0).toDouble();

        // Debt = Cash - (Commission + DeliveryFee) - AlreadyPaid
        double orderDebt =
            (cashCollected - (commission + deliveryFee)) - paidSoFar;

        if (orderDebt <= 0) {
          // If debt is 0 or negative (Vendor owes Rider), we mark as settled immediately to clear list
          batch.update(doc.reference,
              {'is_settled': true, 'settled_at': FieldValue.serverTimestamp()});
          continue;
        }

        if (remainingMoney >= orderDebt) {
          batch.update(doc.reference, {
            'is_settled': true,
            'amount_paid_so_far': FieldValue.increment(orderDebt),
            'settled_at': FieldValue.serverTimestamp(),
          });
          remainingMoney -= orderDebt;
          settledCount++;
        } else {
          batch.update(doc.reference, {
            'amount_paid_so_far': FieldValue.increment(remainingMoney),
            'last_partial_payment': FieldValue.serverTimestamp(),
          });
          remainingMoney = 0;
        }
      }

      // History Record
      DocumentReference settlementRef =
          FirebaseFirestore.instance.collection('settlements').doc();
      batch.set(settlementRef, {
        'vendor_id': vendorId,
        'rider_id': riderId,
        'rider_name': riderName,
        'amount_collected': amountPayable,
        'total_debt_snapshot': totalDebtAtTime,
        'orders_cleared_count': settledCount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("Success! Collected ₹${amountPayable.toStringAsFixed(0)}"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RiderSettlementHistoryScreen(
                riderId: riderId, riderName: riderName)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('rider_id', isEqualTo: riderId)
          .where('vendor_id', isEqualTo: vendorId)
          .where('status', isEqualTo: 'Delivered')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        var allDocs = snapshot.data!.docs;

        var pendingOrders = allDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['is_settled'] != true;
        }).toList();

        double totalDebt = 0;

        for (var doc in pendingOrders) {
          var data = doc.data() as Map<String, dynamic>;

          // --- NEW MATH ---
          double commission = (data['rider_commission'] ?? 0).toDouble();
          double deliveryFee = (data['delivery_fee'] ?? 0).toDouble();
          double cashCollected = (data['payment_method'] == 'COD')
              ? (data['total_amount'] ?? 0).toDouble()
              : 0;
          double paidSoFar = (data['amount_paid_so_far'] ?? 0).toDouble();

          // Debt = Cash - (Commission + DeliveryFee) - AlreadyPaid
          double orderDebt =
              (cashCollected - (commission + deliveryFee)) - paidSoFar;

          totalDebt += orderDebt;
        }

        if (totalDebt < 1) totalDebt = 0;

        if (pendingOrders.isEmpty || totalDebt <= 0) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: Colors.green[50],
            child: ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check, color: Colors.white)),
              title: Text(riderName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("No outstanding debt ($riderPhone)"),
              trailing: const Text("₹0",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green)),
              onTap: () => _navigateToHistory(context),
            ),
          );
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: const Icon(Icons.priority_high,
                                color: Colors.white)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(riderName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(riderPhone,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("To Collect",
                            style: TextStyle(fontSize: 10, color: Colors.red)),
                        Text("₹${totalDebt.toStringAsFixed(0)}",
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      ],
                    )
                  ],
                ),
                const Divider(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _navigateToHistory(context),
                      icon: const Icon(Icons.history,
                          size: 16, color: Colors.blue),
                      label: const Text("History",
                          style: TextStyle(color: Colors.blue)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showSettlementDialog(
                          context, pendingOrders, totalDebt),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.payments, size: 16),
                      label: const Text("COLLECT"),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
