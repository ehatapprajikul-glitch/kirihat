import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'cart_screen.dart';
import 'product_detail.dart';
import 'address_screen.dart';
// import 'category_products.dart'; // REMOVED to prevent error if file is missing

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  // State
  String? _nearestVendorId;
  String _locationLabel = "Locating...";
  GeoPoint? _targetLocation;
  bool _isLoading = true;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Banner
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  final List<String> _bannerImages = [
    "https://img.freepik.com/free-vector/flat-supermarket-social-media-cover-template_23-2149358913.jpg",
    "https://img.freepik.com/free-vector/flat-horizontal-banner-template-supermarket_23-2149364734.jpg",
    "https://img.freepik.com/free-vector/flat-supermarket-twitch-banner_23-2149358915.jpg",
  ];

  @override
  void initState() {
    super.initState();
    _startBannerTimer();
    _initializeSessionLocation();
  }

  // --- 1. LOCATION LOGIC (Dark Store) ---
  Future<void> _initializeSessionLocation() async {
    setState(() => _isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check Session (Fastest)
    if (prefs.containsKey('current_lat') && prefs.containsKey('current_lng')) {
      double lat = prefs.getDouble('current_lat')!;
      double lng = prefs.getDouble('current_lng')!;
      String label = prefs.getString('current_address') ?? "Current Location";
      await _updateTargetLocation(GeoPoint(lat, lng), label);
      return;
    }

    // Check Saved Profile (Firestore)
    User? user = FirebaseAuth.instance.currentUser;
    bool locationFound = false;
    if (user != null) {
      try {
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data()!.containsKey('current_address')) {
          var addr = userDoc['current_address'];
          if (addr.containsKey('location')) {
            GeoPoint p = addr['location'];
            await _updateTargetLocation(p, addr['landmark'] ?? "Saved Address");
            locationFound = true;
          }
        }
      } catch (e) {
        debugPrint("Error: $e");
      }
    }

    if (!locationFound) await _detectGPSLocation();
  }

  // --- FIXED GPS LOGIC (Matches Address Screen) ---
  Future<void> _detectGPSLocation() async {
    try {
      // 1. Check Service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationLabel = "GPS Disabled";
          _isLoading = false;
        });
        return;
      }

      // 2. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationLabel = "Loc: Denied";
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationLabel = "Loc: Permanently Denied";
          _isLoading = false;
        });
        return;
      }

      // 3. Get Position (Robust Settings)
      LocationSettings locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );

      Position pos = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);

      // 4. Get Address Label
      List<Placemark> placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String label = placemarks.isNotEmpty
          ? "${placemarks[0].subLocality}, ${placemarks[0].locality}"
          : "Current Location";

      _updateTargetLocation(GeoPoint(pos.latitude, pos.longitude), label);
    } catch (e) {
      debugPrint("GPS Error: $e");
      if (mounted) {
        setState(() {
          _locationLabel = "GPS Error";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateTargetLocation(GeoPoint location, String label) async {
    if (!mounted) return;
    setState(() {
      _targetLocation = location;
      _locationLabel = label;
      _isLoading = true;
    });

    try {
      var snapshot =
          await FirebaseFirestore.instance.collection('vendors').get();
      String? closestId;
      double minDistance = 15000; // 15km Radius

      for (var doc in snapshot.docs) {
        if (doc.data().containsKey('location')) {
          GeoPoint vLoc = doc['location'];
          double dist = Geolocator.distanceBetween(location.latitude,
                  location.longitude, vLoc.latitude, vLoc.longitude) /
              1000;

          if (dist <= 15.0 && dist < minDistance) {
            minDistance = dist;
            closestId = doc.id;
          }
        }
      }
      if (mounted) {
        setState(() {
          _nearestVendorId = closestId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. DYNAMIC WIDGET BUILDER ---
  Widget _buildDynamicSection(Map<String, dynamic> layoutData) {
    String type = layoutData['type'] ?? 'unknown';
    String title = layoutData['title'] ?? '';
    String filter = layoutData['category_filter'] ?? 'All';

    switch (type) {
      case 'banner':
        return _BannerSection(
            images: _bannerImages, controller: _bannerController);
      case 'category_row':
        return _CategoryRow(title: title);
      case 'product_row':
        return _ProductListSection(
            vendorId: _nearestVendorId!,
            title: title,
            categoryFilter: filter,
            isHorizontal: true);
      case 'product_grid':
        return _ProductListSection(
            vendorId: _nearestVendorId!,
            title: title,
            categoryFilter: filter,
            isHorizontal: false);
      default:
        return const SizedBox.shrink();
    }
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentBannerIndex < _bannerImages.length - 1) {
        _currentBannerIndex++;
      } else {
        _currentBannerIndex = 0;
      }
      if (_bannerController.hasClients) {
        _bannerController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // APP BAR
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: Colors.deepPurple,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DELIVERING TO",
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold)),
                  Text(_locationLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CartScreen())),
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: "Search milk, bread, eggs...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // CONTENT
            if (_isLoading)
              const SliverToBoxAdapter(
                  child: SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator())))
            else if (_nearestVendorId == null)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child: Text("Service not available in this area yet.",
                          textAlign: TextAlign.center)),
                ),
              )
            else
              // DYNAMIC LAYOUT BUILDER
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('home_layout')
                    .orderBy('position')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const SliverToBoxAdapter(child: SizedBox.shrink());

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        var data = snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                        return _buildDynamicSection(data);
                      },
                      childCount: snapshot.data!.docs.length,
                    ),
                  );
                },
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        ),
      ),
    );
  }
}

