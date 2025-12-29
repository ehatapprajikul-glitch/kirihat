import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'vendor_product_detail.dart'; // Ensure this file exists
import '../widgets/order_timer.dart'; // Ensure this file exists

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // --- 1. PDF GENERATOR ---
  Future<void> _generateShippingLabel(
      Map<String, dynamic> orderData, String orderId) async {
    final doc = pw.Document();
    final address = orderData['delivery_address'] ?? {};
    String name = (address['name'] ?? "Customer").toUpperCase();

    // Fix: Robust Address Joining
    String fullAddressLine = [
      address['house_no'],
      address['street'],
      address['city'],
      address['pincode']
    ]
        .where((s) => s != null && s.toString().trim().isNotEmpty)
        .map((s) => s.toString())
        .join(", ");

    String phone = address['phone'] ?? "N/A";
    final items = orderData['items'] as List<dynamic>? ?? [];
    final dateStr = orderData['created_at'] != null
        ? DateFormat('yyyy-MM-dd')
            .format((orderData['created_at'] as Timestamp).toDate())
        : "N/A";

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                height: 60,
                child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: orderId,
                    drawText: true,
                    height: 50,
                    width: 200),
              ),
              pw.Divider(),
              pw.Text("DELIVERY ADDRESS:",
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 5),
              pw.Text(name,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text(fullAddressLine),
              pw.Text("Phone: $phone"),
              pw.SizedBox(height: 20),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Order Date: $dateStr"),
                    pw.Text("Payment: ${orderData['payment_method'] ?? 'COD'}")
                  ]),
              pw.Divider(),
              pw.Table.fromTextArray(
                context: context,
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                headers: ['Product', 'Qty', 'Price'],
                data: items
                    .map((item) => [
                          (item['name'] ?? "Item").toString(),
                          "${item['quantity']}",
                          "${item['price']}"
                        ])
                    .toList(),
              ),
              pw.Divider(),
              pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text("TOTAL: ${orderData['total_amount']}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 18))),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  // --- 2. SHIP ORDER (LOGIC) ---
  Future<void> _shipOrderWithRider(DocumentSnapshot orderDoc,
      Map<String, dynamic> riderData, String riderId) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot freshOrder = await transaction.get(orderDoc.reference);
        if (!freshOrder.exists) throw "Order missing";

        Map<String, dynamic> orderData =
            freshOrder.data() as Map<String, dynamic>;

        // 1. Deduct Stock
        List<dynamic> items = orderData['items'] ?? [];
        for (var item in items) {
          String? productId = item['productId'];
          int qty = item['quantity'] ?? 1;
          if (productId != null) {
            DocumentReference prodRef = FirebaseFirestore.instance
                .collection('products')
                .doc(productId);
            DocumentSnapshot prodSnap = await transaction.get(prodRef);
            if (prodSnap.exists) {
              int currentStock =
                  (prodSnap.data() as Map<String, dynamic>)['stock_quantity'] ??
                      0;
              transaction.update(prodRef, {
                'stock_quantity':
                    (currentStock - qty) < 0 ? 0 : (currentStock - qty)
              });
            }
          }
        }

        // 2. Generate Delivery PIN
        String otp = (1000 + Random().nextInt(9000)).toString();

        // 3. Update Order Status
        transaction.update(orderDoc.reference, {
          'status': 'Shipped',
          'rider_id': riderId,
          'rider_name': riderData['name'],
          'rider_phone': riderData['phone'],
          'delivery_pin': otp,
          'shipped_at': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Order Assigned to ${riderData['name']}!")));
        Navigator.pop(context); // Close the rider selection dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- 3. SHOW RIDER SELECTION DIALOG ---
  void _showRiderSelectionDialog(DocumentSnapshot orderDoc) {
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select a Rider",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Assign this order to an active rider.",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('riders')
                      .where('vendor_id', isEqualTo: currentUser!.uid)
                      .where('status',
                          isEqualTo: 'Active') // Only show active riders
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    var riders = snapshot.data!.docs;

                    if (riders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.no_accounts,
                                size: 50, color: Colors.grey),
                            const SizedBox(height: 10),
                            const Text("No Active Riders Found"),
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Close"))
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: riders.length,
                      itemBuilder: (context, index) {
                        var rider =
                            riders[index].data() as Map<String, dynamic>;
                        return Card(
                          elevation: 0,
                          color: Colors.grey[100],
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.two_wheeler,
                                    color: Colors.white)),
                            title: Text(rider['name'] ?? "Unknown"),
                            subtitle: Text(rider['phone'] ?? ""),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white),
                              onPressed: () => _shipOrderWithRider(
                                  orderDoc, rider, riders[index].id),
                              child: const Text("Assign"),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
            title: const Text("Order Management"),
            backgroundColor: Colors.orange[100],
            bottom: const TabBar(tabs: [
              Tab(text: "Active (Pending)"),
              Tab(text: "History (Shipped/Done)")
            ])),
        body: Column(
          children: [
            // --- BARCODE / SEARCH SCANNER BAR ---
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Scan Barcode or Type Order ID...",
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    },
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toUpperCase());
                },
              ),
            ),

            // --- ORDER LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('orders').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  var allDocs = snapshot.data!.docs;

                  // Filter for this Vendor
                  var myOrders = allDocs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String? orderVendorId = data['vendor_id'];
                    bool isMine = orderVendorId == currentUser?.uid ||
                        orderVendorId == currentUser?.email;

                    // Search Logic (Barcode Scanner)
                    if (_searchQuery.isNotEmpty) {
                      String orderId =
                          (data['order_id'] ?? doc.id).toString().toUpperCase();
                      if (!orderId.contains(_searchQuery)) return false;
                    }
                    return isMine;
                  }).toList();

                  // Sort Newest First
                  myOrders.sort((a, b) {
                    Timestamp t1 =
                        (a.data() as Map)['created_at'] ?? Timestamp.now();
                    Timestamp t2 =
                        (b.data() as Map)['created_at'] ?? Timestamp.now();
                    return t2.compareTo(t1);
                  });

                  var activeOrders = myOrders.where((d) {
                    String status = (d['status'] ?? 'Pending');
                    return status == 'Pending' || status == 'Processing';
                  }).toList();

                  var historyOrders = myOrders.where((d) {
                    String status = (d['status'] ?? 'Pending');
                    return status != 'Pending' && status != 'Processing';
                  }).toList();

                  return TabBarView(children: [
                    _buildOrderList(activeOrders, isActiveTab: true),
                    _buildOrderList(historyOrders, isActiveTab: false)
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<QueryDocumentSnapshot> orders,
      {required bool isActiveTab}) {
    if (orders.isEmpty) {
      return Center(
          child:
              Text(isActiveTab ? "No pending orders." : "No history found."));
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
        String orderId = data['order_id']?.toString() ??
            doc.id.substring(0, 8).toUpperCase();

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Order #$orderId",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: OrderTimer(
                              createdAt: data['created_at'] ?? Timestamp.now(),
                              deliveryMode: data['delivery_mode'] ?? 'Standard',
                              status: status),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color:
                              isActiveTab ? Colors.orange[50] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color:
                                  isActiveTab ? Colors.orange : Colors.blue)),
                      child: Text(status,
                          style: TextStyle(
                              color:
                                  isActiveTab ? Colors.deepOrange : Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Divider(),
                if (!isActiveTab && data['rider_name'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.two_wheeler,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                          "Rider: ${data['rider_name']} (${data['rider_phone']})",
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12))
                    ]),
                  ),
                ...items.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            image: DecorationImage(
                                image: NetworkImage(item['imageUrl'] ?? ""),
                                fit: BoxFit.cover))),
                    title: Text("${item['quantity']}x ${item['name']}",
                        style: const TextStyle(fontSize: 14)),
                    trailing: isActiveTab
                        ? IconButton(
                            icon: const Icon(Icons.print, color: Colors.grey),
                            onPressed: () =>
                                _generateShippingLabel(data, orderId))
                        : null,
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total: ₹$total",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (isActiveTab)
                      ElevatedButton.icon(
                          onPressed: () => _showRiderSelectionDialog(doc),
                          icon: const Icon(Icons.local_shipping, size: 16),
                          label: const Text("Select Rider & Ship"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white)),
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
