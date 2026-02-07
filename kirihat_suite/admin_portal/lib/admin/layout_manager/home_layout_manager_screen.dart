import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/services/home_layout_service.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import 'package:kirihat_core/services/hero_category_service.dart';

class HomeLayoutManagerScreen extends StatefulWidget {
  const HomeLayoutManagerScreen({super.key});

  @override
  State<HomeLayoutManagerScreen> createState() => _HomeLayoutManagerScreenState();
}

class _HomeLayoutManagerScreenState extends State<HomeLayoutManagerScreen> {
  final HomeLayoutService _layoutService = HomeLayoutService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<LayoutModel> _layouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  void _loadLayouts() {
    setState(() => _isLoading = true);
    
    _layoutService.getAdminLayouts().listen((layouts) {
      if (mounted) {
        setState(() {
          _layouts = layouts;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Layout Manager'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showAddLayoutDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Layout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D9759),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left: Layout List (Drag & Drop)
                Expanded(
                  flex: 2,
                  child: _buildLayoutList(),
                ),
                
                // Divider
                const VerticalDivider(width: 1),
                
                // Right: Live Preview
                Expanded(
                  flex: 3,
                  child: _buildPreview(),
                ),
              ],
            ),
    );
  }

  Widget _buildLayoutList() {
    if (_layouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dashboard_customize_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No layouts created yet'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _showAddLayoutDialog,
              child: const Text('Create First Layout'),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      onReorder: _onReorder,
      itemCount: _layouts.length,
      itemBuilder: (context, index) {
        final layout = _layouts[index];
        return _buildLayoutCard(layout, index);
      },
    );
  }

  Widget _buildLayoutCard(LayoutModel layout, int index) {
    return Card(
      key: ValueKey(layout.id),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 8),
            Icon(_getLayoutIcon(layout.type), color: const Color(0xFF0D9759)),
          ],
        ),
        title: Text(
          layout.title.isEmpty ? layout.type.name.toUpperCase() : layout.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Position: ${layout.position} • Type: ${layout.type.name}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: layout.active,
              onChanged: (value) => _toggleActive(layout, value),
              activeColor: const Color(0xFF0D9759),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditDialog(layout),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteLayout(layout),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final activeLayouts = _layouts.where((l) => l.active).toList();

    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.phone_android, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Live Preview (Customer App)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${activeLayouts.length} active layouts',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: activeLayouts.isEmpty
                ? const Center(
                    child: Text(
                      'No active layouts to preview',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: activeLayouts.length,
                    itemBuilder: (context, index) {
                      return _buildPreviewItem(activeLayouts[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(LayoutModel layout) {
    switch (layout.type) {
      case LayoutType.banner:
        return Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[300]!),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.view_carousel, size: 40, color: Colors.blue),
                SizedBox(height: 8),
                Text('Banner Carousel', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      
      case LayoutType.productRow:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                layout.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Product Row (${layout.data['filter'] ?? 'trending'})',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        );
      
      case LayoutType.categoryGrid:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                layout.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: List.generate(6, (index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.category, color: Colors.grey),
                  );
                }),
              ),
            ],
          ),
        );
      
      case LayoutType.heroSection:
        return Container(
          height: 200,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.purple[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple[300]!),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 40, color: Colors.purple),
                SizedBox(height: 8),
                Text('Hero Section', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      
      default:
        return Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(layout.type.name)),
        );
    }
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex--;
    
    setState(() {
      final layout = _layouts.removeAt(oldIndex);
      _layouts.insert(newIndex, layout);
    });

