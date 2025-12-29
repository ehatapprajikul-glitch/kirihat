import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class VendorLocationSetup extends StatefulWidget {
  const VendorLocationSetup({super.key});

  @override
  State<VendorLocationSetup> createState() => _VendorLocationSetupState();
}

class _VendorLocationSetupState extends State<VendorLocationSetup> {
  // Controllers for Manual Entry
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    // Data loading is handled by StreamBuilder in build() to be safe
  }

  // 1. Fetch Existing Data
  Future<void> _loadExistingData(Map<String, dynamic> data) async {
    // Only fill if controllers are empty (to prevent overwriting user edits)
    if (_businessNameController.text.isEmpty) {
      _businessNameController.text =
          data['business_name'] ?? data['shop_name'] ?? "";
      _addressController.text = data['shop_address'] ?? "";
      _pincodeController.text = data['pincode'] ?? "";

      if (data.containsKey('location')) {
        GeoPoint p = data['location'];
        _latController.text = p.latitude.toString();
        _lngController.text = p.longitude.toString();
      }
    }
  }

  // 2. Auto-Detect GPS & Pincode
  Future<void> _autoDetectLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Requesting Permission...";
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Permission Denied";
      }

      if (permission == LocationPermission.deniedForever) {
        throw "Location denied forever. Enable in Browser Settings.";
      }

      setState(() => _statusMessage = "Fetching GPS...");

      // Get GPS
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Get Address & Pincode from GPS
      setState(() => _statusMessage = "Fetching Address Details...");
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      String detectedAddress = "";
      String detectedPincode = "";

      if (placemarks.isNotEmpty) {
        Placemark p = placemarks[0];
        detectedAddress =
            "${p.street}, ${p.subLocality}, ${p.locality}, ${p.administrativeArea}";
        detectedPincode = p.postalCode ?? "";
      }

      // Update UI
      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();

        // Auto-fill address/pincode ONLY if they are empty or user wants update
        if (_addressController.text.isEmpty)
          _addressController.text = detectedAddress;
        if (_pincodeController.text.isEmpty)
          _pincodeController.text = detectedPincode;

        _statusMessage = "Location Found! Verify details below.";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error: $e. Please enter manually.";
      });
    }
  }

  // 3. Save Everything to Firestore
  Future<void> _saveShopProfile(String uid) async {
    if (_businessNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Business Name is required")));
      return;
    }
    if (_pincodeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter a valid 6-digit Pincode")));
      return;
    }

    double? lat = double.tryParse(_latController.text);
    double? lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid GPS Coordinates")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('vendors').doc(uid).set({
        'business_name': _businessNameController.text.trim(),
        'shop_address': _addressController.text.trim(),
        'pincode':
            _pincodeController.text.trim(), // KEY FIELD FOR SECONDARY SEARCH
        'location': GeoPoint(lat, lng), // KEY FIELD FOR PRIMARY SEARCH
        'is_location_set': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Shop Profile Updated Successfully!"),
          backgroundColor: Colors.green,
        ));
        setState(() => _isLoading = false);
        Navigator.pop(context); // Go back after saving
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Save Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));

        User currentUser = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
              title: const Text("Shop Profile & Location"),
              backgroundColor: Colors.orange[100]),
          body: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vendors')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, vendorSnap) {
                // Load existing data once
                if (vendorSnap.hasData && vendorSnap.data!.exists) {
                  _loadExistingData(
                      vendorSnap.data!.data() as Map<String, dynamic>);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                          child: Icon(Icons.store_mall_directory,
                              size: 60, color: Colors.orange)),
                      const SizedBox(height: 20),

                      // --- SECTION 1: BUSINESS DETAILS ---
                      const Text("Business Details",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _businessNameController,
                        decoration: const InputDecoration(
                            labelText: "Shop / Business Name",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business)),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: "Full Shop Address",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.map)),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                            labelText: "6-Digit Pincode (Important)",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.markunread_mailbox),
                            counterText: ""),
                      ),

                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 10),

                      // --- SECTION 2: GPS LOCATION ---
                      const Text("GPS Location",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 5),
                      const Text("This is used for the 'Nearby' feature.",
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 15),

                      // AUTO DETECT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _autoDetectLocation,
                          icon: const Icon(Icons.my_location),
                          label: Text(_isLoading
                              ? "Processing..."
                              : "AUTO DETECT GPS & PINCODE"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              foregroundColor: Colors.white),
                        ),
                      ),

                      if (_statusMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_statusMessage,
                              style: TextStyle(
                                  color: _statusMessage.contains("Error")
                                      ? Colors.red
                                      : Colors.green)),
                        ),

                      const SizedBox(height: 20),

                      // Manual Lat/Lng Fields
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _latController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: "Latitude",
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _lngController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: "Longitude",
                                  border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // --- SAVE BUTTON ---
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _saveShopProfile(currentUser.uid),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white),
                          child: const Text("SAVE SHOP PROFILE",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
        );
      },
    );
  }
}
