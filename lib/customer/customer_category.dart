import 'package:flutter/material.dart';
import 'category_products.dart'; // Import the new screen

class CustomerCategoryScreen extends StatelessWidget {
  const CustomerCategoryScreen({super.key});

  final List<Map<String, dynamic>> categories = const [
    {'name': 'Vegetables', 'icon': Icons.eco},
    {'name': 'Fruits', 'icon': Icons.apple},
    {'name': 'Dairy', 'icon': Icons.egg},
    {'name': 'Bakery', 'icon': Icons.breakfast_dining},
    {'name': 'Drinks', 'icon': Icons.local_drink},
    {'name': 'Snacks', 'icon': Icons.fastfood},
    {'name': 'Household', 'icon': Icons.home},
    {'name': 'Electronics', 'icon': Icons.electrical_services},
    {'name': 'Fashion', 'icon': Icons.checkroom},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("All Categories"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.8,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryProductsScreen(
                    categoryName: categories[index]['name'],
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    categories[index]['icon'],
                    color: Colors.green,
                    size: 35,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    categories[index]['name'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
