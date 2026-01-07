import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _nameController = TextEditingController();
  String _selectedIcon = "🍎"; // Default emoji icon

  // Simple list of icons/emojis for categories
  final List<String> _icons = [
    "🍎",
    "🥦",
    "🥛",
    "🍞",
    "🥤",
    "👕",
    "🔌",
    "🏠",
    "💊",
    "🎉"
  ];

  void _addCategory() async {
    if (_nameController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('categories').add({
      'name': _nameController.text.trim(),
      'icon': _selectedIcon,
      'created_at': FieldValue.serverTimestamp(),
    });

    _nameController.clear();
    Navigator.pop(context); // Close dialog
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Category"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: "Category Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            const Text("Select Icon:"),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              width: double.maxFinite,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _icons.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedIcon = _icons[index]);
                      Navigator.pop(
                          context); // Close selection (re-open dialog is tricky in basic code, simplifying for MVP)
                      _showAddDialog(); // Re-open to show selected (or use StatefulBuilder inside dialog for better UX)
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(_icons[index],
                          style: TextStyle(
                              fontSize: 24,
                              backgroundColor: _selectedIcon == _icons[index]
                                  ? Colors.green[100]
                                  : null)),
                    ),
                  );
                },
              ),
            ),
            Text("Selected: $_selectedIcon",
                style: const TextStyle(fontSize: 20)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(onPressed: _addCategory, child: const Text("Add")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Manage Categories"),
          backgroundColor: Colors.orange[100]),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .orderBy('created_at')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: Text(data['icon'] ?? "📦",
                      style: const TextStyle(fontSize: 24)),
                  title: Text(data['name']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => FirebaseFirestore.instance
                        .collection('categories')
                        .doc(docs[index].id)
                        .delete(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
