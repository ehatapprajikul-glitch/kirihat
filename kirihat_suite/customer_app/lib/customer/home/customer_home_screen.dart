import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:kirihat_core/services/home_layout_service.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import '../widgets/floating_cart_button.dart';
import '../onboarding/change_location_screen.dart';
import '../cart_screen.dart';
import '../widgets/draggable_cart_wrapper.dart';
import '../widgets/customer_header.dart';
import 'widgets/layout_renderer.dart';

class NewCustomerHomeScreen extends StatefulWidget {
  const NewCustomerHomeScreen({super.key});

  @override
  State<NewCustomerHomeScreen> createState() => _NewCustomerHomeScreenState();
}

class _NewCustomerHomeScreenState extends State<NewCustomerHomeScreen> {
  final HomeLayoutService _layoutService = HomeLayoutService();
  
  String? _vendorId;
  String? _selectedArea;
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

      // If no local session, try loading from Firestore
      if (vendorId == null) {
        print('📡 No local session, checking Firestore...');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final sessionService = SessionService();
          final restored = await sessionService.loadSessionFromFirestore(user.uid);
          
          if (restored) {
            vendorId = prefs.getString('assigned_vendor_id');
            area = prefs.getString('current_area');
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
        _isLoading = false;
      });

      print('✅ Vendor ID loaded: $vendorId');
    } catch (e) {
      print('❌ Error loading home data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: DraggableCartWrapper(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              CustomerHeader(
                selectedArea: _selectedArea ?? 'Select Location',
                onLocationTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangeLocationScreen()),
                  );
                  _loadData();
                },
                onCartTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
              
              // Content
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: const FloatingCartButton(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_vendorId == null) {
      return _buildLocationPrompt();
    }

    // Dynamic layout from Firestore
    return StreamBuilder<List<LayoutModel>>(
      stream: _layoutService.getMergedLayouts(_vendorId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('❌ Error loading layouts: ${snapshot.error}');
          return _buildErrorState();
        }

        final layouts = snapshot.data ?? [];

        // If no layouts, show empty state
        if (layouts.isEmpty) {
          return _buildEmptyLayoutState();
        }

        // Render layouts dynamically
        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            itemCount: layouts.length,
            itemBuilder: (context, index) {
              return LayoutRenderer(
                layout: layouts[index],
                vendorId: _vendorId!,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLocationPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Your Location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your delivery area to see available products',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangeLocationScreen()),
                );
                _loadData();
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Choose Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load home screen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLayoutState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dashboard_customize_outlined,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Home layout not configured',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The admin hasn\'t set up the home screen layout yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
