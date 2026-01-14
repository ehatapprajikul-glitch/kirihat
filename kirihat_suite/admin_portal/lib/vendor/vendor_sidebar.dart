import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorSidebar extends StatefulWidget {
  final String selectedPage;
  final Function(String) onPageSelected;

  const VendorSidebar({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
  });

  @override
  State<VendorSidebar> createState() => _VendorSidebarState();
}

class _VendorSidebarState extends State<VendorSidebar> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  String? _hoveredItem;
  late AnimationController _expandController;
  late Animation<double> _widthAnimation;
  String? _currentUserId;
  
  // Collapsed width: 72, Expanded width: 280
  static const double _collapsedWidth = 72.0;
  static const double _expandedWidth = 280.0;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: _collapsedWidth,
      end: _expandedWidth,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand(bool expand) {
    setState(() => _isExpanded = expand);
    if (expand) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _toggleExpand(true),
      onExit: (_) {
        _toggleExpand(false);
        setState(() => _hoveredItem = null);
      },
      child: AnimatedBuilder(
        animation: _widthAnimation,
        builder: (context, child) {
          // Calculate opacity for text content based on width
          // Completely hide content until width is sufficient to prevent overflow (e.g. > 120px)
          final double contentOpacity = (_widthAnimation.value - 200) / (_expandedWidth - 200);
          final bool showContent = _widthAnimation.value > 200;

          return Container(
            width: _widthAnimation.value,
            clipBehavior: Clip.hardEdge, // Prevent overflow
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(showContent, contentOpacity.clamp(0.0, 1.0)),
                const Divider(color: Colors.white12, height: 1, thickness: 0.5),
                Expanded(child: _buildNavigationItems(showContent, contentOpacity.clamp(0.0, 1.0))),
                _buildFooter(showContent, contentOpacity.clamp(0.0, 1.0)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool showContent, double opacity) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showContent ? 20 : 0,
        vertical: 12,
      ),
      height: 80,
      child: Row(
        mainAxisAlignment: showContent ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          // Logo with glow effect
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.store_rounded, color: Colors.white, size: 24),
          ),
          
          // Brand Text
          if (showContent)
            Expanded(
              child: Opacity(
                opacity: opacity,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Kiri Hat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'VENDOR PANEL',
                          style: TextStyle(
                            color: Color(0xFFFFB380),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                          softWrap: false,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadgeCount(String collection, Query Function(CollectionReference) queryBuilder, Color color) {
    if (_currentUserId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: queryBuilder(FirebaseFirestore.instance.collection(collection)).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        
        // Ensure we're counting documents correctly
        final count = snapshot.data!.docs.length;
        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationItems(bool showContent, double opacity) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _buildNavItem(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          page: 'home',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        
        _buildSectionHeader('INVENTORY', showContent, opacity),
        
        _buildNavItem(
          icon: Icons.list_alt_rounded,
          label: 'My Product List',
          page: 'my_products',
          showContent: showContent,
          opacity: opacity,
          badgeWidget: _buildBadgeCount(
            'vendor_inventory', 
            (ref) => ref.where('vendor_id', isEqualTo: _currentUserId),
            Colors.deepOrange,
          ),
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.inventory_2_rounded,
          label: 'Product Catalog',
          page: 'products',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.add_shopping_cart_rounded,
          label: 'Request Stock',
          page: 'request_stock',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.local_shipping_rounded,
          label: 'Incoming Stock',
          page: 'incoming_stock',
          showContent: showContent,
          opacity: opacity,
          badgeWidget: _buildBadgeCount(
            'vendor_stock_requests',
            (ref) => ref.where('vendor_id', isEqualTo: _currentUserId).where('status', isEqualTo: 'shipped'),
            Colors.green,
          ),
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.receipt_long_rounded,
          label: 'Orders',
          page: 'orders',
          showContent: showContent,
          opacity: opacity,
          badgeWidget: _buildBadgeCount(
            'orders',
            (ref) => ref.where('vendor_id', isEqualTo: _currentUserId).where('status', whereIn: ['Pending', 'Processing']),
            Colors.blue,
          ),
          sidebarWidth: _widthAnimation.value,
        ),
        
        _buildSectionHeader('BUSINESS', showContent, opacity),

        _buildNavItem(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Earnings',
          page: 'earnings',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.analytics_rounded,
          label: 'Analytics',
          page: 'analytics',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        
        _buildSectionHeader('MANAGEMENT', showContent, opacity),

        _buildNavItem(
          icon: Icons.moped_rounded,
          label: 'Manage Riders',
          page: 'riders',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.qr_code_2_rounded,
          label: 'Rider Check-in QR',
          page: 'qr_checkin',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.payments_rounded,
          label: 'Rider Settlements',
          page: 'settlements',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.store_mall_directory_rounded,
          label: 'Shop Locations',
          page: 'locations',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.map_rounded,
          label: 'Delivery Zones',
          page: 'zones',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
        _buildNavItem(
          icon: Icons.person_rounded,
          label: 'My Profile',
          page: 'profile',
          showContent: showContent,
          opacity: opacity,
          sidebarWidth: _widthAnimation.value,
        ),
      ],
    );
  }

  Widget _buildFooter(bool showContent, double opacity) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
      ),
      child: showContent
          ? Opacity(
              opacity: opacity,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade600],
                      ),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Vendor Name',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                        Text(
                          'View Profile',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          softWrap: false,
                          overflow: TextOverflow.clip,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                ],
              ),
            )
          : Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade600],
                  ),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, bool showContent, double opacity) {
    if (!showContent) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Opacity(
        opacity: opacity,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              height: 1,
              width: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String page,
    required bool showContent,
    required double opacity,
    required double sidebarWidth,
    Widget? badgeWidget,
  }) {
    bool isSelected = widget.selectedPage == page;
    bool isHovered = _hoveredItem == page;
    
    // Calculate layout values based on expansion progress
    const double minWidth = 72.0;
    const double maxWidth = 280.0;
    final double expandProgress = ((sidebarWidth - minWidth) / (maxWidth - minWidth)).clamp(0.0, 1.0);
    
    // Lerp values
    // Margin: 4 -> 10
    final double horizontalMargin = 4.0 + (6.0 * expandProgress);
    // Icon Container Width: 46 -> 64
    final double iconContainerWidth = 46.0 + (18.0 * expandProgress);
    
    return Tooltip(
      message: !showContent ? label : '',
      waitDuration: const Duration(milliseconds: 400),
      preferBelow: false,
      verticalOffset: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF334155),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredItem = page),
        onExit: (_) => setState(() => _hoveredItem = null),
        child: InkWell(
          onTap: () => widget.onPageSelected(page),
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.transparent,
          splashColor: Colors.deepOrange.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 0), // Width animation handles updates
            margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 3),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.deepOrange.withOpacity(0.2),
                        Colors.deepOrange.withOpacity(0.1),
                      ],
                    )
                  : null,
              color: isHovered && !isSelected
                  ? Colors.white.withOpacity(0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Colors.deepOrange.withOpacity(0.5)
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Row(
                children: [
                  // Icon Container
                  SizedBox(
                    width: iconContainerWidth,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.deepOrange.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected
                              ? Colors.deepOrange
                              : isHovered
                                  ? Colors.white
                                  : Colors.white60,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  
                  // Label and Badge (Conditionally Visible)
                  if (showContent)
                    Expanded(
                      child: Opacity(
                        opacity: opacity,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : isHovered
                                            ? Colors.white
                                            : Colors.white70,
                                    fontSize: 14.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                              
                              // Badge
                              if (badgeWidget != null) ...[
                                const SizedBox(width: 8),
                                badgeWidget,
                              ],
                              
                              // Arrow indicator for selected item
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.deepOrange.withOpacity(0.6),
                                    size: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}