import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_master_product_editor.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

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
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Master Product Catalog',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            // Add Product Button Removed
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

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(filteredDocs[index]);
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
          // Add First Product Button Removed
        ],
      ),
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String docId = doc.id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _showProductForm(context, {'id': docId, ...data}),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: data['imageUrl'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : const Icon(Icons.image, size: 32, color: Colors.grey),
              ),
              const SizedBox(width: 16),

              // Product Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      data['name'] ?? 'Unnamed Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Category & Subcategory (Text badges, no icons)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (data['category'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF0D9759).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              data['category'],
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF0D9759),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (data['subcategory'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.blue.shade200,
                              ),
                            ),
                            child: Text(
                              data['subcategory'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Brand and Unit
                    Row(
                      children: [
                        if (data['brand'] != null && data['brand'].toString().isNotEmpty) ...[
                          Icon(Icons.branding_watermark, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            data['brand'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (data['unit'] != null) ...[
                          Icon(Icons.scale, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            data['unit'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // MRP
                    Text(
                      'MRP: ${CurrencyHelper.format(data['mrp'] ?? 0)}',
                      style: const TextStyle(
                        color: Color(0xFF0D9759),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: Colors.blue,
                    onPressed: () => _showProductForm(context, {'id': docId, ...data}),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    onPressed: () => _confirmDelete(docId, data['name']),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductForm(BuildContext context, Map<String, dynamic>? product) {
    if (product == null) return; 
    
    // Ensure product has key details
    String docId = product['id'] ?? product['docId']; 
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 1000, 
          height: 850,
          child: AdminMasterProductEditor(
              docId: docId, 
              product: product
          ),
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
