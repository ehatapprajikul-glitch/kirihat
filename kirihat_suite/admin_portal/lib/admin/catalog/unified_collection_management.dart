import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/collection_model.dart';
import 'package:kirihat_core/services/smart_collection_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For vendor ID if needed

/// Unified screen to manage Collections, Categories, and Smart Collections
/// with expandable product views and drag-and-drop reordering
class UnifiedCollectionManagementScreen extends StatefulWidget {
  const UnifiedCollectionManagementScreen({super.key});

  @override
  State<UnifiedCollectionManagementScreen> createState() => _UnifiedCollectionManagementScreenState();
}

class _UnifiedCollectionManagementScreenState extends State<UnifiedCollectionManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection & Category Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D9759),
          indicatorColor: const Color(0xFF0D9759),
          tabs: const [
            Tab(icon: Icon(Icons.collections_bookmark), text: 'Collections'),
            Tab(icon: Icon(Icons.category), text: 'Categories'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Smart'),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CollectionsTab(),
          _CategoriesTab(),
          _SmartCollectionsTab(),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {
        if (_tabController.index == 0) {
          _showCollectionDialog();
        } else if (_tabController.index == 1) {
          _showCategoryDialog();
        }
      },
      backgroundColor: const Color(0xFF0D9759),
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showCollectionDialog({CollectionModel? collection}) {
    showDialog(
      context: context,
      builder: (context) => _CollectionDialog(collection: collection),
    );
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(category: category),
    );
  }
}

/// Tab for managing collections with expandable product view
class _CollectionsTab extends StatefulWidget {
  @override
  State<_CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<_CollectionsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, bool> _expandedState = {}; // collectionId -> isExpanded
  Map<String, List<Map<String, dynamic>>> _productCache = {}; // collectionId -> products

  Future<void> _loadProducts(String collectionId, List<String> productIds) async {
    if (_productCache.containsKey(collectionId)) return;

    // Batch fetch products (max 10 at a time due to whereIn limit)
    const batchSize = 10;
    List<Map<String, dynamic>> allProducts = [];

    for (var i = 0; i < productIds.length; i += batchSize) {
      var end = (i + batchSize < productIds.length) ? i + batchSize : productIds.length;
      var batchIds = productIds.sublist(i, end);

      final snapshot = await _firestore
          .collection('master_products')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['id'] = doc.id;
        allProducts.add(data);
      }
    }

    // Sort by collection order
    final orderedProducts = <Map<String, dynamic>>[];
    for (var id in productIds) {
      final product = allProducts.firstWhere((p) => p['id'] == id, orElse: () => {});
      if (product.isNotEmpty) orderedProducts.add(product);
    }

