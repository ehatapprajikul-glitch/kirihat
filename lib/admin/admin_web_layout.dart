import 'package:flutter/material.dart';
import 'admin_sidebar.dart';
import 'admin_header.dart';
import 'dashboard/main_dashboard.dart';
import 'users/user_management.dart';
import 'dashboard/customer_monitor.dart';
import 'dashboard/vendor_monitor.dart';
import 'dashboard/rider_monitor.dart';
import 'coupons/coupon_management.dart';
import 'commission/commission_settings.dart';
import 'notifications/notification_composer.dart';
import 'support/customer_support.dart';
import 'monitoring/data_monitoring.dart';
import 'analytics/analytics_reports.dart';
import 'settings/platform_settings.dart';
import 'catalog/master_products_screen.dart';
import 'catalog/product_requests_screen.dart';
import 'catalog/product_requests_screen.dart';
import 'catalog/category_management_screen.dart';
import 'catalog/hero_category_management.dart';
import 'catalog/subcategory_management.dart';
import 'riders/rider_requests_screen.dart';

class AdminWebLayout extends StatefulWidget {
  const AdminWebLayout({super.key});

  @override
  State<AdminWebLayout> createState() => _AdminWebLayoutState();
}

class _AdminWebLayoutState extends State<AdminWebLayout> {
  String _selectedPage = 'dashboard';
  
  void _navigateTo(String page) {
    setState(() {
      _selectedPage = page;
    });
  }

  Widget _buildPageContent() {
    switch (_selectedPage) {
      case 'dashboard':
        return MainDashboard(onNavigate: (page) {
          setState(() => _selectedPage = page);
        });
      case 'users':
        return const UserManagement();
      case 'customer_monitor':
        return const CustomerMonitor();
      case 'vendor_monitor':
        return const VendorMonitor();
      case 'rider_monitor':
        return const RiderMonitor();
      case 'coupons':
        return const CouponManagement();
      case 'commission':
        return const CommissionSettings();
      case 'notifications':
        return const NotificationComposer();
      case 'support':
        return const CustomerSupport();
      case 'data_monitoring':
        return const DataMonitoring();
      case 'analytics':
        return const AnalyticsReports();
      case 'settings':
        return const PlatformSettings();
      case 'master_products':
        return const MasterProductsScreen();
      case 'product_requests':
        return const ProductRequestsScreen();
      case 'hero_categories':
        return const HeroCategoryManagementScreen();
      case 'categories':
        return const CategoryManagementScreen();
      case 'subcategories':
        return const SubcategoryManagementScreen();
      case 'rider_requests':
        return const RiderRequestsScreen();
      default:
        return const Center(child: Text('Page Not Found'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          AdminSidebar(
            selectedPage: _selectedPage,
            onPageSelected: _navigateTo,
          ),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Header
                AdminHeader(
                  currentPage: _selectedPage,
                  onNavigate: (page) {
                    setState(() => _selectedPage = page);
                  },
                ),
                
                // Page Content
                Expanded(
                  child: Container(
                    color: Colors.grey[100],
                    padding: const EdgeInsets.all(24),
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
