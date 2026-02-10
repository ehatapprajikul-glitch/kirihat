import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kirihat_core/services/notification_service.dart';
import 'package:kirihat_core/utils/currency_helper.dart';
import '../widgets/order_timer.dart';

class RiderOrdersScreen extends StatefulWidget {
  const RiderOrdersScreen({super.key});

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String? _realRiderId;
  bool _isLinkingProfile = true;
  String _debugMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    _linkProfileByEmail();
  }

  // --- 1. LINK RIDER PROFILE ---
  Future<void> _linkProfileByEmail() async {
    if (user?.email == null) {
      if (mounted) {
        setState(() {
          _isLinkingProfile = false;
          _debugMessage = "No email found for login.";
        });
      }
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
            _isLinkingProfile = false;
          });
        } else {
          setState(() {
            _isLinkingProfile = false;
            _debugMessage = "Vendor has not assigned you yet.";
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLinkingProfile = false);
    }
  }

  // --- 2. COMMISSION & STATUS UPDATE LOGIC (NO INDEX REQUIRED) ---
  Future<void> _updateStatus(DocumentSnapshot orderDoc, String newStatus,
      {String? cancelReason}) async {
    double commission = 0;
    Map<String, dynamic> dataToUpdate = {
      'status': newStatus,
      'last_updated': FieldValue.serverTimestamp(),
    };

    try {
      // IF STARTING TRIP -> LOG TIME
      if (newStatus == 'Out for Delivery') {
        dataToUpdate['out_for_delivery_at'] = FieldValue.serverTimestamp();
      }

      // IF DELIVERING OR ELIGIBLE CANCELLATION -> CALCULATE COMMISSION
      bool isEligibleCancellation = newStatus == 'Cancelled' && 
          (cancelReason == "Customer Unreachable" || 
           cancelReason == "Wrong Address" || 
           cancelReason == "Customer Refused Delivery");

      if (newStatus == 'Delivered' || isEligibleCancellation) {
        if (newStatus == 'Delivered') {
          dataToUpdate['delivered_at'] = FieldValue.serverTimestamp();
        }

        // Safe Data Extraction
        Map<String, dynamic>? orderData =
            orderDoc.data() as Map<String, dynamic>?;
        String? vendorId = orderData?['vendor_id'];

        if (vendorId != null && vendorId.isNotEmpty) {
          // A. Fetch Vendor Settings
          var settingsSnap = await FirebaseFirestore.instance
              .collection('vendor_settings')
              .doc(vendorId)
              .get();

          double baseX = 40;
          double extraY = 20;

          if (settingsSnap.exists) {
            var settings = settingsSnap.data();
            baseX = (settings?['commission_base_x'] ?? 40).toDouble();
            extraY = (settings?['commission_extra_y'] ?? 20).toDouble();
          }

          // B. SMART CHECK (Client-Side Logic to fix Index Error)
          // We fetch ALL delivered orders for this rider, then filter in code.
          var historySnap = await FirebaseFirestore.instance
              .collection('orders')
              .where('rider_id', isEqualTo: _realRiderId)
              .where('status', isEqualTo: 'Delivered')
              .get(); // Simple query: No complex filters here

          commission = baseX; // Default: Start of a new trip (X)

          DateTime sixtyMinsAgo =
              DateTime.now().subtract(const Duration(minutes: 60));

          // Loop through history manually
          for (var doc in historySnap.docs) {
            var pastOrder = doc.data();

            // Check 1: Same Vendor?
            if (pastOrder['vendor_id'] == vendorId) {
              // Check 2: Within last 60 mins?
              Timestamp? t = pastOrder['delivered_at'];
              if (t != null && t.toDate().isAfter(sixtyMinsAgo)) {
                commission = extraY; // Found recent order! Switch to Extra (Y)
                break; // Stop looking
              }
            }
          }

          dataToUpdate['rider_commission'] = commission;
        }
      }

      if (newStatus == 'Cancelled') {
        dataToUpdate['cancellation_reason'] = cancelReason;
        dataToUpdate['cancelled_at'] = FieldValue.serverTimestamp();
        dataToUpdate['cancelled_by'] = 'rider';
      }

      // EXECUTE UPDATE
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderDoc.id)
          .update(dataToUpdate);

      // --- SEND NOTIFICATION TO VENDOR ---
      Map<String, dynamic>? currentData = orderDoc.data() as Map<String, dynamic>?;
      String? vId = currentData?['vendor_id'];
      String? cId = currentData?['customer_id'];
      String? orderIdStr = currentData?['order_id'] ?? orderDoc.id;
      
      // Extract Image URL
      String? imgUrl;
      if (currentData != null && currentData['items'] is List && (currentData['items'] as List).isNotEmpty) {
         final firstItem = (currentData['items'] as List).first;
         imgUrl = firstItem['imageUrl'] ?? firstItem['image_url'];
      }

      // 1. Notify Vendor
      if (vId != null) {
        if (newStatus == 'Delivered') {
          await NotificationService.sendNotification(
            vendorId: vId,
            title: 'Order Delivered',
            message: 'Order #$orderIdStr has been delivered.',
            type: 'order_delivered',
            orderId: orderIdStr!,
          );
        } else if (newStatus == 'Cancelled') {
          await NotificationService.sendNotification(
            vendorId: vId,
            title: 'Order Cancelled by Rider',
            message: 'Order #$orderIdStr cancelled. Reason: $cancelReason',
            type: 'rider_cancelled',
            orderId: orderIdStr!,
          );
        }
      }

      // 2. Notify Customer
      if (cId != null) {
        String title = 'Order Update';
        String body = 'Your order status has been updated to $newStatus.';

        if (newStatus == 'Out for Delivery') {
          title = 'Out for Delivery 🛵';
          body = 'Your order is out for delivery! Get ready.';
        } else if (newStatus == 'Delivered') {
          title = 'Order Delivered! 🎉';
          body = 'Your order has been delivered using secure pin. Thank you!';
        } else if (newStatus == 'Cancelled') {
          title = 'Delivery Failed ❌';
          body = 'Delivery attempt failed. Reason: $cancelReason';
        }

        if (newStatus == 'Out for Delivery' || newStatus == 'Delivered' || newStatus == 'Cancelled') {
           await NotificationService.sendCustomerNotification(
             customerId: cId,
             title: title,
             body: body,
             type: 'order_status',
             orderId: orderDoc.id, // Use Doc ID for navigation matching
             imageUrl: imgUrl,
           );
        }
      }
      // -----------------------------------

      if (newStatus == 'Delivered' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Order Delivered! You earned ${CurrencyHelper.format(commission)}"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      debugPrint("Error in _updateStatus: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error updating: $e")));
      }
    }
  }

  // --- 3. DIALOGS ---

  // DELIVERY (PIN REQUIRED)
  void _showDeliveryDialog(DocumentSnapshot orderDoc) {
    final TextEditingController pinCtrl = TextEditingController();
    var data = orderDoc.data() as Map<String, dynamic>;
    String correctPin = data['delivery_pin']?.toString() ?? "1234";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Complete Delivery"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ask customer for the 4-digit PIN."),
            const SizedBox(height: 20),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: "0000",
                border: OutlineInputBorder(),
                counterText: "",
              ),
            ),
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
              if (pinCtrl.text == correctPin) {
                Navigator.pop(context);
                _updateStatus(orderDoc, "Delivered");
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Wrong PIN! Try again."),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text("VERIFY & FINISH"),
          ),
        ],
      ),
    );
  }

  // CANCEL (REASON REQUIRED)
  void _showCancelDialog(DocumentSnapshot orderDoc) {
    String? selectedReason;
    List<String> reasons = [
      "Customer Unreachable",
      "Customer Refused Delivery",
      "Wrong Address",
      "Damaged Item"
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text("Cancel Delivery"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select cancellation reason:",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              ...reasons.map((r) => RadioListTile(
                    title: Text(r),
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (v) => setState(() => selectedReason = v),
                  )),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Back")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                if (selectedReason != null) {
                  Navigator.pop(context);
                  _updateStatus(orderDoc, "Cancelled",
                      cancelReason: selectedReason);
                }
              },
              child: const Text("CONFIRM CANCEL"),
            ),
          ],
        );
      }),
    );
  }

  void _showGlobalScanner() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Order Label'),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: MobileScanner(
            onDetect: (capture) async {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  // Find order in current list
                  Navigator.pop(context); // Close scanner
                  _handleScannedOrder(code);
                  return;
                }
              }
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _handleScannedOrder(String scannedCode) async {
    try {
      // Find the order by its human-readable order_id field
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('order_id', isEqualTo: scannedCode.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();

        if (data['rider_id'] != _realRiderId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("This order is not assigned to you."), backgroundColor: Colors.orange),
          );
          return;
        }

        final status = data['status'];
        if (status == 'Shipped') {
          // AUTO START TRIP
          await _updateStatus(doc, "Out for Delivery");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Trip Started automatically!"), backgroundColor: Colors.blue),
          );
        } else if (status == 'Out for Delivery') {
          // AUTO OPEN PIN PANEL
          _showDeliveryDialog(doc);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Order status: $status")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order not found. Please scan a valid label."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- 4. UTILS ---
  void _callCustomer(String? phone) async {
    if (phone == null) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  String _maskPhone(String? phone) {
    if (phone == null || phone.length < 10) return "Hidden";
    return "${phone.substring(0, 2)}******${phone.substring(phone.length - 2)}";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLinkingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_realRiderId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error"), backgroundColor: Colors.red),
        body: Center(child: Text(_debugMessage)),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("My Deliveries"),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => _showGlobalScanner(),
              tooltip: "Scan to Delivery",
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "New Tasks"),
              Tab(text: "In Progress"),
              Tab(text: "History"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('rider_id', isEqualTo: _realRiderId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var docs = snapshot.data!.docs;

            docs.sort((a, b) {
              Timestamp t1 = (a.data() as Map)['created_at'] ?? Timestamp.now();
              Timestamp t2 = (b.data() as Map)['created_at'] ?? Timestamp.now();
              return t2.compareTo(t1);
            });

            var newTasks = docs.where((d) => d['status'] == 'Shipped').toList();
            var inProgress =
                docs.where((d) => d['status'] == 'Out for Delivery').toList();
            var history = docs.where((d) => 
                d['status'] == 'Delivered' || d['status'] == 'Cancelled').toList();

            return TabBarView(
              children: [
                _buildOrderList(newTasks, isNew: true),
                _buildOrderList(inProgress, isNew: false),
                _buildOrderList(history, isNew: false, isHistory: true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderList(List<QueryDocumentSnapshot> orders,
      {required bool isNew, bool isHistory = false}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isNew ? Icons.inbox : (isHistory ? Icons.history : Icons.local_shipping),
                size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(isNew ? "No new tasks." : (isHistory ? "No history." : "No active trips."),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        var doc = orders[index];
        var data = doc.data() as Map<String, dynamic>;
        var address = data['delivery_address'] ?? {};

        // EXTRACTION FOR TIMER
        String deliveryMode = data['delivery_mode'] ?? 'Standard';
        Timestamp createdAt = data['created_at'] ?? Timestamp.now();
        String status = data['status'] ?? 'Pending';

        String fullName = address['name'] ?? "Customer";
        String fullAddr =
            "${address['house_no'] ?? ''}, ${address['street'] ?? ''}, ${address['city'] ?? ''}";
        String phone = address['phone'] ?? "";
        String orderId = data['order_id'] ?? doc.id;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER with TIMER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Order #$orderId",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(deliveryMode.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),

                    // --- TIMER ---
                    OrderTimer(
                      createdAt: createdAt,
                      deliveryMode: deliveryMode,
                      status: status,
                    ),

                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4)),
                      child: Text("COD: ${CurrencyHelper.format(data['total_amount'])}",
                          style: const TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                // -------------------------

                const Divider(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_pin_circle,
                        color: Colors.red, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(fullAddr,
                              style: const TextStyle(
                                  color: Colors.black87, height: 1.3)),
                          const SizedBox(height: 6),
                          SelectableText(
                              "Mobile: ${isNew ? _maskPhone(phone) : phone}",
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                if (status == 'Cancelled') ...[
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(5)),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text("CANCELLED BY ${(data['cancelled_by'] ?? 'UNKNOWN').toString().toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                         Text("Reason: ${data['cancellation_reason'] ?? 'N/A'}", style: TextStyle(color: Colors.red.shade800)),
                         if (data['rider_commission'] != null && data['rider_commission'] > 0)
                            Text("Compensation: ${CurrencyHelper.format(data['rider_commission'])}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                       ],
                     ),
                   )
                ] else if (status == 'Delivered') ...[
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(5)),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text("DELIVERED", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                         if (data['rider_commission'] != null)
                           Text("Earned: ${CurrencyHelper.format(data['rider_commission'])}", style: TextStyle(color: Colors.green.shade800)),
                       ],
                     ),
                   )
                ] else if (isNew)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () => _updateStatus(doc, "Out for Delivery"),
                      child: const Text("START TRIP",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callCustomer(phone),
                          icon: const Icon(Icons.call, color: Colors.blue),
                          label: const Text("Call"),
                          style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4)),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _showCancelDialog(doc),
                          tooltip: "Cancel Delivery",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () => _showDeliveryDialog(doc),
                          icon: const Icon(Icons.check_circle,
                              color: Colors.white),
                          label: const Text("COMPLETE",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
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
