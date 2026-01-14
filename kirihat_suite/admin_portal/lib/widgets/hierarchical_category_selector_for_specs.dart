import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Hierarchical category selector specifically for specification manager
/// Shows nested tree structure where admin can select any category at any level
class HierarchicalCategorySelectorForSpecs extends StatefulWidget {
  final String? selectedCategoryId;
  final Function(String categoryId, String categoryName, List<String> path, List<String> pathNames, int level) onCategorySelected;

  const HierarchicalCategorySelectorForSpecs({
    super.key,
    this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  State<HierarchicalCategorySelectorForSpecs> createState() => _HierarchicalCategorySelectorForSpecsState();
}

class _HierarchicalCategorySelectorForSpecsState extends State<HierarchicalCategorySelectorForSpecs> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentParentId;
  List<String> _breadcrumbIds = [];
  List<String> _breadcrumbNames = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb navigation
        if (_breadcrumbNames.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentParentId = null;
                      _breadcrumbIds.clear();
                      _breadcrumbNames.clear();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home, size: 14, color: Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text('Root', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                for (int i = 0; i < _breadcrumbNames.length; i++) ...  [
                  Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
                  InkWell(
                    onTap: i < _breadcrumbNames.length - 1
                        ? () {
                            setState(() {
                              _currentParentId = _breadcrumbIds[i];
                              _breadcrumbIds = _breadcrumbIds.sublist(0, i + 1);
                              _breadcrumbNames = _breadcrumbNames.sublist(0, i + 1);
                            });
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        _breadcrumbNames[i],
                        style: TextStyle(
                          color: i < _breadcrumbNames.length - 1 ? Colors.blue : const Color(0xFF34A853),
                          fontWeight: i < _breadcrumbNames.length - 1 ? FontWeight.normal : FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Category list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _currentParentId == null
                ? _firestore
                    .collection('categories')
                    .where('parent_id', isEqualTo: null)
                    .snapshots()
                : _firestore
                    .collection('categories')
                    .where('parent_id', isEqualTo: _currentParentId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filter by level: Only show Level 0 categories at root
              var categories = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (_currentParentId == null) {
                  // At root, only show Level 0 categories
                  return (data['level'] ?? 0) == 0;
                }
                // For subcategories, show all direct children
                return true;
              }).toList();

              if (categories.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentParentId == null 
                              ? 'No root categories found (Level 0)' 
                              : 'No subcategories',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (_currentParentId == null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Only Level 0 categories are shown here',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              // Sort by sort_order, then by name
              
              categories.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                
                final aOrder = aData['sort_order'] ?? 0;
                final bOrder = bData['sort_order'] ?? 0;
                
                if (aOrder != bOrder) {
                  return aOrder.compareTo(bOrder);
                }
                
                final aName = aData['name'] ?? '';
                final bName = bData['name'] ?? '';
                return aName.compareTo(bName);
              });

              return _buildCategoryList(categories);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(List<QueryDocumentSnapshot> categories) {
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final doc = categories[index];
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'Unnamed';
        final iconUrl = data['icon'];
        final level = data['level'] ?? 0;
        final isSelected = widget.selectedCategoryId == doc.id;
        
        // Check if category has children
        return FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection('categories')
              .where('parent_id', isEqualTo: doc.id)
              .limit(1)
              .get(),
          builder: (context, childrenSnapshot) {
            final hasChildren = childrenSnapshot.hasData && childrenSnapshot.data!.docs.isNotEmpty;
            
            return ListTile(
              leading: iconUrl != null
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(iconUrl),
                      onBackgroundImageError: (_, __) {},
                    )
                  : CircleAvatar(
                      backgroundColor: isSelected ? const Color(0xFF34A853) : Colors.grey[300],
                      child: Icon(
                        hasChildren ? Icons.folder : Icons.folder_outlined,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF34A853) : Colors.black87,
                      ),
                    ),
                  ),
                  if (hasChildren)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_forward, size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 2),
                          Text(
                            'Has subcategories',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              subtitle: Text('Level $level'),
              selected: isSelected,
              selectedTileColor: const Color(0xFFE8F5E9),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Navigate into button (only show if has children)
                  if (hasChildren)
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () {
                        setState(() {
                          _breadcrumbIds.add(doc.id);
                          _breadcrumbNames.add(name);
                          _currentParentId = doc.id;
                        });
                      },
                      tooltip: 'View subcategories',
                      color: Colors.grey[600],
                    ),
                ],
              ),
              onTap: () {
                // Select this category for specification template
                widget.onCategorySelected(
                  doc.id,
                  name,
                  _breadcrumbIds, // path without the current category
                  _breadcrumbNames, // path names without current
                  level,
                );
              },
            );
          },
        );
      },
    );
  }
}
