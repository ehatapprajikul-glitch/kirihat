import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'order_details.dart';
import 'product/enhanced_product_detail.dart'; // Import this to navigate to product details

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please Login")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Orders"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customer_id', isEqualTo: user.uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // 3. Empty State
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text("No orders yet",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          var orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              var data = orders[index].data() as Map<String, dynamic>;

              // --- DATA EXTRACTION ---
              String status = data['status'] ?? 'Pending';
              dynamic total = data['total_amount'] ?? 0;
              Timestamp? ts = data['created_at'];
              String orderId = data['order_id'] ?? orders[index].id;

              // Extract Items List
              List<dynamic> items = data['items'] ?? [];

              String dateStr = ts != null
                  ? DateFormat('MMM dd, yyyy').format(ts.toDate())
                  : "Just now";

              Color statusColor = Colors.orange;
              if (status == 'Delivered') statusColor = Colors.green;
              if (status == 'Cancelled') statusColor = Colors.red;

              return Card(
                elevation: 2, // Slight elevation for better look
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // --- TOP SECTION: Order Info (Clickable -> Order Details) ---
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailsScreen(orderDoc: orders[index]),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: statusColor.withAlpha(25),
                              radius: 18,
                              child: Icon(Icons.local_shipping,
                                  color: statusColor, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Order #$orderId",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    "Placed on $dateStr",
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "₹$total",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                Text(
                                  status,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    // --- MIDDLE SECTION: Product List (Clickable -> Product Details) ---
                    // We limit to showing first 2 items to keep list clean,
                    // or show all if you prefer. Here I show all.
                    ...items.map((item) {
                      return InkWell(
                        onTap: () {
                          // NAVIGATE TO PRODUCT DETAIL
                          if (item['productId'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EnhancedProductDetailScreen(
                                  productData: item,
                                  productId:
                                      item['productId'], // Pass ID safely
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade100)),
                          ),
                          child: Row(
                            children: [
                              // Product Image
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey[100],
                                  image: (item['imageUrl'] != null &&
                                          item['imageUrl'] != "")
                                      ? DecorationImage(
                                          image: NetworkImage(item['imageUrl']),
                                          fit: BoxFit.cover)
                                      : null,
                                ),
                                child: (item['imageUrl'] == null)
                                    ? const Icon(Icons.image,
                                        size: 20, color: Colors.grey)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // Product Name & Qty
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] ?? "Unknown Product",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      "Qty: ${item['quantity']}  •  ₹${item['price']}",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    }),

                    // --- BOTTOM SECTION: View Details Link ---
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailsScreen(orderDoc: orders[index]),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        alignment: Alignment.center,
                        child: const Text(
                          "View Full Order Details",
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