    setState(() {
      _productCache[collectionId] = orderedProducts;
    });
  }

  Future<void> _updateCollectionOrder(List<DocumentSnapshot> orderedDocs) async {
    final batch = _firestore.batch();
    for (int i = 0; i < orderedDocs.length; i++) {
      batch.update(orderedDocs[i].reference, {'sort_order': i});
    }
    await batch.commit();
  }

  Future<void> _deleteCollection(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('product_collections').doc(id).delete();
    }
  }

  Future<void> _toggleActive(String id, bool currentValue) async {
    await _firestore.collection('product_collections').doc(id).update({
      'is_active': !currentValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('product_collections').orderBy('sort_order').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No collections found. Create one!'));
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          onReorder: (oldIndex, newIndex) async {
            if (oldIndex < newIndex) newIndex -= 1;
            final doc = docs.removeAt(oldIndex);
            docs.insert(newIndex, doc);
            _updateCollectionOrder(docs);
          },
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final collection = CollectionModel.fromMap(data, docs[index].id);
            final isExpanded = _expandedState[collection.id] ?? false;

            return Card(
              key: ValueKey(collection.id),
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.drag_handle, color: Color(0xFF0D9759)),
                    title: Text(collection.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${collection.productIds.length} products'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active/Inactive Toggle
                        Switch(
                          value: collection.isActive,
                          onChanged: (v) => _toggleActive(collection.id, collection.isActive),
                          activeColor: const Color(0xFF0D9759),
                        ),
                        Text(
                          collection.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            color: collection.isActive ? const Color(0xFF0D9759) : Colors.grey,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            // Open edit dialog
                            showDialog(
                              context: context,
                              builder: (context) => _CollectionDialog(collection: collection),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCollection(collection.id),
                        ),
                        IconButton(
                          icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                          onPressed: () {
                            setState(() {
                              _expandedState[collection.id] = !isExpanded;
                            });
                            if (!isExpanded && !_productCache.containsKey(collection.id)) {
                              _loadProducts(collection.id, collection.productIds);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isExpanded) _buildProductGrid(collection),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductGrid(CollectionModel collection) {
    final products = _productCache[collection.id];

    if (products == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('No products in this collection')),
      );
    }

    // Use ReorderableListView wrapped to show as grid-like but allow drag
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Drag to reorder products',
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length > 20 ? 20 : products.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              final product = products.removeAt(oldIndex);
              products.insert(newIndex, product);
              
              // Update product order in collection
              final newProductIds = products.map((p) => p['id'].toString()).toList();
              _updateCollectionProducts(collection.id, newProductIds);
              
              setState(() {
                _productCache[collection.id] = products;
              });
            },
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                key: ValueKey(product['id']),
                margin: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: product['imageUrl'] != null
                          ? Image.network(
                              product['imageUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 30),
                            )
                          : const Icon(Icons.image, size: 30),
                    ),
                    title: Text(
                      product['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('₹${product['mrp'] ?? 0}'),
                    trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateCollectionProducts(String collectionId, List<String> productIds) async {
    try {
      await _firestore.collection('product_collections').doc(collectionId).update({
        'product_ids': productIds,
      });
    } catch (e) {
      debugPrint('Error updating collection products: $e');
    }
  }
}

/// Compact product card for admin view
class _CompactProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const _CompactProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: product['imageUrl'] != null
                  ? Image.network(
                      product['imageUrl'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40),
                    )
                  : const Center(child: Icon(Icons.image, size: 40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${product['mrp'] ?? 0}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Categories tab - similar structure
class _CategoriesTab extends StatefulWidget {
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, bool> _expandedState = {};
  Map<String, List<Map<String, dynamic>>> _productCache = {};

  Future<void> _loadProductsForCategory(String categoryId, String categoryName) async {
    if (_productCache.containsKey(categoryId)) return;

    final snapshot = await _firestore
        .collection('master_products')
        .where('category', isEqualTo: categoryName)
        .limit(20) // Pagination
        .get();

    final products = snapshot.docs.map((doc) {
      var data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    setState(() {
      _productCache[categoryId] = products;
    });
  }

  Future<void> _updateCategoryOrder(List<DocumentSnapshot> orderedDocs) async {
    final batch = _firestore.batch();
    for (int i = 0; i < orderedDocs.length; i++) {
      batch.update(orderedDocs[i].reference, {'sort_order': i});
    }
    await batch.commit();
  }

  Future<void> _toggleActive(String id, bool currentValue) async {
    await _firestore.collection('categories').doc(id).update({
      'is_active': !currentValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Removed orderBy('sort_order') to ensure all categories appear even if field is missing
      stream: _firestore.collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No categories found.'));
        }

        // Sort client-side safely
        docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final sortA = dataA['sort_order'] as num? ?? 999;
            final sortB = dataB['sort_order'] as num? ?? 999;
            return sortA.compareTo(sortB);
        });

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          onReorder: (oldIndex, newIndex) async {
            if (oldIndex < newIndex) newIndex -= 1;
            final doc = docs.removeAt(oldIndex);
            docs.insert(newIndex, doc);
            _updateCategoryOrder(docs);
          },
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final categoryId = docs[index].id;
            final categoryName = data['name'] ?? 'Unnamed';
            final isActive = data['is_active'] ?? true;
            final isExpanded = _expandedState[categoryId] ?? false;

            return Card(
              key: ValueKey(categoryId),
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: data['imageUrl'] != null
                        ? CircleAvatar(backgroundImage: NetworkImage(data['imageUrl']))
                        : const CircleAvatar(child: Icon(Icons.category)),
                    title: Text(categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: isActive,
                          onChanged: (v) => _toggleActive(categoryId, isActive),
                          activeColor: const Color(0xFF0D9759),
                        ),
                        Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive ? const Color(0xFF0D9759) : Colors.grey,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => _CategoryDialog(category: {'id': categoryId, ...data}),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                          onPressed: () {
                            setState(() {
                              _expandedState[categoryId] = !isExpanded;
                            });
                            if (!isExpanded && !_productCache.containsKey(categoryId)) {
                              _loadProductsForCategory(categoryId, categoryName);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isExpanded) _buildProductGrid(categoryId),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductGrid(String categoryId) {
    final products = _productCache[categoryId];

    if (products == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('No products in this category')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _CompactProductCard(product: product);
        },
      ),
    );
  }
}

/// Smart collections tab with Firestore-backed toggles
class _SmartCollectionsTab extends StatefulWidget {
  @override
  State<_SmartCollectionsTab> createState() => _SmartCollectionsTabState();
}

class _SmartCollectionsTabState extends State<_SmartCollectionsTab> {
  // Settings stored in Firestore: settings/smart_collections
  bool _showWishlist = true;
  bool _showBuyAgain = true;
  bool _showNewArrivals = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('smart_collections')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _showWishlist = data['wishlist_enabled'] ?? true;
            _showBuyAgain = data['buy_again_enabled'] ?? true;
            _showNewArrivals = data['new_arrivals_enabled'] ?? true;
            _isLoading = false;
          });
        }
      } else {
        // Create default settings if they don't exist
        await FirebaseFirestore.instance
            .collection('settings')
            .doc('smart_collections')
            .set({
          'wishlist_enabled': true,
          'buy_again_enabled': true,
          'new_arrivals_enabled': true,
        });
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading smart collection settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('smart_collections')
          .update({key: value});
    } catch (e) {
      print('Error updating setting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update setting: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 32, color: Colors.blue),
              const SizedBox(width: 12),
              const Text(
                'Smart Collections',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Control visibility of smart collections in customer app',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Info Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Toggle visibility of smart collections in customer sidebar. Note: Wishlist in Profile tab is always accessible.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Collection Cards with Toggles
          if (_showWishlist)
            _buildCollectionCard(
              icon: Icons.favorite,
              title: 'My Wishlist',
              description: 'Personalized collection of items each user saves with the heart icon',
              color: Colors.pink,
              enabled: _showWishlist,
              onToggle: (val) {
                setState(() => _showWishlist = val);
                _updateSetting('wishlist_enabled', val);
              },
            ),
          if (!_showWishlist) _buildCollapsedCard('My Wishlist', () {
            setState(() => _showWishlist = true);
            _updateSetting('wishlist_enabled', true);
          }),
          
          const SizedBox(height: 16),

          if (_showBuyAgain)
            _buildCollectionCard(
              icon: Icons.history,
              title: 'Buy Again',
              description: 'Shows frequently purchased items per user based on order history',
              color: Colors.orange,
              enabled: _showBuyAgain,
              onToggle: (val) {
                setState(() => _showBuyAgain = val);
                _updateSetting('buy_again_enabled', val);
              },
            ),
          if (!_showBuyAgain) _buildCollapsedCard('Buy Again', () {
            setState(() => _showBuyAgain = true);
            _updateSetting('buy_again_enabled', true);
          }),

          const SizedBox(height: 16),

          if (_showNewArrivals)
            _buildCollectionCard(
              icon: Icons.new_releases,
              title: 'New Arrivals',
              description: 'Recently added products across the platform (last 30 days)',
              color: Colors.green,
              enabled: _showNewArrivals,
              onToggle: (val) {
                setState(() => _showNewArrivals = val);
                _updateSetting('new_arrivals_enabled', val);
              },
            ),
          if (!_showNewArrivals) _buildCollapsedCard('New Arrivals', () {
            setState(() => _showNewArrivals = true);
            _updateSetting('new_arrivals_enabled', true);
          }),
        ],
      ),
    );
  }

  Widget _buildCollectionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool enabled,
    required Function(bool) onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeColor: color,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: enabled ? Colors.green[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  enabled ? Icons.visibility : Icons.visibility_off,
                  color: enabled ? Colors.green : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    enabled ? 'Visible in customer sidebar' : 'Hidden from customer sidebar',
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.green[800] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedCard(String title, VoidCallback onExpand) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_off, color: Colors.grey[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title (Hidden from customers)',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: onExpand,
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

/// Collection dialog (simplified version of existing)
class _CollectionDialog extends StatefulWidget {
  final CollectionModel? collection;

  const _CollectionDialog({this.collection});

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<String> _selectedProductIds = [];
  bool _isActive = true;
  bool _isLoading = false;
  Map<String, String> _productNames = {};

  @override
  void initState() {
    super.initState();
    if (widget.collection != null) {
      _nameController.text = widget.collection!.name;
      _selectedProductIds = List.from(widget.collection!.productIds);
      _isActive = widget.collection!.isActive;
      _fetchProductNames();
    }
  }

  Future<void> _fetchProductNames() async {
    if (_selectedProductIds.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('master_products')
        .where(FieldPath.documentId, whereIn: _selectedProductIds.take(10).toList())
        .get();

    final names = <String, String>{};
    for (var doc in snapshot.docs) {
      names[doc.id] = doc['name'];
    }

    if (mounted) {
      setState(() {
        _productNames.addAll(names);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'product_ids': _selectedProductIds,
        'is_active': _isActive,
        'sort_order': 0,
      };

      if (widget.collection == null) {
        await FirebaseFirestore.instance.collection('product_collections').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('product_collections')
            .doc(widget.collection!.id)
            .update(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProductPicker() async {
    final result = await showDialog<List<Map<String, String>>>(
      context: context,
      builder: (context) => const _ProductPickerDialog(),
    );

    if (result != null) {
      setState(() {
        for (var p in result) {
          if (!_selectedProductIds.contains(p['id'])) {
            _selectedProductIds.add(p['id']!);
            _productNames[p['id']!] = p['name']!;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.collection == null ? 'New Collection' : 'Edit Collection',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Collection Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _showProductPicker,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Products'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedProductIds.isEmpty
                    ? const Center(child: Text('No products added'))
                    : ReorderableListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) newIndex -= 1;
                            final item = _selectedProductIds.removeAt(oldIndex);
                            _selectedProductIds.insert(newIndex, item);
                          });
                        },
                        children: [
                          for (int i = 0; i < _selectedProductIds.length; i++)
                            ListTile(
                              key: ValueKey(_selectedProductIds[i]),
                              leading: const Icon(Icons.drag_handle),
                              title: Text(_productNames[_selectedProductIds[i]] ?? 'Loading...'),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _selectedProductIds.removeAt(i);
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Collection'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category dialog (simplified placeholder)
class _CategoryDialog extends StatelessWidget {
  final Map<String, dynamic>? category;

  const _CategoryDialog({this.category});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(category == null ? 'New Category' : 'Edit Category'),
      content: const Text('Category management dialog - to be implemented'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Save')),
      ],
    );
  }
}

/// Product picker dialog (reused from original)
class _ProductPickerDialog extends StatefulWidget {
  const _ProductPickerDialog();

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Select Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search master products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('master_products').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: data['imageUrl'] != null
                            ? Image.network(data['imageUrl'], width: 40, height: 40, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 40),
                        title: Text(data['name'] ?? 'No Name'),
                        subtitle: Text(data['category'] ?? '-'),
                        onTap: () {
                          Navigator.pop(context, [
                            {'id': docs[index].id, 'name': (data['name'] ?? 'No Name').toString()}
                          ]);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
