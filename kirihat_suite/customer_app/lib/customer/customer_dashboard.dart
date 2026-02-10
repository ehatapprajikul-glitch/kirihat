import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'home/customer_home_screen.dart';
import 'category_products.dart';
import 'customer_orders.dart';
import 'customer_profile.dart';
import 'services/notification_service.dart';

class CustomerDashboard extends StatefulWidget {
  final int initialIndex;
  
  const CustomerDashboard({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;
  List<String> _assignedVendorIds = [];
  bool _isLoading = true;
  final _sessionService = SessionService();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadSession();
    
    // Listen for auth state changes to rebuild UI immediately
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && mounted) {
        // Initialize Notification Service when user is logged in
        // We need a slight delay to ensure context is ready? 
        // Actually context is available in initState but using it in async callbacks is better safely handled
        WidgetsBinding.instance.addPostFrameCallback((_) {
           NotificationService().init(context);
        });
      }
      
      if (mounted) {
        setState(() {
          // Trigger rebuild to update UI for guest/logged-in state
        });
      }
    });
  }

  Future<void> _loadSession() async {
    try {
      final session = await _sessionService.getSession();
      List<String> vIds = [];
      
      // Handle legacy and new formats
      if (session['vendorIds'] != null) {
        vIds = List<String>.from(session['vendorIds']);
      } else if (session['vendorId'] != null) {
        vIds = [session['vendorId']];
      }
      
      if (mounted) {
        setState(() {
          _assignedVendorIds = vIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Dashboard Session Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Screens with vendor context
    final List<Widget> screens = [
      const EnhancedCustomerHomeScreen(), // Enhanced home screen
      const CategoryProductsScreen(categoryName: "All Products"),
      const CustomerOrdersScreen(),
      const CustomerProfileScreen(),
    ];

    return PopScope(
      canPop: _selectedIndex == 0, // Only allow pop if on Home
      onPopInvoked: (didPop) {
        if (didPop) return;
        // If not on home, go to home
        setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          key: ValueKey(FirebaseAuth.instance.currentUser?.uid), // Force rebuild when user changes
          index: _selectedIndex,
          children: screens, // screens list is not const now
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF059669)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.45, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  );
                }
                return TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: Color(0xFF064E3B), size: 26);
                }
                return IconThemeData(
                  color: Colors.white.withOpacity(0.7),
                  size: 24,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              indicatorColor: Colors.white,
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 65,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: "Home",
                ),
                NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category_rounded),
                  label: "Categories",
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag_rounded),
                  label: "Order",
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: "Me",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
