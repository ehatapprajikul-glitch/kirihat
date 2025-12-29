import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_home.dart';
import 'address_screen.dart'; // For manual entry if GPS fails
import 'customer_dashboard.dart';

class LocationGate extends StatefulWidget {
  const LocationGate({super.key});

  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate> {
  bool _isChecking = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingLocation();
  }

  // --- 1. CHECK IF WE ALREADY KNOW THE LOCATION ---
  Future<void> _checkExistingLocation() async {
    // A. Check SharedPreferences (Local Cache)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('current_lat') && prefs.containsKey('current_lng')) {
      _navigateToHome();
      return;
    }

    // B. Check Firestore (If User is Logged In)
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('current_address')) {
        // We found a saved address! Save to Prefs and Go.
        var addr = doc.data()!['current_address'];
        if (addr['location'] != null) {
          GeoPoint p = addr['location'];
          await prefs.setDouble('current_lat', p.latitude);
          await prefs.setDouble('current_lng', p.longitude);
          await prefs.setString('current_address', addr['landmark'] ?? "Home");
          _navigateToHome();
          return;
        }
      }
    }

    // C. If nothing found, stop checking and show the "Gate" UI
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  // --- 2. THE ACTION: DETECT LOCATION ---
  Future<void> _detectLocation() async {
    setState(() => _isLoading = true);
    try {
      // Check Service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        throw "Enable GPS and try again.";
      }

      // Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Permission denied.";
      }
      if (permission == LocationPermission.deniedForever) {
        throw "Location denied forever. Check settings.";
      }

      // Get Position
      // Using generic settings for compatibility
      Position position = await Geolocator.getCurrentPosition();

      // Get Address Text
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      String label = "Current Location";
      if (placemarks.isNotEmpty) {
        label = "${placemarks[0].subLocality}, ${placemarks[0].locality}";
      }

      // SAVE TO SESSION (SharedPreferences)
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('current_lat', position.latitude);
      await prefs.setDouble('current_lng', position.longitude);
      await prefs.setString('current_address', label);

      _navigateToHome();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
        context,
        // CHANGE THIS: Go to Dashboard (with nav bar), not just Home Screen
        MaterialPageRoute(builder: (_) => const CustomerDashboard()));
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading State (Checking previous session)
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. The "Gate" UI
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.deepPurple.shade50, Colors.white])),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on_outlined,
                size: 80, color: Colors.deepPurple),
            const SizedBox(height: 30),
            const Text(
              "Where should we deliver?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "To show you the correct products and prices, we need to know your location first.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Detect Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _detectLocation,
                icon: const Icon(Icons.my_location),
                label:
                    Text(_isLoading ? "Locating..." : "Use Current Location"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 15),

            // Manual Entry Button
            TextButton(
              onPressed: () {
                // Navigate to Address Screen, but ensure it returns here or saves location
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddressScreen())).then((_) {
                  // When they come back from adding address, check again
                  setState(() => _isChecking = true);
                  _checkExistingLocation();
                });
              },
              child: const Text("Enter Location Manually",
                  style: TextStyle(color: Colors.deepPurple)),
            )
          ],
        ),
      ),
    );
  }
}
