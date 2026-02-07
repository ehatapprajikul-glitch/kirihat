import 'package:flutter/material.dart';
import 'admin_sidebar.dart';
import 'admin_header.dart';
import 'dashboard/main_dashboard.dart';
import 'users/user_management.dart';
import 'dashboard/customer_monitor.dart';
import 'dashboard/vendor_monitor.dart';
import 'dashboard/rider_monitor.dart';
import 'coupons/coupon_management.dart';
import 'fees/vendor_fee_settings.dart'; 
import 'commission/commission_settings.dart';
import 'notifications/notification_composer.dart';
import 'support/customer_support.dart';
import 'monitoring/data_monitoring.dart';
import 'analytics/analytics_reports.dart';
import 'analytics/search_analytics_screen.dart';
import 'settings/platform_settings.dart';
import 'settings/product_display_settings.dart';
import 'settings/fee_configuration_screen.dart';
import 'catalog/master_products_screen.dart';
import 'catalog/product_requests_screen.dart';
import 'catalog/category_management_screen.dart';
import 'catalog/hero_category_management.dart';
import 'catalog/hero_banner_management.dart';
import 'catalog/subcategory_management.dart';
import 'catalog/hierarchical_category_management.dart';
import 'catalog/unified_collection_management.dart';
import 'riders/rider_requests_screen.dart';
import 'sellers/seller_management_screen.dart';
import 'logistics/incoming_shipments_screen.dart';
import 'warehouse/warehouse_dashboard.dart';
import 'warehouse/warehouse_inventory_screen.dart';
import 'warehouse/receive_shipments_screen.dart';
import 'warehouse/warehouse_setup_screen.dart'; // New Import
import 'warehouse/vendor_requests_management_screen.dart';
import 'catalog/category_specification_manager.dart';
import 'catalog/price_override_requests_screen.dart';
import 'setup/system_initialization_screen.dart';
import 'layout_manager/home_layout_manager_screen.dart';
import 'account_deletions_screen.dart';

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
      case 'seller_monitor':
        return const SellerManagementScreen();
      case 'rider_monitor':
        return const RiderMonitor();
      case 'coupons':
        return const CouponManagement();
      case 'vendor_fees':
        return const VendorFeeSettings();
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
      case 'fee_configuration':
        return const FeeConfigurationScreen();
      case 'product_display_settings':
        return const ProductDisplaySettings();
      case 'master_products':
        return const MasterProductsScreen();
      case 'product_requests':
        return const ProductRequestsScreen();
      case 'hero_categories':
        return const HeroCategoryManagementScreen();
      case 'hero_banners':
        return const HeroBannerManagementScreen();
      case 'unified_collections':
        return const UnifiedCollectionManagementScreen();
      case 'categories':
        return const CategoryManagementScreen();
      case 'subcategories':
        return const SubcategoryManagementScreen();
      case 'hierarchical_categories':
        return const HierarchicalCategoryManagement();
      case 'rider_requests':
        return const RiderRequestsScreen();
      case 'incoming_shipments':
        return const IncomingShipmentsScreen();
      case 'warehouse_dashboard':
        return WarehouseDashboard(onNavigate: (page) => setState(() => _selectedPage = page));
      case 'warehouse_setup':
         return const WarehouseSetupScreen();
      case 'warehouse_inventory':
        return const WarehouseInventoryScreen();
      case 'receive_shipments':
        return const ReceiveShipmentsScreen();
      case 'vendor_requests':
        return const VendorRequestsManagementScreen();
      case 'category_specifications':
        return const CategorySpecificationManager();
      case 'price_overrides':
        return const PriceOverrideRequestsScreen();
      case 'system_setup':
        return const SystemInitializationScreen();
      case 'home_layouts':
        return const HomeLayoutManagerScreen();
      case 'account_deletions':
        return const AccountDeletionsScreen();
      case 'search_analytics':
        return const SearchAnalyticsScreen();
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
