import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import '../widgets/floating_cart_button.dart';
import '../onboarding/change_location_screen.dart';
import '../cart_screen.dart';
import '../widgets/draggable_cart_wrapper.dart';
import '../widgets/customer_header.dart';
import 'widgets/layout_renderer.dart';
import 'widgets/enhanced_home_layout_service.dart';

/// Enhanced Customer Home Screen with better error handling, caching, and UX
class EnhancedCustomerHomeScreen extends StatefulWidget {
  const EnhancedCustomerHomeScreen({super.key});

  @override
  State<EnhancedCustomerHomeScreen> createState() => _EnhancedCustomerHomeScreenState();
}

class _EnhancedCustomerHomeScreenState extends State<EnhancedCustomerHomeScreen>
    with AutomaticKeepAliveClientMixin {
  final EnhancedHomeLayoutService _layoutService = EnhancedHomeLayoutService();
  
  String? _vendorId;
  String? _selectedArea;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? vendorId = prefs.getString('assigned_vendor_id');
      String? area = prefs.getString('current_area');

      // If no local session, try loading from Firestore
      if (vendorId == null) {
        debugPrint('📡 No local session, checking Firestore...');
        final user = FirebaseAuth.instance.currentUser;
        
        if (user != null) {
          final sessionService = SessionService();
          final restored = await sessionService.loadSessionFromFirestore(user.uid)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  debugPrint('⏰ Session restore timeout');
                  return false;
                },
              );
          
          if (restored) {
            vendorId = prefs.getString('assigned_vendor_id');
            area = prefs.getString('current_area');
            debugPrint('✅ Session restored from cloud!');
          }
        }
      }

      if (mounted) {
        setState(() {
          _vendorId = vendorId;
          _selectedArea = area ?? 'Your Area';
          _isLoading = false;
        });
      }

      if (vendorId != null) {
        debugPrint('✅ Vendor ID loaded: $vendorId');
      } else {
        debugPrint('❌ No vendor found - showing location prompt');
      }
    } catch (e) {
      debugPrint('❌ Error loading home data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load session data';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // For AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: Colors.white,
      body: DraggableCartWrapper(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              CustomerHeader(
                selectedArea: _selectedArea ?? 'Select Location',
                onLocationTap: _handleLocationTap,
                onCartTap: _handleCartTap,
              ),
              
              // Content
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _vendorId != null ? const FloatingCartButton() : null,
    );
  }

  Widget _buildContent() {
    // Loading state
    if (_isLoading) {
      return _buildLoadingState();
    }

    // Error state
    if (_hasError) {
      return _buildErrorState();
    }

    // No vendor selected
    if (_vendorId == null) {
      return _buildLocationPrompt();
    }

    // Main content with layouts
    return StreamBuilder<List<LayoutModel>>(
      stream: _layoutService.getMergedLayouts(_vendorId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          debugPrint('❌ Error loading layouts: ${snapshot.error}');
          return _buildLayoutErrorState(snapshot.error.toString());
        }

        final layouts = snapshot.data ?? [];

        if (layouts.isEmpty) {
          return _buildEmptyLayoutState();
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF0D9759),
          child: ListView.builder(
            itemCount: layouts.length,
            itemBuilder: (context, index) {
              return EnhancedLayoutRenderer(
                layout: layouts[index],
                vendorId: _vendorId!,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF0D9759),
          ),
          SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Your Location',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Choose your delivery area to see available products and start shopping',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _handleLocationTap,
              icon: const Icon(Icons.location_on),
              label: const Text('Choose Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Failed to load home screen',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 60,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Content Unavailable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load home screen content',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
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
            Icon(
              Icons.dashboard_customize_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Home Layout Not Configured',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The admin hasn\'t set up the home screen layout yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D9759),
                side: const BorderSide(color: Color(0xFF0D9759)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLocationTap() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChangeLocationScreen()),
      );
      
      if (result == true || result == null) {
        // Location was changed or screen was dismissed
        await _loadData();
      }
    } catch (e) {
      debugPrint('❌ Location selection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to change location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleCartTap() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } catch (e) {
      debugPrint('❌ Cart navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to open cart'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRefresh() async {
    // Clear cache before refresh
    _layoutService.clearVendorCache(_vendorId!);
    await _loadData();
  }

  @override
  void dispose() {
    _layoutService.dispose();
    super.dispose();
  }
}