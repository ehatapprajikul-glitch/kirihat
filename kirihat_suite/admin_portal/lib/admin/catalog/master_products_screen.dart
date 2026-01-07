import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'master_product_form.dart' as comprehensive;

class MasterProductsScreen extends StatefulWidget {
  const MasterProductsScreen({super.key});

  @override
  State<MasterProductsScreen> createState() => _MasterProductsScreenState();
}

class _MasterProductsScreenState extends State<MasterProductsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterCategory = 'All';
  String? _filterCategoryId; // Track category ID for subcategory filtering
  String _filterSubcategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Master Product Catalog',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showProductForm(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Search and Filters
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search by name, tags, SEO...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Category Filter
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('categories')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                List<String> categories = ['All'];
                Map<String, String> categoryMap = {}; // name -> id
                
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    String name = doc['name'] as String;
                    categories.add(name);
                    categoryMap[name] = doc.id;
                  }
                }
                return Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: categories.contains(_filterCategory) ? _filterCategory : 'All',
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat == 'All' ? 'All Categories' : cat),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() {
                        _filterCategory = val!;
                        _filterCategoryId = val != 'All' ? categoryMap[val] : null;
                        _filterSubcategory = 'All'; // Reset subcat
                      }),
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),

            // Subcategory Filter (Dynamic)
            if (_filterCategoryId != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('subcategories')
                    .where('category_id', isEqualTo: _filterCategoryId)
                    .snapshots(),
                builder: (context, snapshot) {
                  List<String> subcategories = ['All'];
                  if (snapshot.hasData) {
                    subcategories.addAll(
                      snapshot.data!.docs.map((doc) => doc['name'] as String),
                    );
                  }
                  return Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: subcategories.contains(_filterSubcategory) ? _filterSubcategory : 'All',
                        items: subcategories.map((sub) {
                          return DropdownMenuItem(
                            value: sub,
                            child: Text(sub == 'All' ? 'All Subcategories' : sub),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _filterSubcategory = val!),
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Products Grid
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('master_products')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              // Advanced Filter Logic
              var filteredDocs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                
                // 1. Category Filter
                String category = data['category'] ?? '';
                if (_filterCategory != 'All' && category != _filterCategory) return false;

                // 2. Subcategory Filter
                String subcategory = data['subcategory'] ?? '';
                if (_filterSubcategory != 'All' && subcategory != _filterSubcategory) return false;

                // 3. Search Filter
                if (_searchQuery.isNotEmpty) {
                  String name = (data['name'] ?? '').toString().toLowerCase();
                  String seoTitle = (data['seo_title'] ?? '').toString().toLowerCase();
                  String seoDesc = (data['seo_description'] ?? '').toString().toLowerCase();
                  String brand = (data['brand'] ?? '').toString().toLowerCase();
                  String barcode = (data['barcode'] ?? '').toString().toLowerCase();
                  List tags = (data['tags'] as List? ?? []).map((e) => e.toString().toLowerCase()).toList();

                  bool matchesName = name.contains(_searchQuery);
                  bool matchesSeo = seoTitle.contains(_searchQuery) || seoDesc.contains(_searchQuery);
                  bool matchesBrand = brand.contains(_searchQuery);
                  bool matchesBarcode = barcode.contains(_searchQuery);
                  bool matchesTags = tags.any((t) => t.contains(_searchQuery));

                  if (!matchesName && !matchesSeo && !matchesBrand && !matchesBarcode && !matchesTags) return false;
                }

                return true;
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Text('No products match your filters', style: TextStyle(color: Colors.grey)),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive validation: 
                  // > 1400: 5 cols
                  // > 1100: 4 cols
                  // > 800: 3 cols
                  // < 800: 2 cols
                  int crossAxisCount = 4;
                  double width = constraints.maxWidth;
                  if (width > 1400) {
                    crossAxisCount = 5;
                  } else if (width > 1100) {
                    crossAxisCount = 4;
                  } else if (width > 750) {
                    crossAxisCount = 3;
                  } else {
                    crossAxisCount = 2;
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.65, // Consistent aspect ratio
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      return _buildProductCard(filteredDocs[index]);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showProductForm(context, null),
            child: const Text('Add First Product'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String docId = doc.id;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: const Color(0xFFF1F5F9), // Light grey background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Area
          Expanded(
             flex: 4, // 55% image (increased from ~50%)
             child: Stack(
               children: [
                 Container(
                   decoration: const BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                   ),
                   width: double.infinity,
                   child: data['imageUrl'] != null
                       ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              data['imageUrl'],
                              fit: BoxFit.contain, 
                              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40, color: Colors.grey),
                            ),
                         )
                       : const Icon(Icons.image, size: 40, color: Colors.grey),
                 ),
                 // Category Badge
                 if (data['category'] != null)
                   Positioned(
                     top: 8,
                     left: 8,
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: Colors.black54,
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text(
                         data['category'],
                         style: const TextStyle(color: Colors.white, fontSize: 10),
                       ),
                     ),
                   ),
               ],
             ),
          ),
          
          // Content Area
          Expanded(
            flex: 3, // 45% content (increased from ~40%)
            child: Padding(
              padding: const EdgeInsets.all(10), // Reduced from 12
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Unnamed',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                         data['unit'] ?? '',
                         style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MRP: ₹${data['mrp'] ?? 0}',
                        style: const TextStyle(
                          color: Color(0xFF0D9759),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                            onPressed: () => _showProductForm(context, {'id': docId, ...data}),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Edit',
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            onPressed: () => _confirmDelete(docId, data['name']),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete',
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductForm(BuildContext context, Map<String, dynamic>? product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 900,
          constraints: const BoxConstraints(maxHeight: 800),
          child: comprehensive.ComprehensiveMasterProductForm(product: product),
        ),
      ),
    );
  }

  void _confirmDelete(String docId, String? name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('master_products')
                  .doc(docId)
                  .delete();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
