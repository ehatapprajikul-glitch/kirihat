import 'package:flutter/material.dart';

class VendorSidebar extends StatelessWidget {
  final String selectedPage;
  final Function(String) onPageSelected;

  const VendorSidebar({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF1E293B), // Dark blue-gray like Admin
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
                    color: Colors.deepOrange, // Vendor Brand Color
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 24),
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
                      'Vendor Panel',
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
                  page: 'home',
                ),
                
                _buildSectionHeader('Inventory'),
                _buildNavItem(
                  icon: Icons.grid_view,
                  label: 'Catalog Selection',
                  page: 'catalog_selection',
                ),
                _buildNavItem(
                  icon: Icons.inventory_2,
                  label: 'Product Catalog',
                  page: 'products',
                ),
                _buildNavItem(
                  icon: Icons.receipt_long,
                  label: 'Orders',
                  page: 'orders',
                ),
                
                _buildSectionHeader('Business'),
                _buildNavItem(
                  icon: Icons.account_balance_wallet,
                  label: 'Earnings',
                  page: 'earnings',
                ),
                 _buildNavItem(
                  icon: Icons.analytics,
                  label: 'Analytics',
                  page: 'analytics',
                ),
                
                _buildSectionHeader('Management'),
                _buildNavItem(
                  icon: Icons.moped,
                  label: 'Riders',
                  page: 'riders',
                ),
                _buildNavItem(
                  icon: Icons.person,
                  label: 'My Profile',
                  page: 'profile',
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
          color: isSelected ? Colors.deepOrange.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.deepOrange : Colors.transparent,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.deepOrange : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.deepOrange : Colors.white70,
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
