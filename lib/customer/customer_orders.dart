import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Orders"),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customer_id', isEqualTo: user?.uid) // Only my orders
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var orders = snapshot.data!.docs;
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  Text("No orders yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              var data = orders[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'Pending';

              // Color code the status
              Color statusColor = Colors.orange;
              if (status == 'Delivered') statusColor = Colors.green;
              if (status == 'Shipped') statusColor = Colors.blue;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withAlpha(25),
                    child: Icon(Icons.local_shipping, color: statusColor),
                  ),
                  title: Text("Order #${orders[index].id.substring(0, 5)}"),
                  subtitle: Text("Total: ₹${data['total_amount'] ?? 0}"),
                  trailing: Chip(
                    label: Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    backgroundColor: statusColor,
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