    // Update positions in Firestore
    for (int i = 0; i < _layouts.length; i++) {
      await _firestore
          .collection('home_layouts')
          .doc(_layouts[i].id)
          .update({'position': i});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Layout order updated')),
    );
  }

  void _toggleActive(LayoutModel layout, bool value) async {
    await _firestore
        .collection('home_layouts')
        .doc(layout.id)
        .update({'active': value});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Layout ${value ? 'activated' : 'deactivated'}')),
    );
  }

  void _deleteLayout(LayoutModel layout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Layout'),
        content: Text('Are you sure you want to delete "${layout.title.isEmpty ? layout.type.name : layout.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('home_layouts').doc(layout.id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layout deleted')),
      );
    }
  }

  void _showAddLayoutDialog() {
    showDialog(
      context: context,
      builder: (context) => const LayoutEditorDialog(),
    );
  }

  void _showEditDialog(LayoutModel layout) {
    showDialog(
      context: context,
      builder: (context) => LayoutEditorDialog(layout: layout),
    );
  }

  IconData _getLayoutIcon(LayoutType type) {
    switch (type) {
      case LayoutType.banner: return Icons.view_carousel;
      case LayoutType.productRow: return Icons.view_list;
      case LayoutType.categoryGrid: return Icons.grid_view;
      case LayoutType.heroSection: return Icons.image;
      case LayoutType.searchSection: return Icons.search;
      default: return Icons.widgets;
    }
  }
}

// Layout Editor Dialog
class LayoutEditorDialog extends StatefulWidget {
  final LayoutModel? layout;

  const LayoutEditorDialog({super.key, this.layout});

  @override
  State<LayoutEditorDialog> createState() => _LayoutEditorDialogState();
}

