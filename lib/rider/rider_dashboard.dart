import 'package:flutter/material.dart';
import 'rider_home.dart';
import 'rider_orders.dart';
import 'rider_history.dart';
import 'rider_profile.dart';

class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});

  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const RiderHomeScreen(), // 0. Dashboard
    const RiderOrdersScreen(), // 1. Deliveries (Active Work)
    const RiderHistoryScreen(), // 2. Past Trips
    const RiderProfileScreen(), // 3. Profile & Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: Colors.blue.shade100,
        elevation: 3,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Colors.blue),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.moped_outlined),
            selectedIcon: Icon(Icons.moped, color: Colors.blue),
            label: "Deliveries",
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Colors.blue),
            label: "History",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.blue),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
