import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  void _markAsShipped(String docId) {
    FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': 'Shipped',
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Order Management"),
          backgroundColor: Colors.orange[100],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Active (Pending)"),
              Tab(text: "History (Shipped/Done)"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('vendor_id', isEqualTo: currentUser?.email)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text("No orders found."));
            }

            var activeOrders = docs
                .where((d) => (d['status'] ?? 'Pending') == 'Pending')
                .toList();
            var historyOrders = docs
                .where((d) => (d['status'] ?? 'Pending') != 'Pending')
                .toList();

            return TabBarView(
              children: [
                _buildOrderList(activeOrders, showActionButton: true),
                _buildOrderList(historyOrders, showActionButton: false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderList(
    List<QueryDocumentSnapshot> orders, {
    required bool showActionButton,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          showActionButton ? "No pending orders." : "No history found.",
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        var doc = orders[index];
        var data = doc.data() as Map<String, dynamic>;

        List<dynamic> items = data['items'] ?? [];
        String status = data['status'] ?? 'Pending';
        double total = (data['total_amount'] ?? 0).toDouble();

        Color statusColor = Colors.orange;
        if (status == 'Shipped') {
          statusColor = Colors.blue;
        } else if (status == 'Delivered') {
          statusColor = Colors.green;
        } else if (status == 'Cancelled') {
          statusColor = Colors.red;
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Order #${doc.id.substring(0, 5).toUpperCase()}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(
                      data['customer_phone'] ?? "Unknown Customer",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${item['qty']}x ${item['name']}",
                          style: const TextStyle(fontSize: 15),
                        ),
                        Text(
                          "₹${item['price'] * item['qty']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total: ₹$total",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    if (showActionButton && status == 'Pending')
                      ElevatedButton(
                        onPressed: () => _markAsShipped(doc.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Mark Shipped"),
                      ),
                    if (!showActionButton && status == 'Shipped')
                      const Text(
                        "Wait for Rider",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
