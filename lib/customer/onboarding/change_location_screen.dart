import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/service_area_service.dart';
import 'area_selection_screen.dart';

class ChangeLocationScreen extends StatefulWidget {
  const ChangeLocationScreen({super.key});

  @override
  State<ChangeLocationScreen> createState() => _ChangeLocationScreenState();
}

class _ChangeLocationScreenState extends State<ChangeLocationScreen> {
  final TextEditingController _pincodeController = TextEditingController();
  final ServiceAreaService _serviceAreaService = ServiceAreaService();
  bool _isLoading = false;
  String? _currentPincode;
  String? _currentArea;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentPincode = prefs.getString('pincode');
        _currentArea = prefs.getString('area');
        if (_currentPincode != null) {
          _pincodeController.text = _currentPincode!;
        }
      });
    } catch (e) {
      debugPrint('Error loading current location: $e');
    }
  }

  Future<void> _searchPincode() async {
    final pincode = _pincodeController.text.trim();
    
    if (pincode.isEmpty || pincode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit pincode'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First, get city/state info from India Post API
      final response = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      );

      String city = '';
      String state = '';

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data[0]['Status'] == 'Success') {
          final postOffices = data[0]['PostOffice'] as List;
          
          if (postOffices.isNotEmpty) {
            city = postOffices[0]['District'];
            state = postOffices[0]['State'];
          }
        }
      }

      // Query service_areas to find service areas for this pincode
      final serviceAreas = await _serviceAreaService.getServiceAreasForPincode(pincode);

      if (serviceAreas.isEmpty) {
        _showError('No service available in this area yet. Try another pincode.');
        setState(() => _isLoading = false);
        return;
      }

      // Extract unique area names from all zones
      Set<String> uniqueAreas = {};
      for (var zone in serviceAreas) {
        if (zone['areas'] != null) {
          uniqueAreas.addAll(List<String>.from(zone['areas']));
        }
      }

      final areas = uniqueAreas.toList()..sort();

      if (areas.isEmpty) {
        _showError('No service areas found for this pincode.');
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AreaSelectionScreen(
              pincode: pincode,
              areas: areas,
              city: city.isNotEmpty ? city : 'Your City',
              state: state.isNotEmpty ? state : 'Your State',
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Change Delivery Area'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Location
            if (_currentArea != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF0D9759)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Location',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentArea!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'PIN: $_currentPincode',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Title
            const Text(
              'Enter New Pincode',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We\'ll find vendors that deliver to your area',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Pincode Input
            TextField(
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Pincode',
                hintText: 'Enter 6-digit pincode',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0D9759), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Search Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _searchPincode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Search Areas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }
}