class _LayoutEditorDialogState extends State<LayoutEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late LayoutType _selectedType;
  late TextEditingController _titleController;
  late bool _active;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _selectedType = widget.layout?.type ?? LayoutType.banner;
    _titleController = TextEditingController(text: widget.layout?.title ?? '');
    _active = widget.layout?.active ?? true;
    _data = Map.from(widget.layout?.data ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.layout == null ? 'Add Layout' : 'Edit Layout'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<LayoutType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Layout Type',
                    border: OutlineInputBorder(),
                  ),
                  items: LayoutType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Trending Products',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: const Text('Active'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  activeColor: const Color(0xFF0D9759),
                ),
                
                const SizedBox(height: 16),
                
                // Type-specific configuration
                if (_selectedType == LayoutType.productRow)
                  _buildProductRowConfig(),
                if (_selectedType == LayoutType.categoryGrid)
                  _buildCategoryGridConfig(),
                if (_selectedType == LayoutType.heroSection)
                  _buildHeroSectionConfig(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveLayout,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9759),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildProductRowConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Row Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _data['filter'] ?? 'trending',
          decoration: const InputDecoration(
            labelText: 'Product Filter',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'trending', child: Text('Trending')),
            DropdownMenuItem(value: 'new', child: Text('New Arrivals')),
            DropdownMenuItem(value: 'deals', child: Text('Best Deals')),
            DropdownMenuItem(value: 'collection', child: Text('Specific Collection')),
            DropdownMenuItem(value: 'products', child: Text('Specific Products')),
          ],
          onChanged: (value) => setState(() => _data['filter'] = value),
        ),
        
        // Conditional Collection Dropdown
        if (_data['filter'] == 'collection') ...[
          const SizedBox(height: 12),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('product_collections').orderBy('name').get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No collections found', style: TextStyle(color: Colors.red));
              }

              final collections = snapshot.data!.docs.map((doc) {
                 final data = doc.data() as Map<String, dynamic>;
                 return {
                   'id': doc.id,
                   'name': data['name'] ?? 'Unnamed',
                 };
              }).toList();
  
              return DropdownButtonFormField<String>(
                value: _data['collection_id'],
                hint: const Text('Select Collection'),
                decoration: const InputDecoration(
                  labelText: 'Collection',
                  border: OutlineInputBorder(),
                ),
                items: collections.map((Map<String, dynamic> col) {
                  return DropdownMenuItem<String>(
                    value: col['id'],
                    child: Text(col['name']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _data['collection_id'] = value),
              );
            },
          ),
        ],

        if (_data['filter'] == 'products') ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showProductSelectionDialog,
            icon: const Icon(Icons.playlist_add),
            label: Text('Select Products (${(_data['product_ids'] as List?)?.length ?? 0})'),
          ),
          if ((_data['product_ids'] as List?)?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: ((_data['product_ids'] as List).cast<String>()).map((id) {
                  return Chip(
                    label: Text(id.length > 6 ? '${id.substring(0, 6)}...' : id),
                    onDeleted: () {
                      setState(() {
                         (_data['product_ids'] as List).remove(id);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
        ],

        const SizedBox(height: 12),
        TextFormField(
          initialValue: (_data['limit'] ?? 10).toString(),
          decoration: const InputDecoration(
            labelText: 'Product Limit',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) => _data['limit'] = int.tryParse(value) ?? 10,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Show "View All" Button'),
          value: _data['show_view_all'] ?? true,
          onChanged: (value) => setState(() => _data['show_view_all'] = value),
        ),
      ],
    );
  }

  Widget _buildCategoryGridConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category Grid Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: HeroCategoryService().getAdminHeroCategories(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            
            return DropdownButtonFormField<String>(
              value: _data['hero_category_id'],
              decoration: const InputDecoration(
                labelText: 'Hero Category',
                border: OutlineInputBorder(),
              ),
              items: snapshot.data!.map<DropdownMenuItem<String>>((cat) {
                return DropdownMenuItem<String>(
                  value: cat['id'],
                  child: Text(cat['name']),
                );
              }).toList(),
              onChanged: (value) => setState(() => _data['hero_category_id'] = value),
            );
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _data['columns'] ?? 3,
          decoration: const InputDecoration(
            labelText: 'Columns',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 2, child: Text('2 Columns')),
            DropdownMenuItem(value: 3, child: Text('3 Columns')),
            DropdownMenuItem(value: 4, child: Text('4 Columns')),
          ],
          onChanged: (value) => setState(() => _data['columns'] = value),
        ),
      ],
    );
  }

  Widget _buildHeroSectionConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hero Section Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _data['image_url'] ?? '',
          decoration: const InputDecoration(
            labelText: 'Image URL',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _data['image_url'] = value,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _data['cta_text'] ?? 'Shop Now',
          decoration: const InputDecoration(
            labelText: 'CTA Button Text',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _data['cta_text'] = value,
        ),
      ],
    );
  }

  Future<void> _saveLayout() async {
    if (!_formKey.currentState!.validate()) return;

    final layoutData = {
      'type': _selectedType.name,
      'title': _titleController.text,
      'active': _active,
      'vendor_id': null, // Admin global
      'data': _data,
      'updated_at': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.layout == null) {
        // Create new
        final maxPosition = await _getMaxPosition();
        layoutData['position'] = maxPosition + 1;
        layoutData['created_at'] = FieldValue.serverTimestamp();
        
        await FirebaseFirestore.instance
            .collection('home_layouts')
            .add(layoutData);
      } else {
        // Update existing
        layoutData['position'] = widget.layout!.position;
        await FirebaseFirestore.instance
            .collection('home_layouts')
            .doc(widget.layout!.id)
            .update(layoutData);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Layout ${widget.layout == null ? 'created' : 'updated'}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<int> _getMaxPosition() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('home_layouts')
        .orderBy('position', descending: true)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return 0;
    return snapshot.docs.first.data()['position'] ?? 0;
  }

  void _showProductSelectionDialog() async {
    final selectedIds = (_data['product_ids'] as List?)?.cast<String>() ?? [];
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => ProductSelectionDialog(initialSelection: selectedIds),
    );

    if (result != null) {
      setState(() {
        _data['product_ids'] = result;
      });
    }
  }
}

class ProductSelectionDialog extends StatefulWidget {
  final List<String> initialSelection;

  const ProductSelectionDialog({super.key, required this.initialSelection});

  @override
  State<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<ProductSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _products = [];
  Set<String> _selectedIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelection.toSet();
    _searchProducts();
  }

  void _searchProducts() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance.collection('master_products').limit(20);
      
      if (_searchController.text.trim().isNotEmpty) {
        final term = _searchController.text.trim();
        query = query.where('name', isGreaterThanOrEqualTo: term)
            .where('name', isLessThan: term + 'z');
      }

      final snapshot = await query.get();
      setState(() {
        _products = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Products'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products (case sensitive)...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchProducts,
                ),
              ),
              onSubmitted: (_) => _searchProducts(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                    ? const Center(child: Text('No products found'))
                    : ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final doc = _products[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final id = doc.id;
                        final isSelected = _selectedIds.contains(id);

                        return CheckboxListTile(
                          title: Text(data['name'] ?? 'Unnamed'),
                          subtitle: Text(data['category'] ?? ''),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedIds.toList()),
          child: Text('Select (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
