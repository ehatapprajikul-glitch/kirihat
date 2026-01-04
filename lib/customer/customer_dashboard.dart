import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'home/customer_home_screen.dart';
import 'category_products.dart';
import 'customer_orders.dart';
import 'customer_profile.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

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
    _loadSession();
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
      const NewCustomerHomeScreen(), // New hero category home
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
          index: _selectedIndex,
          children: screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          indicatorColor: Colors.green.shade100,
          backgroundColor: Colors.white,
          elevation: 3,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Colors.green),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category, color: Colors.green),
              label: "Categories",
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag, color: Colors.green),
              label: "Orders",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Colors.green),
              label: "Me",
            ),
          ],
        ),
      ),
    );
  }
}
