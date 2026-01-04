import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'master_product_form.dart';

class SubcategoryProductsView extends StatefulWidget {
  final String categoryName;
  final String subcategoryName;

  const SubcategoryProductsView({
    super.key,
    required this.categoryName,
    required this.subcategoryName,
  });

  @override
  State<SubcategoryProductsView> createState() => _SubcategoryProductsViewState();
}

class _SubcategoryProductsViewState extends State<SubcategoryProductsView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} › ${widget.subcategoryName}'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('master_products')
            .where('category', isEqualTo: widget.categoryName)
            .where('subcategory', isEqualTo: widget.subcategoryName)
            .snapshots(),
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
                    'No products found in this subcategory',
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
    );
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
