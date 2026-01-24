import 'package:flutter/material.dart';

import '../auth/login_screen.dart';

class PortalLandingScreen extends StatelessWidget {
  const PortalLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive Check
          bool isMobile = constraints.maxWidth < 800;

          return SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Header
                  const Icon(Icons.storefront, size: 64, color: Color(0xFF0D9759)),
                  const SizedBox(height: 16),
                  Text(
                    'Kiri Hat Portal',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select your role to continue',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 64),

                  // Role Cards
                  Wrap(
                    spacing: 32,
                    runSpacing: 32,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildRoleCard(
                        context,
                        title: 'Admin',
                        description: 'Manage the entire platform, users, and settings.',
                        icon: Icons.admin_panel_settings,
                        color: Colors.purple,
                        onTap: () => _navigateToLogin(context, 'admin'),
                        isMobile: isMobile,
                      ),
                      _buildRoleCard(
                        context,
                        title: 'Vendor',
                        description: 'Manage your shop, products, and incoming orders.',
                        icon: Icons.store,
                        color: Colors.blue,
                        onTap: () => _navigateToLogin(context, 'vendor'),
                        isMobile: isMobile,
                      ),
                      _buildRoleCard(
                        context,
                        title: 'Seller',
                        description: 'Sell your individual items and manage shipments.',
                        icon: Icons.local_shipping,
                        color: const Color(0xFF0D9759),
                        onTap: () => _navigateToLogin(context, 'seller'),
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 64),
                  Text(
                    '© 2024 Kiri Hat. All rights reserved.',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 300,
      constraints: const BoxConstraints(maxWidth: 340),
      child: Card(
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Login as $title',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context, String role) {
    // For now, we direct everyone to the same login screen since 
    // authentication is unified. We can pass the intended role if needed
    // for UI customization later, but the backend dictates the actual role.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}
