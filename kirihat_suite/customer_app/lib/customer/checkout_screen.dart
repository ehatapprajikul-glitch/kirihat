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
import 'package:kirihat_core/utils/currency_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kirihat_core/services/coupon_service.dart';
import 'package:kirihat_core/services/fee_configuration_service.dart';

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
  bool _isEditingAddress = true; // Default to true until checked

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
    
    // Switch to Summary View
    setState(() => _isEditingAddress = false);
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
      // FIX: Query 'service_areas' (Admin Portal) instead of 'vendor_zones'
      var snapshot = await FirebaseFirestore.instance
          .collection('service_areas')
          .where('vendor_id', isEqualTo: widget.vendorId)
          .where('pincode', isEqualTo: pincode) // Exact match for string pincode
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        
        // Use configured fees from Global Settings as fallback since service_areas doesn't have fee fields yet
        // If fee fields exist in future, use them: data['standard_fee'] ?? _fallbackStandardFee
        double std = (data.containsKey('standard_fee')) ? (data['standard_fee'] ?? 0).toDouble() : _fallbackStandardFee;
        double inst = (data.containsKey('instant_fee')) ? (data['instant_fee'] ?? 0).toDouble() : _fallbackInstantFee;

        setState(() {
          _isZoneFound = true;
          _zoneName = data['zoneName'] ?? "Delivery Zone";
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
            _standardFee = 0; // Don't show misleading free in UI
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

  // Coupon State
  final _couponController = TextEditingController();
  Map<String, dynamic>? _activeCoupon;
  double _couponDiscount = 0;
  bool _isCheckingCoupon = false;

  void _applyCoupon() async {
    String code = _couponController.text.trim();
    if (code.isEmpty) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to use coupons")));
      return;
    }

    setState(() => _isCheckingCoupon = true);

    try {
      final result = await CouponService().validateCoupon(
        code: code,
        userId: user!.uid,
        cartTotal: widget.subtotal,
        cartItems: widget.cartItems,
      );

      setState(() {
        _activeCoupon = result;
        _couponDiscount = (result['discount_amount'] ?? 0).toDouble();
        _updateTotalFee(); // Recalculate total with discount
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Coupon '${result['code']}' applied!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }

    setState(() => _isCheckingCoupon = false);
  }

  void _removeCoupon() {
    setState(() {
      _activeCoupon = null;
      _couponDiscount = 0;
      _couponController.clear();
      _updateTotalFee();
    });
  }

  // --- UI SECTION FOR COUPON ---
  Widget _buildCouponSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                 child: const Icon(Icons.discount, color: Colors.orange, size: 20),
               ),
               const SizedBox(width: 12),
               const Text("Coupons & Offers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_activeCoupon != null)
             _buildAppliedCouponCard()
          else
             _buildCouponInput(),
        ],
      ),
    );
  }

  Widget _buildAppliedCouponCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "'${_activeCoupon!['code']}' Applied", 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 15)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeCoupon!['description'], 
                        style: TextStyle(fontSize: 13, color: Colors.green.shade700)
                      ),
                      const SizedBox(height: 4),
                      Text(
                         "You saved ${CurrencyHelper.format(_couponDiscount)}",
                         style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                      )
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _removeCoupon,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("REMOVE"),
                )
              ],
            ),
          ),
          // Decorative Circles
          Positioned(top: -10, left: -10, child: CircleAvatar(radius: 10, backgroundColor: Colors.white)),
          Positioned(bottom: -10, left: -10, child: CircleAvatar(radius: 10, backgroundColor: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildCouponInput() {
    return Container(
       decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid), // Should use DottedBorder ideally but standard border is safer without packages
       ),
       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
       child: Row(
         children: [
           Expanded(
             child: TextField(
               controller: _couponController,
               decoration: const InputDecoration(
                 hintText: "Enter Coupon Code",
                 hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                 border: InputBorder.none,
                 contentPadding: EdgeInsets.symmetric(horizontal: 16),
                 isDense: true,
               ),
               style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
               textCapitalization: TextCapitalization.characters,
             ),
           ),
           ElevatedButton(
             onPressed: _isCheckingCoupon ? null : _applyCoupon,
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.black,
               foregroundColor: Colors.white,
               elevation: 0,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
             ),
             child: _isCheckingCoupon 
                 ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                 : const Text("APPLY", style: TextStyle(fontWeight: FontWeight.bold)),
           ),
         ],
       ),
    );
  }

  // --- MODIFIED TOTAL CALCULATION ---
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
      
      // Check First Order Free Delivery (STANDARD DELIVERY ONLY)
      // FIX: Don't waive Instant Delivery fee for first order
      if (_isFirstOrder && _firstOrderFreeDelivery && _deliveryMode == 'Standard') {
        baseDeliveryFee = 0;
      }
      
      _appliedDeliveryFee = baseDeliveryFee;
      _deliveryFee = baseDeliveryFee; 

      // 2. LOW CART FEE
      double lowCartFee = 0;
      if (_lowCartEnabled && _lowCartThreshold > 0 && widget.subtotal < _lowCartThreshold) {
        lowCartFee = _lowCartFee;
      }
      if (_isFirstOrder && _firstOrderDetailedWaiver) {
        lowCartFee = 0;
      }
      _appliedLowCartFee = lowCartFee;

      // 3. PLATFORM FEE
      double platformFee = 0;
      if (_platformFeeEnabled) {
        if (_platformFeeType == 'percent') {
          platformFee = (widget.subtotal * _platformFeeValue) / 100;
        } else {
          platformFee = _platformFeeValue;
        }
      }
      _appliedPlatformFee = platformFee;
      
      // 4. COUPON VALIDATION (Re-validate if total changed?)
      // Ideally, we should re-check min order value here if subtotal changed, but subtotal is constant in this screen.
      // So simple subtraction is fine.
    });
  }

  Future<void> _validateAndProceed() async {
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

    if (_paymentMethod == 'UPI') {
      await _handleUpiPayment();
    } else {
      // COD Flow
      await _createOrderInFirestore(paymentStatus: 'Pending');
    }
  }

  Future<void> _handleUpiPayment() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Get Admin VPA from Firestore
      String payeeVpa = "";
      String payeeName = "Kiri Hat Admin";
      
      try {
        var doc = await FirebaseFirestore.instance.collection('admin_settings').doc('payment').get();
        if (doc.exists) {
          payeeVpa = doc.data()?['upi_vpa'] ?? "";
          payeeName = doc.data()?['payee_name'] ?? "Kiri Hat";
        }
      } catch (e) {
        debugPrint("Error fetching VPA: $e");
      }

      if (payeeVpa.isEmpty) {
        if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Online payment unavailable (VPA not configured). Please use COD.")));
        }
        setState(() => _isLoading = false);
        return;
      }

      // 2. Construct UPI URI
      final double amount = widget.subtotal + _appliedDeliveryFee + _appliedLowCartFee + _appliedPlatformFee - _couponDiscount;
      final String txnId = "TXN${DateTime.now().millisecondsSinceEpoch}";
      final String note = "Order from Kiri Hat";
      
      // UPI URI Format
      String upiUrl = 
          "upi://pay?pa=$payeeVpa&pn=${Uri.encodeComponent(payeeName)}&am=$amount&tr=$txnId&tn=${Uri.encodeComponent(note)}&cu=INR";
      
      Uri uri = Uri.parse(upiUrl);

      // 3. Launch UPI App
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // 4. Show Confirmation Dialog
        // Since we can't detect 'success' callback from intent without a native SDK,
        // we ask the user to confirm. 
        // Note: For higher security in production, you would check your Bank API to confirm receipt of $amount with ref $txnId.
        if (mounted) {
           showDialog(
             context: context,
             barrierDismissible: false,
             builder: (ctx) => AlertDialog(
               title: const Text("Confirm Payment"),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Text("1. Did you complete the payment in the UPI app?"),
                   const SizedBox(height: 10),
                   Text("Amount: ${CurrencyHelper.format(amount)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 10),
                   const Text("2. If yes, click 'I have Paid' to place your order.", 
                     style: TextStyle(fontSize: 12, color: Colors.grey)),
                 ],
               ),
               actions: [
                 TextButton(
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      setState(() => _isLoading = false); // Cancel loader
                    },
                    child: const Text("Cancel / Retry", style: TextStyle(color: Colors.red))),
                 ElevatedButton(
                    onPressed: () {
                       Navigator.pop(ctx); // Close dialog
                       _createOrderInFirestore(paymentStatus: 'Paid', txnId: txnId);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text("I HAVE PAID"),
                 ),
               ],
             ),
           );
        }
      } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
               content: Text("No UPI app found. Please install PhonePe, GPay, or Paytm.")));
         }
         setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("UPI Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment Error: $e")));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createOrderInFirestore({required String paymentStatus, String? txnId}) async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch Current Fee Configuration (Snapshot for historical accuracy)
      final feeService = FeeConfigurationService();
      final feeConfig = await feeService.getFeeConfiguration();
      
      // 2. Fetch Commission Settings for this Vendor
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

        // Always fetch from Master Product to get seller info and base price
        if (productId != null) {
          try {
            var doc = await FirebaseFirestore.instance.collection('master_products').doc(productId).get();
            if (doc.exists) {
              var data = doc.data();
              if (sellerId == null || sellerId.isEmpty) {
                sellerId = data?['seller_id'];
                if (sellerId != null && sellerId.isNotEmpty) {
                  processedItem['seller_id'] = sellerId; 
                }
              }
              // Add Cost Price for Analytics
              if (processedItem['cost_price'] == null && data?['cost_price'] != null) {
                processedItem['cost_price'] = data?['cost_price'];
              }
              
              // CRITICAL: Store seller's base price for seller analytics
              // The 'price' field contains vendor's selling price (what customer pays)
              // We need seller's base price for correct seller profit calculations
              if (data?['selling_price'] != null) {
                processedItem['vendor_selling_price'] = processedItem['price']; // Customer pays this
                processedItem['seller_base_price'] = data?['selling_price']; // Seller gets this
                // Keep 'selling_price' as vendor's price for customer total
                processedItem['selling_price'] = processedItem['price'];
              }
            }
          } catch (e) {
            debugPrint("Error recovering details for $productId: $e");
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
        'coupon_discount': _couponDiscount, // NEW FIELD
        'coupon_code': _activeCoupon?['code'], // NEW FIELD
        'coupon_id': _activeCoupon?['coupon_id'], // NEW FIELD
        'is_first_order': _isFirstOrder,
        'total_amount': widget.subtotal + _appliedDeliveryFee + _appliedLowCartFee + _appliedPlatformFee - _couponDiscount,
        'payment_method': _paymentMethod,
        'payment_status': paymentStatus, // SET FROM ARG
        'start_transaction_id': txnId, // SAVE TXN ID
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
        // Fee Snapshot for Historical Accuracy
        'fees_snapshot': {
          'platform_fee_percentage': feeConfig.platformFeePercentage,
          'delivery_fee_default': feeConfig.deliveryFeeDefault,
          'payment_gateway_fee_percentage': feeConfig.paymentGatewayFeePercentage,
          'payment_gateway_fixed_fee': feeConfig.paymentGatewayFixedFee,
          'packaging_fee': feeConfig.packagingFee,
          'captured_at': FieldValue.serverTimestamp(),
        },
        'created_at': FieldValue.serverTimestamp(),
        // Initialize fields for Rider Logic
        'rider_commission': 0, // Will be calculated when Rider Accepts
        'is_settled': false,
      };

      await FirebaseFirestore.instance.collection('orders').add(orderData);
      
      // Increment Coupon Usage
      if (_activeCoupon != null && _activeCoupon!['coupon_id'] != null) {
        try {
           await FirebaseFirestore.instance.collection('coupons').doc(_activeCoupon!['coupon_id']).update({
             'used_count': FieldValue.increment(1)
           });
        } catch (e) {
           debugPrint("Failed to update coupon usage: $e");
        }
      }
      
      // DECREMENT STOCK for BOTH vendor_inventory AND master_products
      // We iterate through items and update both collections
      // Note: In a high-concurrency app, this should be a Transaction.
      // For now, we use a simple batch/loop with FieldValue.increment.
      
      final batch = FirebaseFirestore.instance.batch();
      bool stockUpdatesNeeded = false;

      for (var item in finalCartItems) {
         String? productId = item['product_id'] ?? item['id'];
         int quantity = item['quantity'] ?? 0;
         
         if (productId != null && quantity > 0) {
             // 1. Decrease seller's master_products stock
             var productRef = FirebaseFirestore.instance.collection('master_products').doc(productId);
             batch.update(productRef, {
                'stock_quantity': FieldValue.increment(-quantity)
             });
             
             // 2. Decrease vendor's inventory stock
             // Find vendor_inventory document for this product and vendor
             try {
               var vendorInventoryQuery = await FirebaseFirestore.instance
                   .collection('vendor_inventory')
                   .where('vendor_id', isEqualTo: widget.vendorId)
                   .where('product_id', isEqualTo: productId)
                   .limit(1)
                   .get();
               
               if (vendorInventoryQuery.docs.isNotEmpty) {
                 var vendorInvRef = vendorInventoryQuery.docs.first.reference;
                 batch.update(vendorInvRef, {
                   'stock_quantity': FieldValue.increment(-quantity)
                 });
               } else {
                 debugPrint("Warning: No vendor_inventory found for product $productId");
               }
             } catch (e) {
               debugPrint("Error finding vendor_inventory for $productId: $e");
             }
             
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
        message: 'Order #${orderData['order_id']} for ${CurrencyHelper.format(orderData['total_amount'])} placed.',
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
                  Text(CurrencyHelper.format(widget.subtotal + _appliedDeliveryFee + _appliedLowCartFee + _appliedPlatformFee - _couponDiscount),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _validateAndProceed,
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
              // 1. DELIVERY ADDRESS SECTION
              const Text("Delivery Address",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              if (!_isEditingAddress)
                _buildAddressSummaryCard()
              else
                _buildAddressEditForm(),

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
                          _standardFee == 0 ? "FREE" : CurrencyHelper.format(_standardFee),
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
                      subtitle: Text(CurrencyHelper.format(_instantFee),
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
              
              // 2.5 COUPON SECTION
              _buildCouponSection(),

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
                    // TODO: UPI Integration is implemented but hidden for now. Uncomment to enable.
                    /* 
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
                    */
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
                    _buildSummaryRow("Item Total", CurrencyHelper.format(widget.subtotal)),
                    
                    // Delivery Fee Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Delivery Fee", style: TextStyle(color: Colors.grey)),
                        Row(
                          children: [
                            if (_appliedDeliveryFee == 0 && _deliveryFee > 0) ...[
                              Text(CurrencyHelper.format(_deliveryFee), 
                                style: const TextStyle(
                                  color: Colors.grey, 
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 12
                                )
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              _appliedDeliveryFee == 0 ? "FREE" : CurrencyHelper.format(_appliedDeliveryFee),
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
                      _buildSummaryRow("Low Cart Fee", CurrencyHelper.format(_appliedLowCartFee)),
                      
                    if (_appliedPlatformFee > 0)
                       _buildSummaryRow("Platform Fee", CurrencyHelper.format(_appliedPlatformFee)),

                    if (_couponDiscount > 0)
                       _buildSummaryRow("Coupon Discount", "-${CurrencyHelper.format(_couponDiscount)}", isGreen: true, isBold: true),

                    const Divider(),
                    _buildSummaryRow(
                        "Grand Total", CurrencyHelper.format(widget.subtotal + _appliedDeliveryFee + _appliedLowCartFee + _appliedPlatformFee - _couponDiscount),
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
                              "Add ${CurrencyHelper.format(getNudgeAmount() - widget.subtotal)} more for FREE ${_deliveryMode} Delivery",
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

  Widget _buildAddressSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivering to ${_nameCtrl.text}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_houseCtrl.text}, ${_streetCtrl.text}\n${_cityCtrl.text}, ${_districtCtrl.text} - ${_pinCtrl.text}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Phone: ${_phoneCtrl.text}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _showAddressSelector,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                  child: const Text("CHANGE"),
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade300),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _isEditingAddress = true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                  child: const Text("EDIT"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressEditForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Edit Address", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              if (_houseCtrl.text.isNotEmpty) // Only allow minimize if we have some data
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () => setState(() => _isEditingAddress = false),
                  tooltip: "Minimize",
                ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          _buildTextField(_nameCtrl, "Full Name *"),
          const SizedBox(height: 10),
          _buildTextField(_phoneCtrl, "Phone Number *", isNumber: true),
          const SizedBox(height: 10),
          _buildTextField(_altPhoneCtrl, "Alternative Phone", isNumber: true),
          const SizedBox(height: 10),
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
              readOnly: true, suffixIcon: const Icon(Icons.lock, size: 16, color: Colors.grey)),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Determine if valid (simple check)
                if (_nameCtrl.text.isNotEmpty && _houseCtrl.text.isNotEmpty) {
                  setState(() => _isEditingAddress = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text("DONE"),
            ),
          ),
        ],
      ),
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
