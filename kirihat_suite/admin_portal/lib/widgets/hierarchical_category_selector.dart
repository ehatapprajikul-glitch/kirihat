import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Reusable widget for selecting categories from hierarchical tree structure
/// Used in product forms and anywhere category selection is needed
class HierarchicalCategorySelector extends StatefulWidget {
  final String? selectedCategoryId;
  final List<String>? selectedPath;
  final Function(String? categoryId, List<String> path, List<String> pathNames) onCategorySelected;
  final bool required;
  final String label;

  const HierarchicalCategorySelector({
    super.key,
    this.selectedCategoryId,
    this.selectedPath,
    required this.onCategorySelected,
    this.required = false,
    this.label = 'Category',
  });

  @override
  State<HierarchicalCategorySelector> createState() => _HierarchicalCategorySelectorState();
}

class _HierarchicalCategorySelectorState extends State<HierarchicalCategorySelector> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _selectedCategoryId;
  List<String> _selectedPath = [];
  List<String> _selectedPathNames = [];

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.selectedCategoryId;
    _selectedPath = widget.selectedPath ?? [];
    _loadSelectedPathNames();
  }

  Future<void> _loadSelectedPathNames() async {
    if (_selectedCategoryId == null) return;

    final doc = await _firestore.collection('categories').doc(_selectedCategoryId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _selectedPathNames = List<String>.from(data['path_names'] ?? []);
        _selectedPathNames.add(data['name']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display current selection with breadcrumb
        if (_selectedPathNames.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF0D9759), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedPathNames.join(' → '),
                    style: const TextStyle(
                      color: Color(0xFF0D9759),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      _selectedCategoryId = null;
                      _selectedPath = [];
                      _selectedPathNames = [];
                    });
                    widget.onCategorySelected(null, [], []);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

        // Select Category Button
        OutlinedButton.icon(
          onPressed: () => _showCategoryDialog(),
          icon: const Icon(Icons.account_tree),
          label: Text(_selectedCategoryId == null ? 'Select ${widget.label}' : 'Change ${widget.label}'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0D9759),
            side: BorderSide(
              color: widget.required && _selectedCategoryId == null ? Colors.red : Colors.grey,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        if (widget.required && _selectedCategoryId == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              '${widget.label} is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: _CategoryTreeSelector(
            currentSelectedId: _selectedCategoryId,
            onCategorySelected: (categoryId, path, pathNames) {
              setState(() {
                _selectedCategoryId = categoryId;
                _selectedPath = path;
                _selectedPathNames = pathNames;
              });
              widget.onCategorySelected(categoryId, path, pathNames);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryTreeSelector extends StatefulWidget {
  final String? currentSelectedId;
  final Function(String categoryId, List<String> path, List<String> pathNames) onCategorySelected;

  const _CategoryTreeSelector({
    this.currentSelectedId,
    required this.onCategorySelected,
  });

  @override
  State<_CategoryTreeSelector> createState() => _CategoryTreeSelectorState();
}

class _CategoryTreeSelectorState extends State<_CategoryTreeSelector> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentParentId;
  List<String> _breadcrumbIds = [];
  List<String> _breadcrumbNames = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.account_tree, color: Color(0xFF0D9759)),
            const SizedBox(width: 12),
            const Text(
              'Select Category',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 8),

        // Breadcrumb
        _buildBreadcrumb(),
        const SizedBox(height: 16),

        // Category List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('categories')
                .where('parent_id', isEqualTo: _currentParentId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Handle index creation error
              if (snapshot.hasError) {
                final errorMessage = snapshot.error.toString();
                // Extract index creation URL if present
                String? indexUrl;
                if (errorMessage.contains('https://console.firebase.google.com')) {
                  final urlMatch = RegExp(r'https://console\.firebase\.google\.com[^\s\)]+').firstMatch(errorMessage);
                  if (urlMatch != null) {
                    indexUrl = urlMatch.group(0);
                  }
                }

                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange[700]),
                        const SizedBox(height: 16),
                        const Text(
                          'Firestore Index Required',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This category query requires a Firestore index.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (indexUrl != null)
                          ElevatedButton.icon(
                            onPressed: () {
                              html.window.open(indexUrl!, '_blank');
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Create Index Automatically'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                          )
                        else
                          const Text('Check console for index URL'),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _currentParentId == null
                            ? 'No categories available'
                            : 'This category has no subcategories.\nYou can select it directly.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              // Sort by sort_order in memory to avoid composite index requirement
              var categories = snapshot.data!.docs.toList();
              categories.sort((a, b) {
                final aOrder = (a.data() as Map<String, dynamic>)['sort_order'] ?? 0;
                final bOrder = (b.data() as Map<String, dynamic>)['sort_order'] ?? 0;
                return aOrder.compareTo(bOrder);
              });

              return ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final doc = categories[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unnamed';
                  final iconUrl = data['icon'];
                  final level = data['level'] ?? 0;
                  final path = List<String>.from(data['path'] ?? []);
                  final pathNames = List<String>.from(data['path_names'] ?? []);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: iconUrl != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(iconUrl),
                              onBackgroundImageError: (_, __) {},
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              child: const Icon(Icons.folder, color: Colors.grey),
                            ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('Level $level'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Color(0xFF0D9759)),
                            onPressed: () {
                              // Select this category
                              final fullPath = [...path, doc.id];
                              final fullPathNames = [...pathNames, name];
                              widget.onCategorySelected(doc.id, fullPath, fullPathNames);
                            },
                            tooltip: 'Select this category',
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward, color: Colors.grey),
                            onPressed: () {
                              // Navigate into this category
                              setState(() {
                                _breadcrumbIds.add(doc.id);
                                _breadcrumbNames.add(name);
                                _currentParentId = doc.id;
                              });
                            },
                            tooltip: 'View subcategories',
                          ),
                        ],
                      ),
                      selected: widget.currentSelectedId == doc.id,
                      selectedTileColor: Colors.green[50],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Footer hint
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Click ✓ to select a category, or → to explore its subcategories',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    if (_breadcrumbNames.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.home, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              'Root Level',
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Home button
          InkWell(
            onTap: () {
              setState(() {
                _currentParentId = null;
                _breadcrumbIds.clear();
                _breadcrumbNames.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home, size: 14, color: Colors.grey[700]),
                  const SizedBox(width: 4),
                  Text('Root', style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
          ),
          // Breadcrumb items
          for (int i = 0; i < _breadcrumbNames.length; i++) ...[
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _breadcrumbNames[i],
                  style: TextStyle(
                    color: i < _breadcrumbNames.length - 1 ? Colors.blue : const Color(0xFF0D9759),
                    fontWeight: i < _breadcrumbNames.length - 1 ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
