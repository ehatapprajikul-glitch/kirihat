import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'master_product_form.dart';

class CategoryProductsView extends StatefulWidget {
  final String categoryName;

  const CategoryProductsView({
    super.key,
    required this.categoryName,
  });

  @override
  State<CategoryProductsView> createState() => _CategoryProductsViewState();
}

class _CategoryProductsViewState extends State<CategoryProductsView> {
  String? _selectedSubcategory;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategoryId();
  }

  Future<void> _loadCategoryId() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .where('name', isEqualTo: widget.categoryName)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty && mounted) {
      setState(() {
        _selectedCategoryId = snapshot.docs.first.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Products in ${widget.categoryName}'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Subcategory Filter
          if (_selectedCategoryId != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('subcategories')
                    .where('category_id', isEqualTo: _selectedCategoryId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final subcategories = snapshot.data!.docs;
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedSubcategory,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Subcategory',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Subcategories'),
                      ),
                      ...subcategories.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: data['name'],
                          child: Text(data['name'] ?? 'Unnamed'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedSubcategory = value);
                    },
                  );
                },
              ),
            ),

          // Products Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildProductsQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No products found in this category',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final products = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final doc = products[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildProductCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildProductsQuery() {
    Query query = FirebaseFirestore.instance
        .collection('master_products')
        .where('category', isEqualTo: widget.categoryName);

    // Apply subcategory filter if selected
    if (_selectedSubcategory != null) {
      query = query.where('subcategory', isEqualTo: _selectedSubcategory);
    }

    return query.snapshots();
  }

  Widget _buildProductCard(String productId, Map<String, dynamic> data) {
    String name = data['name'] ?? 'Unnamed Product';
    String? imageUrl = data['imageUrl'] ?? (data['images'] != null && (data['images'] as List).isNotEmpty
        ? data['images'][0]
        : null);
    double mrp = (data['mrp'] ?? 0).toDouble();

    return GestureDetector(
      onTap: () {
        // Navigate to edit product screen
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Container(
              width: 900,
              height: MediaQuery.of(context).size.height * 0.9,
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ComprehensiveMasterProductForm(
                product: {'id': productId, ...data},
              ),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  image: imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.contain,
                        )
                      : null,
                ),
                child: imageUrl == null
                    ? const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.grey),
                      )
                    : null,
              ),
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${mrp.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF0D9759),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (data['subcategory'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      data['subcategory'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