// --- SUB WIDGETS ---

class _BannerSection extends StatelessWidget {
  final List<String> images;
  final PageController controller;

  const _BannerSection({required this.images, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: PageView.builder(
        controller: controller,
        itemCount: images.length,
        itemBuilder: (ctx, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                  image: NetworkImage(images[index]), fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String title;
  const _CategoryRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        SizedBox(
          height: 100,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .orderBy('sort_order')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              if (docs.isEmpty) return const SizedBox.shrink();

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: docs.length,
                itemBuilder: (ctx, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () {
                      // Navigate to Category Products (Implement when file created)
                    },
                    child: Container(
                      width: 75,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.grey.shade200, blurRadius: 4)
                              ],
                              image: data['imageUrl'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(data['imageUrl']),
                                      fit: BoxFit.cover)
                                  : null,
                            ),
                            child: data['imageUrl'] == null
                                ? const Icon(Icons.category,
                                    color: Colors.green)
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(data['name'] ?? "",
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}

class _ProductListSection extends StatelessWidget {
  final String vendorId;
  final String title;
  final String categoryFilter;
  final bool isHorizontal;

  const _ProductListSection(
      {required this.vendorId,
      required this.title,
      required this.categoryFilter,
      required this.isHorizontal});

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('vendor_id', isEqualTo: vendorId)
        .where('isActive', isEqualTo: true);

    if (categoryFilter != "All") {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              if (isHorizontal)
                const Text("See All",
                    style: TextStyle(color: Colors.blue, fontSize: 12)),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: query.limit(isHorizontal ? 6 : 20).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            var docs = snapshot.data!.docs;

            if (docs.isEmpty) return const SizedBox.shrink();

            if (isHorizontal) {
              return SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 140,
                        child: _buildCard(context, docs[index]),
                      ),
                    );
                  },
                ),
              );
            } else {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) =>
                    _buildCard(context, docs[index]),
              );
            }
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCard(BuildContext context, DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ProductDetailScreen(productData: data, productId: doc.id)));
      },
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: data['imageUrl'] != null
                    ? Image.network(data['imageUrl'], fit: BoxFit.contain)
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name'] ?? 'Product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text("₹${data['price']}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text("ADD",
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 10)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
