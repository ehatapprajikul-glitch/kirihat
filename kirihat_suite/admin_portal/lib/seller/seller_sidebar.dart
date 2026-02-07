import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

class SellerSidebar extends StatelessWidget {
  final String currentPage;
  final Function(String) onPageChange;
  final SellerModel seller;

  const SellerSidebar({
    super.key,
    required this.currentPage,
    required this.onPageChange,
    required this.seller,
  });

  @override
  Widget build(BuildContext context) {
    final isDrawer = Scaffold.of(context).hasDrawer;
    
    return Container(
      width: isDrawer ? null : 260,
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D9759), Color(0xFF0A7A45)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.store, size: 36, color: Color(0xFF0D9759)),
                ),
                const SizedBox(height: 12),
                Text(
                  seller.businessName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  seller.ownerName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        seller.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  page: 'dashboard',
                  isActive: currentPage == 'dashboard',
                ),
                const Divider(height: 1),
                _buildSectionHeader('PRODUCT CATALOG'),
                _buildNavItem(
                  icon: Icons.inventory_2,
                  label: 'Products',
                  page: 'products',
                  isActive: currentPage == 'products',
                ),
                _buildNavItem(
                  icon: Icons.assessment,
                  label: 'Inventory',
                  page: 'inventory',
                  isActive: currentPage == 'inventory',
                ),
                _buildNavItem(
                  icon: Icons.local_shipping,
                  label: 'Shipments',
                  page: 'shipments',
                  isActive: currentPage == 'shipments',
                ),
                const Divider(height: 1),
                _buildSectionHeader('OPERATIONS'),
                _buildNavItem(
                  icon: Icons.location_on,
                  label: 'My Area',
                  page: 'area',
                  isActive: currentPage == 'area',
                ),
                _buildNavItem(
                  icon: Icons.trending_up,
                  label: 'Sells',
                  page: 'sells',
                  isActive: currentPage == 'sells',
                ),
                _buildNavItem(
                  icon: Icons.receipt_long,
                  label: 'Product Transactions',
                  page: 'product_transactions',
                  isActive: currentPage == 'product_transactions',
                ),
                const Divider(height: 1),
                _buildSectionHeader('FINANCE'),
                _buildNavItem(
                  icon: Icons.account_balance_wallet,
                  label: 'Billing',
                  page: 'billing',
                  isActive: currentPage == 'billing',
                ),
                const Divider(height: 1),
                _buildSectionHeader('ACCOUNT'),
                _buildNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  page: 'profile',
                  isActive: currentPage == 'profile',
                ),
              ],
            ),
          ),

          // Stats Summary (only on web)
          if (!isDrawer) _buildStatsCard(),

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9759),
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String page,
    required bool isActive,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive ? const Color(0xFF0D9759).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onPageChange(page),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isActive ? const Color(0xFF0D9759) : Colors.grey[700],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive ? const Color(0xFF0D9759) : Colors.grey[800],
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9759),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D9759).withOpacity(0.1),
            const Color(0xFF0A7A45).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D9759).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D9759),
            ),
          ),
          const SizedBox(height: 12),
          _buildStatRow('Products', '${seller.totalProducts}'),
          _buildStatRow('Active', '${seller.activeProducts}'),
          _buildStatRow('Sales', CurrencyHelper.format(seller.totalSales)),
          _buildStatRow('Rating', '${seller.rating.toStringAsFixed(1)} ⭐'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D9759),
            ),
          ),
        ],
      ),
    );
  }
}
