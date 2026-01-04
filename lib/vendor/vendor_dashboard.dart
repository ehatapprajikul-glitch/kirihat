import 'package:flutter/material.dart';
// Import your screens
import 'vendor_home.dart';
import 'vendor_orders.dart';
import 'vendor_profile.dart';
import 'master_catalog_browser.dart';
import 'vendor_earnings.dart';
import 'vendor_sidebar.dart';
import 'vendor_header.dart';
import 'vendor_riders.dart';
import 'vendor_sales_analytics.dart';
import 'catalog_selection_screen.dart';

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
      case 'catalog_selection':
        return const VendorCatalogSelectionScreen();
      case 'products':
        return const MasterCatalogBrowser();
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
      body: Row(
        children: [
          // Sidebar
          VendorSidebar(
            selectedPage: _selectedPage,
            onPageSelected: _navigateTo,
          ),
          
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
    );
  }
}
