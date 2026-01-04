import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/hero_category_service.dart';
import '../../services/session_service.dart';
import '../category/category_products_screen.dart';
import '../widgets/floating_cart_button.dart';
import '../onboarding/change_location_screen.dart';
import '../cart_screen.dart';

class NewCustomerHomeScreen extends StatefulWidget {
  const NewCustomerHomeScreen({super.key});

  @override
  State<NewCustomerHomeScreen> createState() => _NewCustomerHomeScreenState();
}

class _NewCustomerHomeScreenState extends State<NewCustomerHomeScreen> {
  final HeroCategoryService _heroService = HeroCategoryService();
  
  String? _vendorId;
  String? _selectedArea;
  List<Map<String, dynamic>> _heroCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? vendorId = prefs.getString('assigned_vendor_id');
      String? area = prefs.getString('current_area');
      String? pincode = prefs.getString('current_pincode');

      print('🏠 Home Screen - Loading session...');
      print('   VendorId: $vendorId');
      print('   Area: $area');
      print('   Pincode: $pincode');

      // If no local session, try loading from Firestore
      if (vendorId == null) {
        print('📡 No local session, checking Firestore...');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final sessionService = SessionService();
          final restored = await sessionService.loadSessionFromFirestore(user.uid);
          
          if (restored) {
            // Reload from SharedPreferences after sync
            vendorId = prefs.getString('assigned_vendor_id');
            area = prefs.getString('current_area');
            pincode = prefs.getString('current_pincode');
            print('✅ Session restored from cloud!');
          }
        }
      }

      if (vendorId == null) {
        print('❌ No vendor found - showing location prompt');
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _vendorId = vendorId;
        _selectedArea = area ?? 'Your Area';
      });

      // Fetch hero categories
      final heroCategories = await _heroService.getVendorHeroCategories(vendorId);
      print('✅ Loaded ${heroCategories.length} hero categories');

      setState(() {
        _heroCategories = heroCategories;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading home data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Search Bar
            _buildSearchBar(),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _vendorId == null
                      ? _buildNoVendorView()
                      : _heroCategories.isEmpty
                          ? _buildEmptyView()
                          : _buildHeroCategoriesGrid(),
            ),
          ],
        ),
      ),
      floatingActionButton: const FloatingCartButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // App Icon/Logo Placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0D9759),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          
          // Location
          Expanded(
            child: GestureDetector(
              onTap: () async {
                // Navigate to location selection
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangeLocationScreen()),
                );
                // Reload data after returning
                _loadData();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _selectedArea ?? 'Select Location',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                    ],
                  ),
                  const Text(
                    'Delivery in 20 minutes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Cart Icon
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search bar',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                // TODO: Navigate to search screen
              },
              readOnly: true,
            ),
          ),
          const Icon(Icons.mic, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildHeroCategoriesGrid() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _heroCategories.length,
      itemBuilder: (context, index) {
        final heroCategory = _heroCategories[index];
        return _buildHeroCategorySection(heroCategory);
      },
    );
  }

  Widget _buildHeroCategorySection(Map<String, dynamic> heroCategory) {
    final String name = heroCategory['name'] ?? 'Unnamed';
    final List<String> categoryIds = List<String>.from(heroCategory['category_ids'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Category Title
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Categories Grid
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _heroService.getCategoriesWithInventory(
            vendorId: _vendorId!,
            categoryIds: categoryIds,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final categories = snapshot.data!;

            if (categories.isEmpty) {
              return const SizedBox.shrink();
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryCard(categories[index]);
              },
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final String name = category['name'] ?? 'Unnamed';
    final String? iconUrl = category['icon'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewCategoryProductsScreen(
              categoryName: name,
              vendorId: _vendorId!,
            ),
          ),
        );
      },
      child: Column(
        children: [
          // Image Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                image: iconUrl != null && iconUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(iconUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: iconUrl == null || iconUrl.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.category,
                        size: 40,
                        color: Colors.grey,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          // Category Name
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVendorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No vendor available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please select your delivery area',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              // Navigate to location selection
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangeLocationScreen()),
              );
              // Reload data after returning
              _loadData();
            },
            icon: const Icon(Icons.location_on),
            label: const Text('Select Area'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9759),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No categories available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'The vendor hasn\'t set up their catalog yet',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
