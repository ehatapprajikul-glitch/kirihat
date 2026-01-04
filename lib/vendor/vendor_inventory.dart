import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_product_screen.dart';
import 'add_category_screen.dart';
import 'vendor_product_detail.dart';

class VendorInventoryScreen extends StatefulWidget {
  const VendorInventoryScreen({super.key});

  @override
  State<VendorInventoryScreen> createState() => _VendorInventoryScreenState();
}

class _VendorInventoryScreenState extends State<VendorInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? user = FirebaseAuth.instance.currentUser;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteCategory(String docId, String categoryName) async {
    bool confirm = await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Delete Category?"),
            content: Text(
                "Warning: This will delete '$categoryName' and ALL products inside it."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text("Cancel")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Delete All")),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      // 1. Delete Products
      var products = await FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: categoryName)
          .get();
      for (var doc in products.docs) {
        await doc.reference.delete();
      }
      // 2. Delete Category
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Category and items deleted.")));
      }
    }
  }

  Future<void> _deleteProduct(String docId) async {
    bool confirm = await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Delete Product?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text("Delete",
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(docId)
          .delete();
    }
  }

  // --- SAFE ICON BUILDER (Handles URL vs Emoji) ---
  Widget _buildCategoryIcon(String? iconData) {
    if (iconData == null || iconData.isEmpty) {
      return const Icon(Icons.image_not_supported,
          size: 40, color: Colors.grey);
    }
    // Check if it's a URL (Cloudinary)
    if (iconData.startsWith('http')) {
      return Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(iconData),
              fit: BoxFit.cover,
              onError: (e, s) => {}, // Silent error
            )),
      );
    }
    // Assume it's an emoji/text
    return Text(iconData, style: const TextStyle(fontSize: 40));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Inventory Manager"),
        backgroundColor: Colors.orange[100],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepOrange,
          indicatorColor: Colors.deepOrange,
          tabs: const [
            Tab(text: "Categories"),
            Tab(text: "All Items"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoriesTab(),
          _buildItemsTab(),
        ],
      ),
    );
  }

  // --- TAB 1: CATEGORIES ---
  Widget _buildCategoriesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "catBtn",
            onPressed: () => showDialog(
                context: context, builder: (_) => const AddCategoryScreen()),
            label: const Text("New Category"),
            icon: const Icon(Icons.category),
            backgroundColor: Colors.blueGrey,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "prodBtn",
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddProductScreen())),
            label: const Text("New Product"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.deepOrange,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No categories yet."));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return GestureDetector(
                onTap: () {
                  _searchController.text = data['name'] ?? "";
                  setState(() => _searchQuery =
                      (data['name'] ?? "").toString().toLowerCase());
                  _tabController.animateTo(1);
                },
                child: Card(
                  elevation: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCategoryIcon(data['icon']),
                      const SizedBox(height: 10),
                      Text(data['name'] ?? "Unnamed",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      TextButton.icon(
                        onPressed: () =>
                            _deleteCategory(docs[index].id, data['name'] ?? ""),
                        icon: const Icon(Icons.delete,
                            size: 16, color: Colors.red),
                        label: const Text("Delete",
                            style: TextStyle(color: Colors.red, fontSize: 12)),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- TAB 2: ITEMS ---
  Widget _buildItemsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search products...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  }),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('vendor_id', isEqualTo: user?.uid)
                // .orderBy('created_at', descending: true) // Commented out
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No items found."));
              }

              var docs = snapshot.data!.docs;

              var filtered = docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                String name = (data['name'] ?? "").toString().toLowerCase();
                String category =
                    (data['category'] ?? "").toString().toLowerCase();
                return name.contains(_searchQuery) ||
                    category.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                    child: Text("No items found matching search."));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  var doc = filtered[index];
                  var data = doc.data() as Map<String, dynamic>;

                  // SAFE TIMESTAMP PARSING
                  String date = "Unknown Date";
                  if (data['created_at'] != null &&
                      data['created_at'] is Timestamp) {
                    date = DateFormat('MMM d, y • h:mm a')
                        .format((data['created_at'] as Timestamp).toDate());
                  }

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => VendorProductDetailScreen(
                                    productData: data, productId: doc.id)));
                      },
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            image: (data['imageUrl'] != null &&
                                    data['imageUrl'].toString().isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(data['imageUrl']),
                                    fit: BoxFit.cover)
                                : null),
                        child: (data['imageUrl'] == null ||
                                data['imageUrl'].toString().isEmpty)
                            ? const Icon(Icons.image, color: Colors.grey)
                            : null,
                      ),
                      title: Text(data['name'] ?? "Unknown Product",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data['unit'] != null && data['unit'].toString().isNotEmpty)
                             Text("${data['unit']}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                          Text("Added: $date",
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                              "Stock: ${data['stock_quantity'] ?? 0} | ₹${data['price'] ?? 0}",
                              style: TextStyle(
                                  color: (data['stock_quantity'] ?? 0) <= 0
                                      ? Colors.red 
                                      : (data['stock_quantity'] ?? 0) < 5 ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AddProductScreen(
                                        initialData: data, docId: doc.id))),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProduct(doc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
