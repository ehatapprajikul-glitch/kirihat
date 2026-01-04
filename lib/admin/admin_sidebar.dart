import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final String selectedPage;
  final Function(String) onPageSelected;

  const AdminSidebar({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF1E293B), // Dark blue-gray
      child: Column(
        children: [
          // Logo/Brand
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9759),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kiri Hat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Admin Panel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white24, height: 1),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  page: 'dashboard',
                ),
                
                _buildSectionHeader('User Management'),
                _buildNavItem(
                  icon: Icons.people,
                  label: 'All Users',
                  page: 'users',
                ),
                
                _buildSectionHeader('Product Catalog'),
                _buildNavItem(
                  icon: Icons.inventory_2,
                  label: 'Master Products',
                  page: 'master_products',
                ),
                _buildNavItem(
                  icon: Icons.pending_actions,
                  label: 'Product Requests',
                  page: 'product_requests',
                ),
                _buildNavItem(
                  icon: Icons.grid_view,
                  label: 'Hero Categories',
                  page: 'hero_categories',
                ),
                _buildNavItem(
                  icon: Icons.category,
                  label: 'Categories',
                  page: 'categories',
                ),
                _buildNavItem(
                  icon: Icons.category_outlined,
                  label: 'Subcategories',
                  page: 'subcategories',
                ),
                
                _buildSectionHeader('App Control'),
                _buildNavItem(
                  icon: Icons.local_offer,
                  label: 'Discount Coupons',
                  page: 'coupons',
                ),
                _buildNavItem(
                  icon: Icons.attach_money,
                  label: 'Commission Settings',
                  page: 'commission',
                ),
                
                _buildSectionHeader('Communication'),
                _buildNavItem(
                  icon: Icons.notifications,
                  label: 'Push Notifications',
                  page: 'notifications',
                ),
                _buildNavItem(
                  icon: Icons.support_agent,
                  label: 'Customer Support',
                  page: 'support',
                ),
                
                _buildSectionHeader('Monitoring'),
                _buildNavItem(
                  icon: Icons.people,
                  label: 'Customer Monitor',
                  page: 'customer_monitor',
                ),
                _buildNavItem(
                  icon: Icons.store,
                  label: 'Vendor Monitor',
                  page: 'vendor_monitor',
                ),
                _buildNavItem(
                  icon: Icons.delivery_dining,
                  label: 'Rider Monitor',
                  page: 'rider_monitor',
                ),
                _buildNavItem(
                  icon: Icons.assignment_ind,
                  label: 'Rider Requests',
                  page: 'rider_requests',
                ),
                _buildNavItem(
                  icon: Icons.analytics,
                  label: 'Data Access',
                  page: 'data_monitoring',
                ),
                _buildNavItem(
                  icon: Icons.bar_chart,
                  label: 'Analytics & Reports',
                  page: 'analytics',
                ),
                
                _buildSectionHeader('Configuration'),
                _buildNavItem(
                  icon: Icons.settings,
                  label: 'Platform Settings',
                  page: 'settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String page,
  }) {
    bool isSelected = selectedPage == page;
    
    return InkWell(
      onTap: () => onPageSelected(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9759).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9759) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF0D9759) : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF0D9759) : Colors.white70,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
