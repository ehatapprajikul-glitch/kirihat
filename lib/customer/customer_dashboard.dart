import 'package:flutter/material.dart';
// Ensure these imports match your file names
import 'customer_home.dart';
import 'customer_category.dart';
import 'customer_orders.dart';
import 'customer_profile.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;

  // The 4 Screens (Tabs)
  final List<Widget> _screens = [
    const CustomerHomeScreen(), // Tab 0: Home (The complex UI)
    const CustomerCategoryScreen(), // Tab 1: Categories
    const CustomerOrdersScreen(), // Tab 2: Orders
    const CustomerProfileScreen(), // Tab 3: Profile (Me)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // This body switches depending on which tab is clicked
      body: _screens[_selectedIndex],

      // THE BOTTOM TABS
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
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
    );
  }
}
