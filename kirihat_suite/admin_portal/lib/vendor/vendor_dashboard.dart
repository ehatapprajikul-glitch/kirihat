import 'package:flutter/material.dart';
import 'vendor_home.dart';
import 'order/vendor_orders.dart';
import 'vendor_profile.dart';
import 'master_catalog/master_catalog_screen.dart';
import 'Business/vendor_earnings.dart';
import 'vendor_sidebar.dart';
import 'vendor_header.dart';
import 'vendor_riders.dart';
import 'Business/vendor_sales_analytics.dart';
import 'stock/vendor_request_stock_screen.dart';
import 'stock/vendor_receive_stock_screen.dart';
import 'my_listed_products.dart';
import 'vendor_settlements.dart';
import 'vendor_location_setup.dart';
import 'vendor_zones.dart';
import 'vendor_qr_screen.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  String _selectedPage = 'home';

  Widget _buildPageContent() {
    switch (_selectedPage) {
      case 'home':
        return const VendorHomeScreen();
      case 'products':
        return const MasterCatalogScreen();
      case 'request_stock':
        return const VendorRequestStockScreen();
      case 'incoming_stock':
        return const VendorReceiveStockScreen();
      case 'orders':
        return const VendorOrdersScreen();
      case 'earnings':
        return const VendorEarningsScreen();
      case 'analytics':
        return const VendorSalesAnalytics();
      case 'riders':
        return const VendorRidersScreen();
      case 'profile':
        return const VendorProfileScreen();
      case 'my_products':
        return const MyListedProductsScreen();
      case 'settlements':
        return const VendorSettlementsScreen();
      case 'locations':
        return const VendorLocationSetup();
      case 'zones':
        return const VendorZonesScreen();
      case 'qr_checkin':
        return const VendorQRScreen();
      default:
        return const Center(child: Text("Page not found"));
    }
  }

  void _navigateTo(String page) {
    setState(() {
      _selectedPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          // 1. Content Layer (With placeholder for collapsed sidebar)
          Row(
            children: [
              // Placeholder for collapsed sidebar width
              const SizedBox(width: 70), 
              
              // Main Content
              Expanded(
                child: Column(
                  children: [
                    // Header
                    VendorHeader(
                      currentPage: _selectedPage,
                      onNavigate: _navigateTo,
                    ),
                    
                    // Content Area
                    Expanded(
                      child: ClipRect( 
                        // ClipRect ensures content doesn't bleed during transitions/scrolls
                        child: _buildPageContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. Sidebar Layer (Floating on top)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: VendorSidebar(
              selectedPage: _selectedPage,
              onPageSelected: _navigateTo,
            ),
          ),
        ],
      ),
    );
  }
}
