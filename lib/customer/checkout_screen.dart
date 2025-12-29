import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'customer_home.dart';
import 'address_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final String vendorId; // CRITICAL: Identify which shop gets the order

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.vendorId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  // Address Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  // Delivery & Payment State
  String _deliveryMode = 'Standard';
  String _paymentMethod = 'COD';
  double _deliveryFee = 0;
  double _standardFee = 0;
  double _instantFee = 0;
  double _minFreeDelivery = 0;
  bool _isZoneFound = false;
  String _zoneName = "Checking...";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchVendorSettings(); // Fetch fees for THIS vendor
    _loadDefaultAddress();
  }

  // --- 1. LOAD DEFAULT ADDRESS ---
  Future<void> _loadDefaultAddress() async {
    if (user == null) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('current_address')) {
          _fillAddressForm(data['current_address']);
        } else {
          _nameCtrl.text = user!.displayName ?? "";
        }
      }
    } catch (e) {
      debugPrint("Error loading default address: $e");
    }
  }

  // --- 2. FILL FORM & CHECK ZONE ---
  void _fillAddressForm(Map<String, dynamic> address) {
    setState(() {
      _nameCtrl.text = address['name'] ?? "";
      _phoneCtrl.text = address['phone'] ?? "";
      _houseCtrl.text = address['house_no'] ?? "";
      _streetCtrl.text = address['street'] ?? "";
      _cityCtrl.text = address['city'] ?? "";
      _pinCtrl.text = address['pincode'] ?? "";
    });
    if (_pinCtrl.text.isNotEmpty) {
      _checkZoneAndFees(_pinCtrl.text);
    }
  }

  // --- 3. SHOW SAVED ADDRESS SHEET ---
  void _showAddressSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Select Address",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddressScreen()));
                    },
                    icon: const Icon(Icons.add, color: Colors.green),
                    label: const Text("Add New",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('addresses')
                      .orderBy('created_at', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return const Center(
                          child: Text("No addresses saved. Add one!"));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(Icons.location_city,
                                color: Colors.grey),
                            title: Text(data['landmark'] ?? "Address",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                "${data['house_no']}, ${data['city']}, ${data['pincode']}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.pop(context); // Close sheet first
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => AddressScreen(
                                              addressId: docs[index].id,
                                              initialData: data,
                                            )));
                              },
                            ),
                            onTap: () {
                              _fillAddressForm(data);
                              Navigator.pop(context);
                            },
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

  // --- 4. FETCH SETTINGS & ZONE LOGIC ---
  Future<void> _fetchVendorSettings() async {
    try {
      // Fetch settings for the Specific Vendor (Passed from Cart)
      var doc = await FirebaseFirestore.instance
          .collection('vendor_settings')
          .doc(widget.vendorId)
          .get();
      if (doc.exists) {
        setState(() {
          _minFreeDelivery =
              (doc.data()?['min_order_value_free_delivery'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      debugPrint("Error fetching settings: $e");
    }
  }

  Future<void> _checkZoneAndFees(String pincode) async {
    if (pincode.length < 6) return;

    try {
      // Check Zones for Specific Vendor
      var snapshot = await FirebaseFirestore.instance
          .collection('vendor_zones')
          .where('vendor_id', isEqualTo: widget.vendorId)
          .where('pincodes', arrayContains: pincode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        double std = (data['standard_fee'] ?? 0).toDouble();
        double inst = (data['instant_fee'] ?? 0).toDouble();

        if (widget.subtotal >= _minFreeDelivery && _minFreeDelivery > 0) {
          std = 0;
        }

        setState(() {
          _isZoneFound = true;
          _zoneName = data['zone_name'];
          _standardFee = std;
          _instantFee = inst;
          _updateTotalFee();
        });
      } else {
        setState(() {
          _isZoneFound = false;
          _zoneName = "Not Deliverable";
          _standardFee = 0;
          _instantFee = 0;
          _deliveryFee = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text("Sorry, this shop does not deliver to this area.")));
        }
      }
    } catch (e) {
      debugPrint("Error checking zone: $e");
    }
  }

  void _updateTotalFee() {
    setState(() {
      _deliveryFee = (_deliveryMode == 'Standard') ? _standardFee : _instantFee;
    });
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isZoneFound) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter a valid deliverable pincode")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Fetch Commission Settings for this Vendor
      double commissionRate = 0;
      double deliveryFeeShare = 0;

      try {
        var commDoc = await FirebaseFirestore.instance
            .collection('vendor_commission_settings')
            .doc(widget.vendorId)
            .get();
        if (commDoc.exists) {
          // You can fetch 'base_commission' etc here if you want to store it in order
          // But usually, calculation happens dynamically or by the rider.
          // For now, we rely on the Rider App to calculate "X+Y" based on settings.
        }
      } catch (e) {
        debugPrint("Comm fetch error: $e");
      }

      String deliveryPin = (1000 + Random().nextInt(9000)).toString();

      Map<String, dynamic> orderData = {
        'order_id':
            "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        'customer_id': user?.uid,
        'customer_phone': _phoneCtrl.text.trim(),
        'vendor_id': widget.vendorId, // CRITICAL: This routes the order
        'items': widget.cartItems,
        'product_total': widget.subtotal,
        'delivery_fee': _deliveryFee,
        'total_amount': widget.subtotal + _deliveryFee,
        'payment_method': _paymentMethod,
        'payment_status': _paymentMethod == 'UPI' ? 'Paid' : 'Pending',
        'delivery_mode': _deliveryMode,
        'delivery_pin': deliveryPin,
        'status': 'Pending',
        'delivery_address': {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'house_no': _houseCtrl.text.trim(),
          'street': _streetCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'pincode': _pinCtrl.text.trim(),
        },
        'created_at': FieldValue.serverTimestamp(),
        // Initialize fields for Rider Logic
        'rider_commission': 0, // Will be calculated when Rider Accepts
        'is_settled': false,
      };

      await FirebaseFirestore.instance.collection('orders').add(orderData);

      // Clear Cart
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .get()
          .then((snap) {
        for (DocumentSnapshot ds in snap.docs) {
          ds.reference.delete();
        }
      });

      // Save Address
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'current_address': orderData['delivery_address'],
      }, SetOptions(merge: true));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title:
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
            content: Text(
                "Order Placed via $_paymentMethod!\n\nCheck 'My Orders' for status.",
                textAlign: TextAlign.center),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CustomerHomeScreen()));
                  },
                  child: const Text("OK"))
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Checkout"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1),
      backgroundColor: Colors.grey[50],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)]),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total to Pay",
                      style: TextStyle(color: Colors.grey)),
                  Text("₹${widget.subtotal + _deliveryFee}",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12)),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white))
                    : const Text("PLACE ORDER",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. DELIVERY ADDRESS HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Delivery Address",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _showAddressSelector,
                    icon: const Icon(Icons.bookmark_border, size: 18),
                    label: const Text("Saved Addresses"),
                  )
                ],
              ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    _buildTextField(_nameCtrl, "Full Name"),
                    const SizedBox(height: 10),
                    _buildTextField(_phoneCtrl, "Phone Number", isNumber: true),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _buildTextField(_houseCtrl, "House No/Flat")),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildTextField(_pinCtrl, "Pincode",
                              isNumber: true, onChanged: (val) {
                        if (val.length == 6) _checkZoneAndFees(val);
                      })),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _buildTextField(_streetCtrl, "Street/Area")),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_cityCtrl, "City")),
                    ]),
                    if (_isZoneFound)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(children: [
                          const Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 5),
                          Text("Delivering to $_zoneName",
                              style: const TextStyle(
                                  color: Colors.green, fontSize: 12))
                        ]),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. DELIVERY OPTIONS
              const Text("Delivery Speed",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    RadioListTile(
                      title: const Row(children: [
                        Icon(Icons.access_time, size: 18),
                        SizedBox(width: 8),
                        Text("Standard Delivery (2 Hours)")
                      ]),
                      subtitle: Text(
                          _standardFee == 0 ? "FREE" : "₹$_standardFee",
                          style: TextStyle(
                              color: _standardFee == 0
                                  ? Colors.green
                                  : Colors.black,
                              fontWeight: FontWeight.bold)),
                      value: 'Standard',
                      groupValue: _deliveryMode,
                      activeColor: Colors.green,
                      onChanged: (val) => setState(() {
                        _deliveryMode = val.toString();
                        _updateTotalFee();
                      }),
                    ),
                    const Divider(height: 1),
                    RadioListTile(
                      title: const Row(children: [
                        Icon(Icons.bolt, size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Instant Delivery (20 Mins)")
                      ]),
                      subtitle: Text("₹$_instantFee",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      value: 'Instant',
                      groupValue: _deliveryMode,
                      activeColor: Colors.orange,
                      onChanged: (val) => setState(() {
                        _deliveryMode = val.toString();
                        _updateTotalFee();
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. PAYMENT OPTIONS
              const Text("Payment Method",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    RadioListTile(
                      title: const Row(children: [
                        Icon(Icons.money, size: 18, color: Colors.green),
                        SizedBox(width: 8),
                        Text("Cash on Delivery (COD)")
                      ]),
                      value: 'COD',
                      groupValue: _paymentMethod,
                      activeColor: Colors.green,
                      onChanged: (val) =>
                          setState(() => _paymentMethod = val.toString()),
                    ),
                    const Divider(height: 1),
                    RadioListTile(
                      title: const Row(children: [
                        Icon(Icons.qr_code, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text("UPI (GPay / PhonePe)")
                      ]),
                      subtitle: const Text("Pay securely online",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      value: 'UPI',
                      groupValue: _paymentMethod,
                      activeColor: Colors.blue,
                      onChanged: (val) =>
                          setState(() => _paymentMethod = val.toString()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. PRICE BREAKDOWN
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    _buildSummaryRow("Item Total", "₹${widget.subtotal}"),
                    _buildSummaryRow("Delivery Fee", "₹$_deliveryFee",
                        isGreen: _deliveryFee == 0),
                    const Divider(),
                    _buildSummaryRow(
                        "Grand Total", "₹${widget.subtotal + _deliveryFee}",
                        isBold: true),
                  ],
                ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint,
      {bool isNumber = false, Function(String)? onChanged}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
      ),
      validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: isGreen ? Colors.green : Colors.black)),
        ],
      ),
    );
  }
}
