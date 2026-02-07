import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'seller_sidebar.dart';
import 'products/seller_products_screen.dart';
import 'area/seller_area_screen.dart';
import 'inventory/enhanced_seller_inventory_screen.dart';
import 'shipments/seller_shipments_screen.dart';
import 'analytics/enhanced_seller_analytics_screen.dart';
import 'analytics/seller_analytics_screen.dart';
import 'analytics/product_transactions_screen.dart';
import 'billing/seller_billing_screen.dart';
import 'profile/seller_profile_screen.dart';
import '../auth/seller_registration_screen.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  final _sellerService = SellerService();
  SellerModel? _seller;
  bool _isLoading = true;
  String _currentPage = 'products'; // Default page

  @override
  void initState() {
    super.initState();
    _loadSellerData();
  }

  Future<void> _loadSellerData() async {
    setState(() => _isLoading = true);
    
    try {
      final seller = await _sellerService.getCurrentSeller();
      setState(() {
        _seller = seller;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading seller data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onPageChange(String page) {
    setState(() => _currentPage = page);
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 'products':
        return SellerProductsScreen(seller: _seller!);
      case 'area':
        return SellerAreaScreen(seller: _seller!);
      case 'inventory':
        return EnhancedSellerInventoryScreen(seller: _seller!);
      case 'shipments':
        return SellerShipmentsScreen(seller: _seller!);
      case 'sells':
        return EnhancedSellerAnalyticsScreen(seller: _seller!);
      case 'product_transactions':
        return EnhancedProductTransactionsScreen(seller: _seller!);
      case 'billing':
        return SellerBillingScreen(seller: _seller!);
      case 'profile':
        return SellerProfileScreen(seller: _seller!);
      default:
        return SellerProductsScreen(seller: _seller!);
    }
  }

  Widget _buildComingSoon(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 80, color: Color(0xFF0D9759)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Coming Soon', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0D9759)),
        ),
      );
    }

    if (_seller == null) {
      // HANDLE MISSING SELLER PROFILE (Manual Role Change Case)
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront, size: 60, color: Color(0xFF0D9759)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Complete Your Seller Profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'You have seller access, but your business details are missing.\nPlease complete the registration to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SellerRegistrationScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Complete Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Logout', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      );
    }

    // Check seller status
    if (_seller!.status == 'pending') {
      return _buildPendingApprovalScreen();
    }

    if (_seller!.status == 'rejected') {
      return _buildRejectedScreen();
    }

    if (_seller!.status == 'suspended') {
      return _buildSuspendedScreen();
    }

    // Show dashboard for active sellers
    return LayoutBuilder(
      builder: (context, constraints) {
        // Web layout (desktop)
        if (constraints.maxWidth > 800) {
          return _buildWebLayout();
        }
        // Mobile layout
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // Sidebar
          SellerSidebar(
            currentPage: _currentPage,
            onPageChange: _onPageChange,
            seller: _seller!,
          ),
          // Main content
          Expanded(
            child: _buildCurrentPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: SellerSidebar(
          currentPage: _currentPage,
          onPageChange: (page) {
            _onPageChange(page);
            Navigator.pop(context); // Close drawer
          },
          seller: _seller!,
        ),
      ),
      body: _buildCurrentPage(),
    );
  }


  String _getPageTitle() {
    switch (_currentPage) {
      case 'products': return 'Products';
      case 'area': return 'My Area';
      case 'inventory': return 'Inventory';
      case 'shipments': return 'Shipments';
      case 'sells': return 'Sales';
      case 'billing': return 'Billing';
      case 'profile': return 'Profile';
      default: return 'Dashboard';
    }
  }

  Widget _buildPendingApprovalScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pending,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pending Approval',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Your seller account is under review',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What happens next?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('1. Admin reviews your documents'),
                    _buildInfoRow('2. Verification process (1-2 days)'),
                    _buildInfoRow('3. You\'ll receive notification once approved'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, size: 100, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Application Rejected',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Unfortunately, your seller application was not approved',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuspendedScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pause_circle, size: 100, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                'Account Suspended',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your seller account has been temporarily suspended',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF0D9759)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
