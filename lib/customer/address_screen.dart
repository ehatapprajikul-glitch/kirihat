import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressScreen extends StatefulWidget {
  final String? addressId;
  final Map<String, dynamic>? initialData;

  const AddressScreen({super.key, this.addressId, this.initialData});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetchingPin = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _houseController;
  late TextEditingController _streetController;
  late TextEditingController _landmarkController;
  late TextEditingController _marketController;
  late TextEditingController _cityController;
  late TextEditingController _districtController;
  late TextEditingController _stateController;
  late TextEditingController _pinController;

  // Manual Coordinate Controllers
  late TextEditingController _latController;
  late TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    var data = widget.initialData ?? {};

    _nameController = TextEditingController(text: data['name'] ?? "");
    _phoneController = TextEditingController(text: data['phone'] ?? "");
    _altPhoneController = TextEditingController(text: data['alt_phone'] ?? "");

    _houseController = TextEditingController(text: data['house_no'] ?? "");
    _streetController = TextEditingController(text: data['street'] ?? "");
    _landmarkController = TextEditingController(text: data['landmark'] ?? "");
    _marketController =
        TextEditingController(text: data['nearby_market'] ?? "");
    _cityController = TextEditingController(text: data['city'] ?? "");

    _districtController = TextEditingController(text: data['district'] ?? "");
    _stateController = TextEditingController(text: data['state'] ?? "");
    _pinController = TextEditingController(text: data['pincode'] ?? "");

    // Initialize Lat/Lng Controllers
    double? initialLat;
    double? initialLng;

    if (data.containsKey('location')) {
      GeoPoint p = data['location'];
      initialLat = p.latitude;
      initialLng = p.longitude;
    }

    _latController = TextEditingController(text: initialLat?.toString() ?? "");
    _lngController = TextEditingController(text: initialLng?.toString() ?? "");

    if (widget.addressId == null) {
      _fetchUserDetails();
    }
  }

  Future<void> _fetchUserDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && _nameController.text.isEmpty) {
        setState(() => _nameController.text = user.displayName!);
      }

      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        var userData = doc.data();
        setState(() {
          if (_phoneController.text.isEmpty) {
            _phoneController.text = userData?['phone'] ?? "";
          }
          if (_nameController.text.isEmpty) {
            _nameController.text = userData?['name'] ?? "";
          }
        });
      }
    }
  }

  // --- ROBUST GPS DETECTION (FIXED FOR GEOLOCATOR 13) ---
  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // 1. Check Service Status
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        // Check again after opening settings
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw "Location services are disabled. Please enable GPS.";
        }
      }

      // 2. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw "Location permission denied.";
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw "Location permission permanently denied. Enable in Settings.";
      }

      // 3. Get Coordinates (Corrected for v13.0.1)
      LocationSettings locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);

      // Update Manual Fields
      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });

      // 4. Reverse Geocoding
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        setState(() {
          _pinController.text = place.postalCode ?? "";
          _stateController.text = place.administrativeArea ?? "";
          _cityController.text =
              place.locality ?? place.subAdministrativeArea ?? "";
          _districtController.text = place.subAdministrativeArea ?? "";
          _streetController.text =
              "${place.subLocality ?? ''} ${place.thoroughfare ?? ''}".trim();

          if (_houseController.text.isEmpty) {
            _houseController.text = place.name ?? "";
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Location Detected!"),
              backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("GPS Error: $e"), backgroundColor: Colors.red));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // --- PINCODE API LOGIC ---
  Future<void> _fetchPinDetails(String pin) async {
    if (pin.length != 6) return;
    setState(() => _isFetchingPin = true);
    try {
      final url = Uri.parse('https://api.postalpincode.in/pincode/$pin');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[0]['Status'] == 'Success') {
          final postOffice = data[0]['PostOffice'][0];
          setState(() {
            _districtController.text = postOffice['District'];
            _stateController.text = postOffice['State'];
            if (_cityController.text.isEmpty) {
              _cityController.text = postOffice['Block'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching PIN: $e");
    }
    if (mounted) setState(() => _isFetchingPin = false);
  }

  // --- SAVE ---
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please fix the errors in red"),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not logged in";
      String uid = user.uid;

      Map<String, dynamic> addressData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'alt_phone': _altPhoneController.text.trim(),
        'house_no': _houseController.text.trim(),
        'street': _streetController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'nearby_market': _marketController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pinController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      };

      // VITAL: Parse Lat/Lng from Text Fields
      double? finalLat = double.tryParse(_latController.text);
      double? finalLng = double.tryParse(_lngController.text);

      if (finalLat != null && finalLng != null) {
        addressData['location'] = GeoPoint(finalLat, finalLng);
      }

      if (widget.addressId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('addresses')
            .doc(widget.addressId)
            .update(addressData);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('addresses')
            .add(addressData);
      }

      // Automatically Set as Default
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'current_address': addressData,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Address Saved Successfully!"),
            backgroundColor: Colors.green));
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
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _houseController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _marketController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pinController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.addressId != null ? "Edit Address" : "Add Address"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. GPS BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _useCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                      _isLoading ? "Detecting..." : "DETECT MY LOCATION (GPS)"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.blue.shade200)),
                ),
              ),
              const SizedBox(height: 20),

              // --- 2. MANUAL COORDINATES ---
              const Text("Coordinates (Auto-filled or Manual)",
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField(
                          _latController, "Latitude", Icons.explore,
                          isNumber: true, isMandatory: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildTextField(
                          _lngController, "Longitude", Icons.explore,
                          isNumber: true, isMandatory: true)),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 10),

              // --- 3. CONTACT DETAILS ---
              const Text("Contact Details",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildTextField(
                  _nameController, "Receiver's Full Name *", Icons.person,
                  isMandatory: true),
              const SizedBox(height: 15),
              _buildTextField(_phoneController, "Mobile Number *", Icons.phone,
                  isMandatory: true, isNumber: true),
              const SizedBox(height: 15),
              _buildTextField(_altPhoneController,
                  "Alternative Mobile (Optional)", Icons.phone_android,
                  isNumber: true),

              const SizedBox(height: 25),

              // --- 4. ADDRESS DETAILS ---
              const Text("Address Details",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildTextField(
                  _houseController, "House No / Building *", Icons.home,
                  isMandatory: true),
              const SizedBox(height: 15),
              _buildTextField(
                  _streetController, "Street / Area / Colony *", Icons.add_road,
                  isMandatory: true),
              const SizedBox(height: 15),
              _buildTextField(_landmarkController, "Landmark *", Icons.store,
                  isMandatory: true),
              const SizedBox(height: 15),
              _buildTextField(
                  _marketController, "Nearby Market *", Icons.shopping_basket,
                  isMandatory: true),
              const SizedBox(height: 15),
              _buildTextField(
                  _cityController, "Village / City *", Icons.location_city,
                  isMandatory: true),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onChanged: (val) {
                        if (val.length == 6) _fetchPinDetails(val);
                      },
                      validator: (val) => (val == null || val.length != 6)
                          ? "Invalid PIN"
                          : null,
                      decoration: InputDecoration(
                        labelText: "PIN Code *",
                        prefixIcon:
                            const Icon(Icons.pin_drop, color: Colors.green),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        counterText: "",
                        suffixIcon: _isFetchingPin
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField(
                          _districtController, "District", Icons.map,
                          isReadOnly: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildTextField(
                          _stateController, "State", Icons.flag,
                          isReadOnly: true)),
                ],
              ),
              const SizedBox(height: 30),

              // --- SAVE BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SAVE ADDRESS",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isMandatory = false,
      bool isReadOnly = false,
      bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      readOnly: isReadOnly,
      keyboardType: isNumber
          ? (label.contains("Latitude") || label.contains("Longitude")
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.phone)
          : TextInputType.text,
      maxLength: (isNumber && label.contains("Mobile")) ? 10 : null,
      validator: (val) {
        if (isMandatory && (val == null || val.trim().isEmpty))
          return "$label is required";
        if (isNumber &&
            label.contains("Mobile") &&
            val != null &&
            val.isNotEmpty &&
            val.length != 10) return "Must be 10 digits";
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green),
        filled: isReadOnly,
        counterText: "",
        fillColor: isReadOnly ? Colors.grey[200] : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
