import 'package:flutter/material.dart';

class CustomerCategoryScreen extends StatelessWidget {
  const CustomerCategoryScreen({super.key});

  final List<Map<String, dynamic>> categories = const [
    {'name': 'Groceries', 'icon': Icons.local_grocery_store},
    {'name': 'Vegetables', 'icon': Icons.eco},
    {'name': 'Snacks', 'icon': Icons.fastfood},
    {'name': 'Household', 'icon': Icons.home},
    {'name': 'Electronics', 'icon': Icons.electrical_services},
    {'name': 'Fashion', 'icon': Icons.checkroom},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Categories"),
        backgroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Filtering by ${categories[index]['name']}"),
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green.shade50,
                  child: Icon(
                    categories[index]['icon'],
                    color: Colors.green,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  categories[index]['name'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
