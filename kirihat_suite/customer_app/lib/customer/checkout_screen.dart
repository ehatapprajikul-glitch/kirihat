import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'customer_dashboard.dart';
import 'address_screen.dart';
import 'package:kirihat_core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _altPhoneCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _marketCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  // Delivery & Payment State
  String _deliveryMode = 'Standard';
  String _paymentMethod = 'COD';
  double _deliveryFee = 0;
  double _standardFee = 0;
  double _instantFee = 0;
  // _minFreeDelivery moved to Free Delivery Settings

  // Fee Configuration (Standard)
  double _minFreeDelivery = 0;
  bool _freeDeliveryEnabled = false;
  double _fallbackStandardFee = 25; // Default fallback

  // Fee Configuration (Instant)
  double _minFreeInstantDelivery = 0;
  bool _freeInstantDeliveryEnabled = false;
  double _fallbackInstantFee = 50; // Default fallback

  // Low Cart Fee Configuration
  bool _lowCartEnabled = false;
  double _lowCartThreshold = 0;
  double _lowCartFee = 0;
  bool _isLoading = false;
  bool _isAddressExpanded = true; // Address section starts expanded

  @override
  void initState() {
    super.initState();
    _fetchVendorSettings(); // Fetch fees for THIS vendor
    _loadUserProfile(); // Load name and phone from profile
    _loadSessionAddress(); // Auto-fill from session
    _loadDefaultAddress();
  }

  // --- Load user profile data (name and phone) ---
  Future<void> _loadUserProfile() async {
    if (user == null) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            // Auto-fill name from profile if available
            if (_nameCtrl.text.isEmpty) {
              _nameCtrl.text = data['name'] ?? user!.displayName ?? "";
            }
            // Auto-fill phone from profile if available
            if (_phoneCtrl.text.isEmpty) {
              _phoneCtrl.text = data['phone'] ?? "";
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
    }
  }

  // --- 1a. LOAD SESSION ADDRESS (Auto-fill PIN + Area) ---
  Future<void> _loadSessionAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // FIX: Use correct keys that match SessionService
      String? sessionPin = prefs.getString('current_pincode');
      String? sessionArea = prefs.getString('current_area');

      if (sessionPin != null && sessionArea != null) {
        setState(() {
          _pinCtrl.text = sessionPin;
          _cityCtrl.text = sessionArea; // Use area as service area
        });
        // Check zone immediately
        _checkZoneAndFees(sessionPin);
        // Fetch district and state from PIN code API
        await _fetchDistrictState(sessionPin);
      }
    } catch (e) {
      debugPrint("Error loading session address: $e");
    }
  }

  // --- Fetch District and State from PIN code ---
  Future<void> _fetchDistrictState(String pin) async {
    if (pin.length != 6) return;
    
    try {
      final url = Uri.parse('https://api.postalpincode.in/pincode/$pin');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[0]['Status'] == 'Success') {
          final postOffice = data[0]['PostOffice'][0];
          setState(() {
            _districtCtrl.text = postOffice['District'];
            _stateCtrl.text = postOffice['State'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching district/state: $e");
    }
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
      // Only fill if currently empty (don't overwrite profile data)
      if (_nameCtrl.text.isEmpty) {
        _nameCtrl.text = address['name'] ?? "";
      }
      if (_phoneCtrl.text.isEmpty) {
        _phoneCtrl.text = address['phone'] ?? "";
      }
      // Fill other fields (can overwrite as they don't come from profile)
      _altPhoneCtrl.text = address['alt_phone'] ?? "";
      _houseCtrl.text = address['house_no'] ?? "";
      _streetCtrl.text = address['street'] ?? "";
      _landmarkCtrl.text = address['landmark'] ?? "";
      _marketCtrl.text = address['nearby_market'] ?? "";
      _districtCtrl.text = address['district'] ?? "";
      _stateCtrl.text = address['state'] ?? "";
      // DON'T overwrite service area and pincode - they come from session only
      // _cityCtrl.text = address['service_area'] ?? address['city'] ?? "";
      // _pinCtrl.text = address['pincode'] ?? "";
    });
    
    // Service area and pincode are already set from session, no need to check again
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
                                "${data['house_no']}, ${data['service_area'] ?? data['city']}, ${data['pincode']}"),
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

  // Instant Delivery Variables are at top of class (lines 58-62)
  
  // Low Cart Variables are at top of class (lines 63-66)

  // Platform Fee Configuration
  bool _platformFeeEnabled = false;
  String _platformFeeType = 'fixed';
  double _platformFeeValue = 0;

  // First Order Configuration
  bool _firstOrderFreeDelivery = true;
  bool _firstOrderDetailedWaiver = true;

  // Zone Logic
  bool _isZoneFound = false;
  String _zoneName = "";

  bool _isFirstOrder = false;
  double _appliedDeliveryFee = 0;
  double _appliedLowCartFee = 0;
  double _appliedPlatformFee = 0;

  // --- 4. FETCH SETTINGS & ZONE LOGIC ---
  Future<void> _fetchVendorSettings() async {
    try {
      // Fetch settings for the Specific Vendor (Passed from Cart)
      var doc = await FirebaseFirestore.instance
          .collection('vendor_settings')
          .doc(widget.vendorId)
          .get();
          
      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          // Delivery
          _freeDeliveryEnabled = data['free_delivery_enabled'] ?? true;
          _minFreeDelivery = (data['min_order_value_free_delivery'] ?? 0).toDouble();
          _fallbackStandardFee = (data['standard_delivery_fee'] ?? 25).toDouble();
          
          // Instant Delivery
          _freeInstantDeliveryEnabled = data['free_instant_delivery_enabled'] ?? false;
          _minFreeInstantDelivery = (data['min_order_value_free_instant'] ?? 0).toDouble();
          _fallbackInstantFee = (data['instant_delivery_fee'] ?? 50).toDouble();
          
          // Low Cart
          _lowCartEnabled = data['low_cart_enabled'] ?? true;
          _lowCartThreshold = (data['low_cart_threshold'] ?? 0).toDouble();
          _lowCartFee = (data['low_cart_fee'] ?? 0).toDouble();
          
          // Platform
          _platformFeeEnabled = data['platform_fee_enabled'] ?? false;
          _platformFeeType = data['platform_fee_type'] ?? 'fixed';
          _platformFeeValue = (data['platform_fee_value'] ?? 0).toDouble();

          // First Order
          _firstOrderFreeDelivery = data['first_order_free_delivery_enabled'] ?? true;
          _firstOrderDetailedWaiver = data['first_order_low_cart_waived'] ?? true;
        });
      }
      
      // After fetching settings, check if first order
      _checkFirstOrder();

    } catch (e) {
      debugPrint("Error fetching settings: $e");
    }
  }

  Future<void> _checkFirstOrder() async {
    if (user == null) return;
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('user_id', isEqualTo: user!.uid)
          .where('status', isNotEqualTo: 'Cancelled') // Don't count cancelled orders
          .limit(1)
          .get();

      setState(() {
        _isFirstOrder = snapshot.docs.isEmpty;
      });
      
      // Recalculate fees after checking first order status
      _updateTotalFee();
      
    } catch (e) {
      debugPrint("Error checking first order: $e");
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

        // Free delivery logic moved to _updateTotalFee
        // if (widget.subtotal >= _minFreeDelivery && _minFreeDelivery > 0) {
        //   std = 0;
        // }

        setState(() {
          _isZoneFound = true;
          _zoneName = data['zone_name'];
          _standardFee = std;
          _instantFee = inst;
          _updateTotalFee();
        });
      } else {
        // Check if this is a session pincode (validated at gate)
        final prefs = await SharedPreferences.getInstance();
        String? sessionPin = prefs.getString('current_pincode');
        bool isSessionPin = sessionPin != null && sessionPin == pincode;

        setState(() {
          if (isSessionPin) {
            _isZoneFound = true;
            _zoneName = "Standard Delivery";
            _standardFee = _fallbackStandardFee; 
            _instantFee = _fallbackInstantFee;
            _updateTotalFee();
          } else {
            _isZoneFound = false;
            _zoneName = "Not Deliverable";
            _standardFee = 0;
            _instantFee = 0;
            _deliveryFee = 0;
          }
        });

        if (mounted && !isSessionPin) {
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
      // 1. DELIVERY FEE CALCULATION
      double baseDeliveryFee = (_deliveryMode == 'Standard') ? _standardFee : _instantFee;
      
      // Check Free Delivery Threshold based on Mode
      if (_deliveryMode == 'Standard') {
        if (_freeDeliveryEnabled && _minFreeDelivery > 0 && widget.subtotal >= _minFreeDelivery) {
          baseDeliveryFee = 0;
        }
      } else if (_deliveryMode == 'Instant') {
        if (_freeInstantDeliveryEnabled && _minFreeInstantDelivery > 0 && widget.subtotal >= _minFreeInstantDelivery) {
           baseDeliveryFee = 0;
        }
      }
      
      // Check First Order Free Delivery
      if (_isFirstOrder && _firstOrderFreeDelivery) {
        baseDeliveryFee = 0;
      }
      
      _appliedDeliveryFee = baseDeliveryFee;
      _deliveryFee = baseDeliveryFee; // For backward compatibility with existing code

      // 2. LOW CART FEE CALCULATION
      double lowCartFee = 0;
      if (_lowCartEnabled && _lowCartThreshold > 0 && widget.subtotal < _lowCartThreshold) {
        lowCartFee = _lowCartFee;
      }
      
      // Check First Order Low Cart Waiver
      if (_isFirstOrder && _firstOrderDetailedWaiver) {
        lowCartFee = 0;
      }
      
      _appliedLowCartFee = lowCartFee;

      // 3. PLATFORM FEE CALCULATION
      double platformFee = 0;
      if (_platformFeeEnabled) {
        if (_platformFeeType == 'percent') {
          platformFee = (widget.subtotal * _platformFeeValue) / 100;
        } else {
          platformFee = _platformFeeValue;
        }
      }
      _appliedPlatformFee = platformFee;
    });
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    
    // FIX: Trust pincode gate validation - if PIN is from session, it's valid
    // Only block if:
    // 1. No zone found AND
    // 2. Pincode is not from session (manually entered)
    final prefs = await SharedPreferences.getInstance();
    String? sessionPin = prefs.getString('current_pincode');
    bool isPincodeFromSession = sessionPin != null && _pinCtrl.text == sessionPin;
    
    if (!_isZoneFound && !isPincodeFromSession) {
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

      // Aggregate all unique seller IDs from cart items (handling stale data)
      Set<String> sellerIds = {};
      List<Map<String, dynamic>> finalCartItems = [];

      for (var item in widget.cartItems) {
        Map<String, dynamic> processedItem = Map.from(item); // Create a mutable copy
        String? sellerId = processedItem['seller_id'];
        String? productId = processedItem['product_id'] ?? processedItem['id'];

        // If seller_id is missing (stale cart), fetch it from Master Product
        if ((sellerId == null || sellerId.isEmpty) && productId != null) {
          try {
            var doc = await FirebaseFirestore.instance.collection('master_products').doc(productId).get();
            if (doc.exists) {
              sellerId = doc.data()?['seller_id'];
              if (sellerId != null && sellerId.isNotEmpty) {
                processedItem['seller_id'] = sellerId; // Update item with recovered ID
              }
            }
          } catch (e) {
            debugPrint("Error recovering seller_id for $productId: $e");
          }
        }
        
        // SNAPSHOT RETURN POLICY from Vendor Inventory
        if (productId != null) {
          try {
             var invQuery = await FirebaseFirestore.instance
                 .collection('vendor_inventory')
                 .where('vendor_id', isEqualTo: widget.vendorId)
                 .where('product_id', isEqualTo: productId)
                 .limit(1)
                 .get();
                 
             if (invQuery.docs.isNotEmpty) {
               var invData = invQuery.docs.first.data();
               processedItem['return_policy_type'] = invData['return_policy_type'] ?? 'No Return';
               processedItem['return_window_days'] = invData['return_window_days'] ?? 0;
             } else {
               processedItem['return_policy_type'] = 'No Return';
               processedItem['return_window_days'] = 0;
             }
          } catch (e) {
             debugPrint("Error snapshotting policy for $productId: $e");
             processedItem['return_policy_type'] = 'No Return';
          }
        }

        if (sellerId != null && sellerId.isNotEmpty) {
          sellerIds.add(sellerId);
        }
        finalCartItems.add(processedItem); // Use updated items in order
      }

      Map<String, dynamic> orderData = {
        'order_id':
            "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        'customer_id': user?.uid,
        'customer_phone': _phoneCtrl.text.trim(),
        'vendor_id': widget.vendorId, // This routes to the Darkstore
        'seller_ids': sellerIds.toList(), // CRITICAL: This allows Sellers to track their products
        'items': finalCartItems, // Use enriched items with seller_id
        'product_total': widget.subtotal,
        'delivery_fee': _appliedDeliveryFee,
        'low_cart_fee': _appliedLowCartFee,
        'platform_fee': _appliedPlatformFee,
        'is_first_order': _isFirstOrder,
        'total_amount': widget.subtotal + _appliedDeliveryFee + _appliedLowCartFee + _appliedPlatformFee,
        'payment_method': _paymentMethod,
        'payment_status': _paymentMethod == 'UPI' ? 'Paid' : 'Pending',
        'delivery_mode': _deliveryMode,
        'delivery_pin': deliveryPin,
        'status': 'Pending',
        'delivery_address': {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'alt_phone': _altPhoneCtrl.text.trim(),
          'house_no': _houseCtrl.text.trim(),
          'street': _streetCtrl.text.trim(),
          'landmark': _landmarkCtrl.text.trim(),
          'nearby_market': _marketCtrl.text.trim(),
          'service_area': _cityCtrl.text.trim(),
          'district': _districtCtrl.text.trim(),
          'state': _stateCtrl.text.trim(),
          'pincode': _pinCtrl.text.trim(),
        },
        'created_at': FieldValue.serverTimestamp(),
        // Initialize fields for Rider Logic
        'rider_commission': 0, // Will be calculated when Rider Accepts
        'is_settled': false,
      };

      await FirebaseFirestore.instance.collection('orders').add(orderData);
      
      // DECREMENT STOCK
      // We iterate through items and update master_products directly.
      // Note: In a high-concurrency app, this should be a Transaction.
      // For now, we use a simple batch/loop with FieldValue.increment.
      
      final batch = FirebaseFirestore.instance.batch();
      bool stockUpdatesNeeded = false;

      for (var item in finalCartItems) {
         String? productId = item['product_id'] ?? item['id'];
         int quantity = item['quantity'] ?? 0;
         
         if (productId != null && quantity > 0) {
             var productRef = FirebaseFirestore.instance.collection('master_products').doc(productId);
             batch.update(productRef, {
                'stock_quantity': FieldValue.increment(-quantity)
             });
             stockUpdatesNeeded = true;
         }
      }

      if (stockUpdatesNeeded) {
          try {
             await batch.commit();
          } catch (e) {
             debugPrint("Stock update failed (non-fatal for order): $e");
          }
      }

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

      // SEND NOTIFICATION TO VENDOR
      await NotificationService.sendNotification(
        vendorId: widget.vendorId,
        title: 'New Order Received',
        message: 'Order #${orderData['order_id']} for ₹${orderData['total_amount']} placed.',
        type: 'order_new',
        orderId: orderData['order_id'], // Might differ from doc ID, but usable for display
      );

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
                            builder: (_) => const CustomerDashboard()));
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
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _houseCtrl.dispose();
    _streetCtrl.dispose();
    _landmarkCtrl.dispose();
    _marketCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  bool shouldShowNudge() {
    double minFree = (_deliveryMode == 'Instant') ? _minFreeInstantDelivery : _minFreeDelivery;
    bool enabled = (_deliveryMode == 'Instant') ? _freeInstantDeliveryEnabled : _freeDeliveryEnabled;

    if (!enabled || minFree <= 0 || widget.subtotal >= minFree) {
      return false;
    }
    return true;
  }

  double getNudgeAmount() {
    return (_deliveryMode == 'Instant') ? _minFreeInstantDelivery : _minFreeDelivery;
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
                  Text("₹${widget.subtotal + _appliedDeliveryFee + _appliedLowCartFee + _appliedPlatformFee}",
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
              // 1. DELIVERY ADDRESS SECTION - Always Visible Contact Info
              const Text("Delivery Address",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    // Contact Details - Always Visible & Editable
                    _buildTextField(_nameCtrl, "Full Name *"),
                    const SizedBox(height: 10),
                    _buildTextField(_phoneCtrl, "Phone Number *", isNumber: true),
                    const SizedBox(height: 10),
                    _buildTextField(_altPhoneCtrl, "Alternative Phone (Optional)", isNumber: true),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. ADDRESS DETAILS - Expandable Section
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: _isAddressExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() => _isAddressExpanded = expanded);
                    },
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    leading: const Icon(Icons.home_outlined, color: Colors.green),
                    title: const Text(
                      "Address Details",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      _isAddressExpanded ? "Tap to collapse" : "Tap to expand",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: _showAddressSelector,
                          icon: const Icon(Icons.bookmark_border, size: 16),
                          label: const Text("Saved", style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        Icon(
                          _isAddressExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                      ],
                    ),
                    children: [
                      Row(children: [
                        Expanded(
                            child: _buildTextField(_houseCtrl, "House No/Flat *")),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildTextField(_pinCtrl, "Pincode *",
                                isNumber: true, readOnly: true)),
                      ]),
                      const SizedBox(height: 10),
                      _buildTextField(_streetCtrl, "Street/Area/Colony *"),
                      const SizedBox(height: 10),
                      _buildTextField(_landmarkCtrl, "Landmark *"),
                      const SizedBox(height: 10),
                      _buildTextField(_marketCtrl, "Nearby Market *"),
                      const SizedBox(height: 10),
                      _buildTextField(_cityCtrl, "Service Area *",
                          readOnly: true,
                          suffixIcon: const Icon(Icons.lock_outline,
                              size: 16, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(_districtCtrl, "District",
                                readOnly: true)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildTextField(_stateCtrl, "State",
                                readOnly: true)),
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
                        Text("Standard Delivery")
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
                    
                    // Delivery Fee Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Delivery Fee", style: TextStyle(color: Colors.grey)),
                        Row(
                          children: [
                            if (_appliedDeliveryFee == 0 && _deliveryFee > 0) ...[
                              Text("₹$_deliveryFee", 
                                style: const TextStyle(
                                  color: Colors.grey, 
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 12
                                )
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              _appliedDeliveryFee == 0 ? "FREE" : "₹$_appliedDeliveryFee",
                              style: TextStyle(
                                color: _appliedDeliveryFee == 0 ? Colors.green : Colors.black,
                                fontWeight: _appliedDeliveryFee == 0 ? FontWeight.bold : FontWeight.normal
                              )
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_appliedLowCartFee > 0)
                      _buildSummaryRow("Low Cart Fee", "₹$_appliedLowCartFee"),
                      
                    if (_appliedPlatformFee > 0)
                       _buildSummaryRow("Platform Fee", "₹${_appliedPlatformFee.toStringAsFixed(2)}"),

                    const Divider(),
                    _buildSummaryRow(
                        "Grand Total", "₹${widget.subtotal + _appliedDeliveryFee + _appliedLowCartFee + _appliedPlatformFee}",
                        isBold: true),
                        
                    // Free Delivery Nudge
                    if (shouldShowNudge())
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.withOpacity(0.3))
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.stars, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              "Add ₹${(getNudgeAmount() - widget.subtotal).toStringAsFixed(0)} more for FREE ${_deliveryMode} Delivery",
                              style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      
                     if (_isFirstOrder && (_firstOrderFreeDelivery || _firstOrderDetailedWaiver))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "🎉 First Order Offer Applied!",
                            style: TextStyle(color: Colors.purple[700], fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                          ),
                        ),
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
      {bool isNumber = false, Function(String)? onChanged, bool readOnly = false, Widget? suffixIcon}) {
    // Check if field is optional based on hint text
    bool isOptional = hint.contains('(Optional)') || (!hint.contains('*') && readOnly);
    
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[100] : null,
        suffixIcon: suffixIcon ?? (readOnly ? const Icon(Icons.lock_outline, size: 18, color: Colors.grey) : null),
      ),
      validator: (val) {
        if (isOptional) return null;
        return (val == null || val.isEmpty) ? "Required" : null;
      },
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
