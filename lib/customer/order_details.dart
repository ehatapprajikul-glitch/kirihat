import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'product/enhanced_product_detail.dart';
import 'address_screen.dart';
import '../widgets/order_timer.dart'; // Import Timer Widget
import '../services/notification_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final DocumentSnapshot orderDoc;

  const OrderDetailsScreen({super.key, required this.orderDoc});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isLoading = false;
  final User? user = FirebaseAuth.instance.currentUser;

  // --- 1. CANCEL ORDER LOGIC ---
  void _showCancelDialog() {
    String selectedReason = "";
    final customReasonController = TextEditingController();
    final List<String> reasons = [
      "Ordered by mistake",
      "Found a better price",
      "Delivery time is too long",
      "Need to change payment method",
      "Other"
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Order"),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Please select a reason for cancellation:"),
                  ...reasons.map((r) => RadioListTile<String>(
                        title: Text(r),
                        value: r,
                        groupValue: selectedReason,
                        onChanged: (val) {
                          setDialogState(() => selectedReason = val!);
                        },
                      )),
                  if (selectedReason == "Other")
                    TextField(
                      controller: customReasonController,
                      decoration: const InputDecoration(
                        labelText: "Write a reason (min 5 words)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Keep Order")),
          ElevatedButton(
            onPressed: () async {
              if (selectedReason.isEmpty) {
                return;
              }
              if (selectedReason == "Other" &&
                  customReasonController.text.split(' ').length < 5) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Please write at least 5 words.")));
                }
                return;
              }

              Navigator.pop(context);
              setState(() => _isLoading = true);

              await widget.orderDoc.reference.update({
                'status': 'Cancelled',
                'cancellation_reason': selectedReason == "Other"
                    ? customReasonController.text
                    : selectedReason,
                'cancelled_at': FieldValue.serverTimestamp(),
              });

              // --- NOTIFY VENDOR ---
              Map<String, dynamic>? data = widget.orderDoc.data() as Map<String, dynamic>?;
              String? vId = data?['vendor_id'];
              if (vId != null) {
                await NotificationService.sendNotification(
                  vendorId: vId,
                  title: 'Order Cancelled by Customer',
                  message: 'Order #${data?['order_id'] ?? widget.orderDoc.id} was cancelled. Reason: $selectedReason',
                  type: 'order_cancelled',
                  orderId: data?['order_id'] ?? widget.orderDoc.id,
                );
              }
              // ---------------------

              if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Order Cancelled Successfully")));
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Confirm Cancel"),
          )
        ],
      ),
    );
  }

  // --- 2. CHANGE ADDRESS ---
  void _changeAddress(Map<String, dynamic> currentAddress) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressScreen(
          initialData: currentAddress,
        ),
      ),
    ).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Address updated in your profile. Please contact support to update it for this shipped order if needed.")));
      }
    });
  }

  // --- 3. REQUEST CALLBACK ---
  Future<void> _requestCallback() async {
    setState(() => _isLoading = true);

    try {
      var existingDocs = await FirebaseFirestore.instance
          .collection('support_requests')
          .where('user_id', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'Pending')
          .get();

      if (existingDocs.docs.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 50),
              content: const Text(
                  "You already have an open callback request.\n\nPlease wait for our team to resolve it before raising another."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c), child: const Text("OK"))
              ],
            ),
          );
        }
      } else {
        await FirebaseFirestore.instance.collection('support_requests').add({
          'user_id': user!.uid,
          'user_email': user!.email,
          'order_id': widget.orderDoc.id,
          'type': 'Callback Request',
          'status': 'Pending',
          'created_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Callback requested! Check 'Me' tab for status."),
              backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- 4. RETURN LOGIC ---
  void _showReturnDialog() {
    Timestamp? deliveredAt =
        (widget.orderDoc.data() as Map<String, dynamic>)['delivered_at'];
    if (deliveredAt != null) {
      final diff = DateTime.now().difference(deliveredAt.toDate()).inDays;
      if (diff > 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Return period (2 days) has expired.")));
        }
        return;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Return Product"),
        content: const Text("Do you want to return this product?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("No")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.orderDoc.reference
                  .update({'status': 'Return Requested'});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Return Request Raised!")));
              }
            },
            child: const Text("Yes, Return"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.orderDoc.data() as Map<String, dynamic>;
    var items = data['items'] as List<dynamic>? ?? [];
    String status = data['status'] ?? 'Pending';
    double total = (data['total_amount'] ?? 0).toDouble();
    Timestamp? ts = data['created_at'];
    String dateStr = ts != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate())
        : "Unknown";

    // --- FIX: DISPLAY ID LOGIC ---
    // If 'order_id' exists in DB, use it.
    // If not, generate a KIRI- ID from the document ID.
    String displayOrderId;
    if (data['order_id'] != null && data['order_id'].toString().isNotEmpty) {
      displayOrderId = data['order_id'].toString();
    } else {
      // Fallback: Create "KIRI-ABC123" using the first 6 chars of Doc ID
      displayOrderId =
          "KIRI-${widget.orderDoc.id.substring(0, 6).toUpperCase()}";
    }
    // -----------------------------

    // --- SAFE ADDRESS EXTRACTION ---
    Map<String, dynamic> address = data['delivery_address'] ?? {};
    String shippingName =
        address['name'] ?? address['guardian_name'] ?? "Customer";

    // Filter null/empty/"null"
    List<String> validParts = [
      address['house_no']?.toString(),
      address['street']?.toString(),
      address['landmark']?.toString(),
      address['city']?.toString(),
      address['state']?.toString()
    ]
        .where((s) => s != null && s.trim().isNotEmpty && s != "null")
        .map((s) => s!)
        .toList();

    String shippingFull = validParts.join(", ");

    if (address['pincode'] != null &&
        address['pincode'].toString().isNotEmpty &&
        address['pincode'] != "null") {
      if (shippingFull.isNotEmpty) {
        shippingFull += " - ${address['pincode']}";
      } else {
        shippingFull = address['pincode'].toString();
      }
    }

    if (shippingFull.isEmpty) {
      shippingFull = "Address details unavailable";
    }
    // ------------------------------------------

    // Delivery PIN & Mode
    String deliveryPin = data['delivery_pin']?.toString() ?? "1234";
    String deliveryMode = data['delivery_mode'] ?? 'Standard';

    // Colors
    Color statusColor = Colors.orange;
    if (status == 'Delivered') {
      statusColor = Colors.green;
    }
    if (status == 'Cancelled') {
      statusColor = Colors.red;
    }
    if (status == 'Shipped' || status == 'Out for Delivery') {
      statusColor = Colors.blue;
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Order Details"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- DELIVERY CODE DISPLAY ---
                  if (status == 'Shipped' || status == 'Out for Delivery')
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.blue.shade800,
                          Colors.blue.shade500
                        ]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.blue.withAlpha(77),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text("SHARE WITH RIDER",
                              style: TextStyle(
                                  color: Colors.white70,
                                  letterSpacing: 1.5,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              deliveryPin,
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 5,
                                  color: Colors.blue.shade900),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                              "Provide this code to receive your package",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),

                  // --- 1. SHIPPING ADDRESS HEADER ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.local_shipping,
                            color: Colors.green, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Shipping to $shippingName",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(shippingFull,
                                  style: const TextStyle(
                                      color: Colors.grey, height: 1.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ORDER STATUS CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Order #$displayOrderId", // UPDATED HERE
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: OrderTimer(
                                    createdAt: ts ?? Timestamp.now(),
                                    deliveryMode: deliveryMode,
                                    status: status,
                                  ),
                                ),
                              ],
                            ),
                            Chip(
                              label: Text(status,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              backgroundColor: statusColor,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text("Placed on: $dateStr",
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ITEMS LIST
                  const Text("Items",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      var item = items[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => EnhancedProductDetailScreen(
                                      productData: item,
                                      productId: "unknown")));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                  image: (item['imageUrl'] != null)
                                      ? DecorationImage(
                                          image: NetworkImage(item['imageUrl']),
                                          fit: BoxFit.cover)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] ?? "Product",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text("x${item['quantity']}",
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Text("₹${item['price'] * item['quantity']}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 12, color: Colors.grey)
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ACTION BUTTONS
                  if (status != 'Cancelled') ...[
                    const Text("Order Actions",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    // PENDING ACTIONS
                    if (status == 'Pending') ...[
                      _buildActionButton(Icons.cancel, "Cancel Order",
                          Colors.red, _showCancelDialog),
                      const SizedBox(height: 10),
                      _buildActionButton(
                          Icons.edit_location_alt,
                          "Change Address",
                          Colors.blue,
                          () => _changeAddress(address)),
                      const SizedBox(height: 10),
                      _buildActionButton(Icons.headset_mic, "Request Callback",
                          Colors.orange, _requestCallback),
                    ],

                    // SHIPPED ACTIONS
                    if (status == 'Shipped' ||
                        status == 'Out for Delivery') ...[
                      _buildActionButton(Icons.cancel, "Cancel Order",
                          Colors.red, _showCancelDialog),
                      const SizedBox(height: 10),
                      _buildActionButton(Icons.location_off,
                          "Change Address (Locked)", Colors.grey, () {},
                          isDisabled: true),
                    ],

                    // DELIVERED ACTIONS
                    if (status == 'Delivered') ...[
                      _buildActionButton(Icons.undo, "Return Product",
                          Colors.orange, _showReturnDialog),
                      const SizedBox(height: 10),
                      _buildActionButton(
                          Icons.download, "Download Invoice", Colors.black, () {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Invoice download started...")));
                        }
                      }),
                    ],
                  ],

                  const SizedBox(height: 20),

                  // PAYMENT SUMMARY
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Payment Details",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Subtotal"),
                              Text("₹${data['product_total'] ?? total}")
                            ]),
                        const SizedBox(height: 5),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Delivery Fee"),
                              Text("₹${data['delivery_fee'] ?? 0}")
                            ]),
                        if ((data['tax_amount'] ?? 0) > 0)
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Tax (GST)"),
                                Text(
                                    "₹${(data['tax_amount'] ?? 0).toStringAsFixed(2)}")
                              ]),
                        const Divider(),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Total Amount",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text("₹$total",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green)),
                            ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onTap,
      {bool isDisabled = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : onTap,
        icon: Icon(icon,
            color: isDisabled ? Colors.grey : Colors.white, size: 18),
        label: Text(label,
            style: TextStyle(color: isDisabled ? Colors.grey : Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey[200] : color,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }
}
