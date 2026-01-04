import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/service_area_service.dart';

class AddressScreen extends StatefulWidget {
  final String? addressId;
  final Map<String, dynamic>? initialData;

  const AddressScreen({super.key, this.addressId, this.initialData});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final ServiceAreaService _serviceAreaService = ServiceAreaService();
  
  bool _isLoading = false;
  bool _isFetchingPin = false;
  List<String> _availableAreas = [];
  String? _selectedArea;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _houseController;
  late TextEditingController _streetController;
  late TextEditingController _landmarkController;
  late TextEditingController _marketController;
  late TextEditingController _districtController;
  late TextEditingController _stateController;
  late TextEditingController _pinController;

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
    _marketController = TextEditingController(text: data['nearby_market'] ?? "");
    _districtController = TextEditingController(text: data['district'] ?? "");
    _stateController = TextEditingController(text: data['state'] ?? "");
    _pinController = TextEditingController(text: data['pincode'] ?? "");
    
    _selectedArea = data['service_area'];

    if (widget.addressId == null) {
      _fetchUserDetails();
    }
    
    // If editing and has pincode, load areas
    if (_pinController.text.length == 6) {
      _fetchPinDetails(_pinController.text);
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

  // --- PINCODE API LOGIC + SERVICE AREA FETCH ---
  Future<void> _fetchPinDetails(String pin) async {
    if (pin.length != 6) return;
    
    // Remember current selection to restore if available
    final previousSelection = _selectedArea;
    
    setState(() {
      _isFetchingPin = true;
      _availableAreas = [];
      _selectedArea = null;
    });
    
    try {
      // Fetch District/State from India Post API
      final url = Uri.parse('https://api.postalpincode.in/pincode/$pin');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[0]['Status'] == 'Success') {
          final postOffice = data[0]['PostOffice'][0];
          setState(() {
            _districtController.text = postOffice['District'];
            _stateController.text = postOffice['State'];
          });
        }
      }
      
      // Fetch Service Areas from vendor service_areas
      final serviceAreas = await _serviceAreaService.getServiceAreasForPincode(pin);
      
      if (serviceAreas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No service available in this pincode yet'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isFetchingPin = false;
        });
        return;
      }
      
      // Extract unique areas
      Set<String> areas = {};
      for (var zone in serviceAreas) {
        if (zone['areas'] != null) {
          areas.addAll(List<String>.from(zone['areas']));
        }
      }
      
      final areasList = areas.toList()..sort();
      
      setState(() {
        _availableAreas = areasList;
        
        // Auto-select previous selection if available
        if (previousSelection != null && areasList.contains(previousSelection)) {
          _selectedArea = previousSelection;
          print('✅ Auto-selected previous service area: $previousSelection');
        } else if (areasList.length == 1) {
          // If only one area, auto-select it
          _selectedArea = areasList.first;
          print('✅ Auto-selected only available area: ${areasList.first}');
        }
        
        _isFetchingPin = false;
      });
      
    } catch (e) {
      debugPrint("Error fetching PIN: $e");
      if (mounted) {
        setState(() => _isFetchingPin = false);
      }
    }
  }

  // --- SAVE ---
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please fix the errors in red"),
          backgroundColor: Colors.red));
      return;
    }
    
    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select a service area"),
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
        'service_area': _selectedArea, // Changed from city
        'district': _districtController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pinController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      };

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
    _districtController.dispose();
    _stateController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.addressId != null ? "Edit Address" : "Add Address"),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CONTACT DETAILS ---
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

              // --- ADDRESS DETAILS ---
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

              // PIN CODE
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (val) {
                  if (val.length == 6) _fetchPinDetails(val);
                },
                validator: (val) =>
                    (val == null || val.length != 6) ? "Invalid PIN" : null,
                decoration: InputDecoration(
                  labelText: "PIN Code *",
                  prefixIcon: const Icon(Icons.pin_drop, color: Color(0xFF0D9759)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  counterText: "",
                  suffixIcon: _isFetchingPin
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                ),
              ),
              const SizedBox(height: 15),

              // SERVICE AREA DROPDOWN
              DropdownButtonFormField<String>(
                value: _selectedArea,
                decoration: InputDecoration(
                  labelText: "Service Area *",
                  prefixIcon: const Icon(Icons.location_city, color: Color(0xFF0D9759)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _availableAreas.map((area) {
                  return DropdownMenuItem(value: area, child: Text(area));
                }).toList(),
                onChanged: _availableAreas.isEmpty
                    ? null
                    : (val) {
                        setState(() => _selectedArea = val);
                      },
                validator: (val) => val == null ? "Please select service area" : null,
                hint: Text(_availableAreas.isEmpty
                    ? "Enter pincode first"
                    : "Select service area"),
              ),
              const SizedBox(height: 15),

              // DISTRICT & STATE (Auto-filled, read-only)
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
                    backgroundColor: const Color(0xFF0D9759),
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
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
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
        prefixIcon: Icon(icon, color: const Color(0xFF0D9759)),
        filled: isReadOnly,
        counterText: "",
        fillColor: isReadOnly ? Colors.grey[200] : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
