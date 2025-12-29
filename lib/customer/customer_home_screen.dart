import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'customer_product_list.dart'; // We will link this next

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  Position? _userPosition;
  String _locationStatus = "Locating...";

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // 1. Get Customer GPS (Robust Version)
  Future<void> _getUserLocation() async {
    setState(() => _locationStatus = "Checking location services...");
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationStatus = "Location services are disabled. Please enable GPS.");
        await Geolocator.openLocationSettings(); // Prompt user to enable
        return;
      }

      setState(() => _locationStatus = "Checking permissions...");
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        setState(() => _locationStatus = "Fetching location...");
        Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _userPosition = pos;
            _locationStatus = "Location Found";
          });
        }
      } else {
        setState(() => _locationStatus = "Location Permission Denied. Please enable in settings.");
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      setState(() => _locationStatus = "Error finding location: ${e.toString()}");
    }
  }

  // 2. Calculate Distance (Haversine Formula Wrapper)
  double _calculateDistance(GeoPoint vendorLoc) {
    if (_userPosition == null) return 9999; // Far away if unknown
    return Geolocator.distanceBetween(_userPosition!.latitude,
            _userPosition!.longitude, vendorLoc.latitude, vendorLoc.longitude) /
        1000; // Convert Meters to KM
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Order From Nearby", style: TextStyle(fontSize: 16, color: Colors.white)),
            Text("Select a shop to view products",
                style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor, // Use theme color
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.shopping_cart, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: _userPosition == null
          ? Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 15),
                Text(_locationStatus, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              ],
            ))
          : StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('vendors').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                var vendorDocs = snapshot.data!.docs;

                // 3. Sort Vendors by Distance
                vendorDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;

                  // Handle missing locations safely
                  if (!dataA.containsKey('location'))
                    return 1; // Push to bottom
                  if (!dataB.containsKey('location')) return -1;

                  double distA = _calculateDistance(dataA['location']);
                  double distB = _calculateDistance(dataB['location']);
                  return distA.compareTo(distB);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vendorDocs.length,
                  itemBuilder: (context, index) {
                    var data = vendorDocs[index].data() as Map<String, dynamic>;
                    String vendorId = vendorDocs[index].id;
                    String name =
                        data['business_name'] ?? data['name'] ?? "Unknown Shop";
                    String address = data['shop_address'] ?? "No address";
                    String image = data['imageUrl'] ??
                        ""; // Assuming you might add shop images later

                    // Distance Logic
                    String distanceDisplay = "N/A";
                    if (data.containsKey('location')) {
                      double km = _calculateDistance(data['location']);
                      distanceDisplay = "${km.toStringAsFixed(1)} km";
                    }

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () {
                          // 4. Navigate to Product List (Passing Vendor ID)
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CustomerProductListScreen(
                                      vendorId: vendorId, vendorName: name)));
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Shop Image Banner (Placeholder logic)
                            Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12)),
                                  image: image.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(image),
                                          fit: BoxFit.cover)
                                      : null),
                              child: image.isEmpty
                                  ? const Center(
                                      child: Icon(Icons.store,
                                          size: 50, color: Colors.grey))
                                  : null,
                            ),

                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            Border.all(color: Colors.green)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 14, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Text(distanceDisplay,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
