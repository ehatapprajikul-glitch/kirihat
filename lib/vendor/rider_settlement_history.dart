import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RiderSettlementHistoryScreen extends StatelessWidget {
  final String riderId;
  final String riderName;

  const RiderSettlementHistoryScreen({
    super.key,
    required this.riderId,
    required this.riderName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("$riderName's History"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('settlements')
            .where('rider_id', isEqualTo: riderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No settlement history found.",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Sort Manually (Newest First)
          docs.sort((a, b) {
            Timestamp t1 = (a.data() as Map)['timestamp'] ?? Timestamp.now();
            Timestamp t2 = (b.data() as Map)['timestamp'] ?? Timestamp.now();
            return t2.compareTo(t1);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;

              // 1. Data Parsing
              Timestamp? ts = data['timestamp'];
              String dateStr = ts != null
                  ? DateFormat('dd MMM yyyy').format(ts.toDate())
                  : "Unknown Date";
              String timeStr =
                  ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : "";

              double paidAmount = (data['amount_collected'] ?? 0).toDouble();
              double totalDebtSnapshot =
                  (data['total_debt_snapshot'] ?? paidAmount)
                      .toDouble(); // Fallback to paid if missing
              double remainingAfterThis = totalDebtSnapshot - paidAmount;
              if (remainingAfterThis < 0) remainingAfterThis = 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                    border: Border(
                        left: BorderSide(
                            color: Colors.green.shade600, width: 5))),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header: Date and Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Settlement Record",
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                          Text("$dateStr • $timeStr",
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                      const Divider(height: 20),

                      // Body: Amount Paid
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Cash Received",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                "₹${paidAmount.toStringAsFixed(0)}",
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green),
                              ),
                            ],
                          ),
                          // Context: "Out of Total"
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("Total Pending Was",
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              Text("₹${totalDebtSnapshot.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 4),
                              if (remainingAfterThis > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    "Bal: ₹${remainingAfterThis.toStringAsFixed(0)}",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    "Fully Settled",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
