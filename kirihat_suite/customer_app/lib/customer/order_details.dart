import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'product/enhanced_product_detail.dart';
import 'address_screen.dart';
import '../widgets/order_timer.dart';
import 'package:kirihat_core/services/notification_service.dart';
import '../services/invoice_service.dart';
import 'widgets/unique_order_status_tracker.dart';

class OrderDetailsScreen extends StatefulWidget {
  final DocumentSnapshot? orderDoc;
  final String? orderId;

  const OrderDetailsScreen({
    super.key, 
    this.orderDoc,
    this.orderId,
  }) : assert(orderDoc != null || orderId != null, 
             'Either orderDoc or orderId must be provided');

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isLoading = false;
  final User? user = FirebaseAuth.instance.currentUser;
  
  DocumentSnapshot? _fetchedDoc;

  @override
  void initState() {
    super.initState();
    if (widget.orderDoc == null && widget.orderId != null) {
      _fetchOrder();
    }
  }

  Future<void> _fetchOrder() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      if (mounted) {
        setState(() {
          _fetchedDoc = doc;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching order: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  DocumentSnapshot get _activeDoc => widget.orderDoc ?? _fetchedDoc!;

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

              await _activeDoc.reference.update({
                'status': 'Cancelled',
                'cancellation_reason': selectedReason == "Other"
                    ? customReasonController.text
                    : selectedReason,
                'cancelled_at': FieldValue.serverTimestamp(),
                'cancelled_by': 'Customer',
              });

              // --- RESTORE STOCK FOR BOTH VENDOR AND SELLER ---
              Map<String, dynamic>? data = _activeDoc.data() as Map<String, dynamic>?;
              var items = data?['items'] as List<dynamic>? ?? [];
              String? vendorId = data?['vendor_id'];
              
              final batch = FirebaseFirestore.instance.batch();
              bool stockRestoreNeeded = false;

              for (var item in items) {
                String? productId = item['product_id'] ?? item['id'];
                int quantity = item['quantity'] ?? 0;
                
                if (productId != null && quantity > 0) {
                  // 1. Restore seller's master_products stock
                  var productRef = FirebaseFirestore.instance.collection('master_products').doc(productId);
                  batch.update(productRef, {
                    'stock_quantity': FieldValue.increment(quantity)
                  });
                  
                  // 2. Restore vendor's inventory stock
                  if (vendorId != null) {
                    try {
                      var vendorInventoryQuery = await FirebaseFirestore.instance
                          .collection('vendor_inventory')
                          .where('vendor_id', isEqualTo: vendorId)
                          .where('product_id', isEqualTo: productId)
                          .limit(1)
                          .get();
                      
                      if (vendorInventoryQuery.docs.isNotEmpty) {
                        var vendorInvRef = vendorInventoryQuery.docs.first.reference;
                        batch.update(vendorInvRef, {
                          'stock_quantity': FieldValue.increment(quantity)
                        });
                      }
                    } catch (e) {
                      debugPrint("Error restoring vendor stock for $productId: $e");
                    }
                  }
                  
                  stockRestoreNeeded = true;
                }
              }

              if (stockRestoreNeeded) {
                try {
                  await batch.commit();
                  debugPrint("✅ Stocks restored successfully");
                } catch (e) {
                  debugPrint("❌ Stock restoration failed: $e");
                }
              }
              // --------------------------------------------------

              // --- NOTIFY VENDOR ---
              String? vId = data?['vendor_id'];
              if (vId != null) {
                await NotificationService.sendNotification(
                  vendorId: vId,
                  title: 'Order Cancelled by Customer',
                  message: 'Order #${data?['order_id'] ?? _activeDoc.id} was cancelled. Reason: $selectedReason',
                  type: 'order_cancelled',
                  orderId: data?['order_id'] ?? _activeDoc.id,
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
          'order_id': _activeDoc.id,
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

  Future<Map<String, dynamic>> _fetchItemPolicy(Map<String, dynamic> item, String? globalVendorId) async {
    debugPrint('🔍 === FETCHING ITEM POLICY ===');
    debugPrint('🔍 Item data: $item');
    
    // 1. Check snapshot (Order Item has data)
    if (item.containsKey('return_policy_type') && item['return_policy_type'] != null) {
      debugPrint('✅ Found policy in order snapshot');
      return {
        'return_policy_type': item['return_policy_type'],
        'return_window_days': item['return_window_days'] ?? 0
      };
    }

    // 2. Fallback: Fetch from Vendor Inventory
    String? vendorId = item['seller_id'] ?? globalVendorId;
    String? productId = item['product_id'] ?? item['id'];

    debugPrint('🔍 Vendor ID: $vendorId');
    debugPrint('🔍 Product ID: $productId');

    if (vendorId == null || productId == null) {
      debugPrint('⚠️ Missing vendor or product ID');
      return {'return_policy_type': 'No Return', 'return_window_days': 0};
    }

    try {
      debugPrint('🔍 Querying vendor_inventory...');
      final query = await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .where('product_id', isEqualTo: productId)
          .limit(1)
          .get();

      debugPrint('🔍 Query results: ${query.docs.length} documents');

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        debugPrint('✅ Found policy in vendor_inventory: $data');
        return {
          'return_policy_type': data['return_policy_type'] ?? 'No Return',
          'return_window_days': data['return_window_days'] ?? 0
        };
      } else {
        debugPrint('⚠️ No matching document found in vendor_inventory');
      }
    } catch (e) {
      debugPrint("❌ Error fetching policy fallback: $e");
    }

    return {'return_policy_type': 'No Return', 'return_window_days': 0};
  }

  // Helper method to check if product ID is valid
  bool _isValidProductId(dynamic productId) {
    if (productId == null) return false;
    final idString = productId.toString().trim();
    return idString.isNotEmpty && idString.toLowerCase() != 'null';
  }

  // Helper to navigate to product details with proper validation
  void _navigateToProduct(Map<String, dynamic> item) {
    // Try multiple possible ID fields
    final productId = item['product_id'] ?? item['id'];
    
    if (!_isValidProductId(productId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Product details are not available for this item"),
          duration: Duration(seconds: 2),
        )
      );
      return;
    }

    // Ensure we have the minimum required data
    final productData = Map<String, dynamic>.from(item);
    
    // Navigate to product details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedProductDetailScreen(
          productId: productId.toString(),
          productData: productData,
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _fetchedDoc == null && widget.orderDoc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_fetchedDoc == null && widget.orderDoc == null) {
         return const Scaffold(body: Center(child: Text("Order not found")));
    }

    var data = _activeDoc.data() as Map<String, dynamic>;
    var items = data['items'] as List<dynamic>? ?? [];
    String status = data['status'] ?? 'Pending';
    double total = (data['total_amount'] ?? 0).toDouble();
    Timestamp? ts = data['created_at'];
    String dateStr = ts != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate())
        : "Unknown";

    // --- DISPLAY ID LOGIC ---
    String displayOrderId;
    if (data['order_id'] != null && data['order_id'].toString().isNotEmpty) {
      displayOrderId = data['order_id'].toString();
    } else {
      displayOrderId =
          "KIRI-${_activeDoc.id.substring(0, 6).toUpperCase()}";
    }

    // --- SAFE ADDRESS EXTRACTION ---
    Map<String, dynamic> address = data['delivery_address'] ?? {};
    String shippingName =
        address['name'] ?? address['guardian_name'] ?? "Customer";

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

                  // ORDER STATUS CARD - Removed, replaced with tracker below

                  // UNIQUE ORDER STATUS TRACKER
                  UniqueOrderStatusTracker(orderData: data),
                  
                  const SizedBox(height: 16),

                  // ORDER INFO CARD WITH TIMER
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
                                Text("Order #$displayOrderId",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text("Placed: $dateStr",
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                  ],
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
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        
                        // DELIVERY COUNTDOWN TIMER
                        if (status != 'Delivered' && status != 'Cancelled')
                          OrderTimer(
                            createdAt: ts ?? Timestamp.now(),
                            deliveryMode: deliveryMode,
                            status: status,
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
                      final productId = item['product_id'] ?? item['id'];
                      final hasValidProductId = _isValidProductId(productId);
                      
                      return GestureDetector(
                        onTap: null, // Disabled as per request
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4),
                                      image: (item['imageUrl'] != null)
                                          ? DecorationImage(
                                              image: CachedNetworkImageProvider(item['imageUrl']),
                                              fit: BoxFit.cover)
                                          : null,
                                    ),
                                    child: (item['imageUrl'] == null)
                                        ? const Icon(Icons.image, color: Colors.grey)
                                        : null,
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
                                ],
                              ),
                              // Return/Replace Action Button
                              if (status == 'Delivered') 
                                FutureBuilder<Map<String, dynamic>>(
                                  future: _fetchItemPolicy(item, data['vendor_id']),
                                  builder: (context, policySnapshot) {
                                    if (!policySnapshot.hasData) {
                                      debugPrint('⏳ Waiting for policy data...');
                                      return const Padding(
                                        padding: EdgeInsets.only(top: 12),
                                        child: Center(
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      );
                                    }
                                    
                                    final policy = policySnapshot.data!;
                                    String policyType = policy['return_policy_type'] ?? 'No Return';
                                    int windowDays = policy['return_window_days'] ?? 0;
                                    
                                    debugPrint('🔍 Policy Type: $policyType');
                                    debugPrint('🔍 Window Days: $windowDays');
                                    
                                    if (policyType == 'No Return') {
                                      debugPrint('⚠️ No return policy - hiding button');
                                      return const SizedBox.shrink();
                                    }

                                    // Calculate Expiry - Use delivered_at as primary
                                    DateTime? deliveredAt;
                                    
                                    // Use delivered_at as the primary field
                                    if (data['delivered_at'] != null) {
                                      deliveredAt = (data['delivered_at'] as Timestamp).toDate();
                                      debugPrint('✅ Using delivered_at: $deliveredAt');
                                    } else if (data['delivery_time'] != null) {
                                      deliveredAt = (data['delivery_time'] as Timestamp).toDate();
                                      debugPrint('⚠️ Fallback to delivery_time: $deliveredAt');
                                    } else if (data['updated_at'] != null && status == 'Delivered') {
                                      // Last fallback to updated_at if status is Delivered
                                      deliveredAt = (data['updated_at'] as Timestamp).toDate();
                                      debugPrint('⚠️ Using updated_at as fallback: $deliveredAt');
                                    }
                                    
                                    if (deliveredAt == null) {
                                      debugPrint('⚠️ No delivery timestamp found - showing button anyway');
                                      // Show button anyway if no timestamp (shouldn't block returns)
                                      String btnLabel = policyType == 'Replace Only' ? 'Replace' : 'Return / Replace';
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.assignment_return, size: 16),
                                            label: Text(btnLabel),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF0D9759),
                                              side: const BorderSide(color: Color(0xFF0D9759)),
                                            ),
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Return/Replace Request Initiated"))
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    }

                                    final expiryDate = deliveredAt.add(Duration(days: windowDays));
                                    final now = DateTime.now();
                                    final daysLeft = expiryDate.difference(now).inDays;
                                    
                                    debugPrint('🔍 Delivered at: $deliveredAt');
                                    debugPrint('🔍 Expiry date: $expiryDate');
                                    debugPrint('🔍 Days left: $daysLeft');
                                    
                                    if (now.isAfter(expiryDate)) {
                                      debugPrint('⚠️ Return window expired');
                                      return const Padding(
                                        padding: EdgeInsets.only(top: 12),
                                        child: Text(
                                          'Return/Replace window expired',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    }

                                    String btnLabel = policyType == 'Replace Only' ? 'Replace' : 'Return / Replace';
                                    
                                    debugPrint('✅ Showing return button: $btnLabel');
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.assignment_return, size: 16),
                                              label: Text(btnLabel),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF0D9759),
                                                side: const BorderSide(color: Color(0xFF0D9759)),
                                              ),
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Return/Replace Request Initiated"))
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$daysLeft day${daysLeft != 1 ? 's' : ''} left to return/replace',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                ),
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
                      _buildActionButton(
                          Icons.download, "Download Invoice", Colors.black, () {
                        final invoiceData = Map<String, dynamic>.from(data);
                        // Prioritize the display order ID, fallback to document ID
                        invoiceData['order_id'] = data['order_id'] ?? _activeDoc.id;
                        InvoiceService.generateInvoice(invoiceData);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Opening Invoice...")));
                        }
                      }),
                    ],
                  ],

                  // PERMANENT ACTIONS (For all statuses including Cancelled)
                  const SizedBox(height: 10),
                  _buildActionButton(Icons.headset_mic, "Request Callback",
                      Colors.orange, _requestCallback),

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
                        if ((data['low_cart_fee'] ?? 0) > 0)
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Small Order Fee"),
                                Text("₹${data['low_cart_fee']}")
                              ]),
                        if ((data['platform_fee'] ?? 0) > 0)
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Platform Fee"),
                                Text("₹${data['platform_fee']}")
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