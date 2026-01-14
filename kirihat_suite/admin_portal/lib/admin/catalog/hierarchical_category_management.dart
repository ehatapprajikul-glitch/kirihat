import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:kirihat_core/services/cloudinary_service.dart';
import '../setup/level_fix_script.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class HierarchicalCategoryManagement extends StatefulWidget {
  const HierarchicalCategoryManagement({super.key});

  @override
  State<HierarchicalCategoryManagement> createState() => _HierarchicalCategoryManagementState();
}

class _HierarchicalCategoryManagementState extends State<HierarchicalCategoryManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CategoryLevelFixer _levelFixer = CategoryLevelFixer();
  String? _selectedCategoryId;
  List<String> _breadcrumbIds = [];
  List<String> _breadcrumbNames = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Category Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Row(
                children: [
                  // Fix Levels Button
                  ElevatedButton.icon(
                    onPressed: _showLevelFixDialog,
                    icon: const Icon(Icons.build, size: 18),
                    label: const Text('Fix Levels'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Add Category Button
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(parentId: _selectedCategoryId),
                    icon: const Icon(Icons.add),
                    label: Text(_selectedCategoryId == null ? 'Add Root Category' : 'Add Child Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // INDEX SETUP BANNER - Test if index exists
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('categories')
              .where('parent_id', isEqualTo: null)
              .orderBy('sort_order')
              .limit(1)
              .snapshots(),
          builder: (context, testSnapshot) {
            if (testSnapshot.hasError) {
              final errorMsg = testSnapshot.error.toString();
              String? indexUrl;
              if (errorMsg.contains('https://console.firebase.google.com')) {
                final urlMatch = RegExp(r'https://console\.firebase\.google\.com[^\s\)]+').firstMatch(errorMsg);
                if (urlMatch != null) {
                  indexUrl = urlMatch.group(0);
                }
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Firestore Index Required',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click the button to create the required index for fast category queries →',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: indexUrl != null
                          ? () {
                              html.window.open(indexUrl!, '_blank');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✓ Opened Firebase Console. Click CREATE, then wait 1-2 minutes.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.launch, size: 18),
                      label: const Text('Create Index'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink(); // Hide when index exists
          },
        ),

        // Breadcrumb
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: _buildBreadcrumb(),
        ),

        // Category Tree View
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _selectedCategoryId == null
                ? _firestore
                    .collection('categories')
                    .where('parent_id', isEqualTo: null)
                    .snapshots()
                : _firestore
                    .collection('categories')
                    .where('parent_id', isEqualTo: _selectedCategoryId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading categories',
                          style: TextStyle(fontSize: 18, color: Colors.red[700]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filter by level: Only show Level 0 categories at root
              var categories = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (_selectedCategoryId == null) {
                  // At root, only show Level 0 categories
                  return (data['level'] ?? 0) == 0;
                }
                // For subcategories, show all direct children (they should have correct parent_id)
                return true;
              }).toList();

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

              return _buildCategoryGrid(categories);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(List<QueryDocumentSnapshot> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _selectedCategoryId == null 
                  ? 'No root categories yet (Level 0)' 
                  : 'No subcategories in this category',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_selectedCategoryId == null)
              Text(
                'Only Level 0 categories are shown here',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(parentId: _selectedCategoryId),
              icon: const Icon(Icons.add),
              label: Text(_selectedCategoryId == null ? 'Add First Root Category' : 'Add Subcategory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final doc = categories[index];
        final data = doc.data() as Map<String, dynamic>;
        return _buildCategoryCard(doc.id, data);
      },
    );
  }

  Widget _buildBreadcrumb() {
    if (_breadcrumbNames.isEmpty) {
      return Row(
        children: [
          Icon(Icons.home, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Root Categories',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Home button
        InkWell(
          onTap: () {
            setState(() {
              _selectedCategoryId = null;
              _breadcrumbIds.clear();
              _breadcrumbNames.clear();
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text('Root', style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
        ),
        // Breadcrumb items
        for (int i = 0; i < _breadcrumbNames.length; i++) ...[
          Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          InkWell(
            onTap: i < _breadcrumbNames.length - 1
                ? () {
                    setState(() {
                      _selectedCategoryId = _breadcrumbIds[i];
                      _breadcrumbIds = _breadcrumbIds.sublist(0, i + 1);
                      _breadcrumbNames = _breadcrumbNames.sublist(0, i + 1);
                    });
                  }
                : null,
            child: Padding(
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
    );
  }

  Widget _buildCategoryCard(String docId, Map<String, dynamic> data) {
    String name = data['name'] ?? 'Unnamed';
    String? iconUrl = data['icon'];
    int level = data['level'] ?? 0;
    bool hasChildren = false; // Will be checked asynchronously

    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('categories')
          .where('parent_id', isEqualTo: docId)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        hasChildren = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        
        return _CategoryCard(
          docId: docId,
          name: name,
          iconUrl: iconUrl,
          level: level,
          hasChildren: hasChildren,
          onEdit: () => _showAddEditDialog(docId: docId, existingData: data),
          onDelete: () => _deleteCategory(docId, name, data),
          onTap: () async {
            // Navigate into this category
            setState(() {
              _breadcrumbIds.add(docId);
              _breadcrumbNames.add(name);
              _selectedCategoryId = docId;
            });
          },
          onAddChild: () => _showAddEditDialog(parentId: docId),
        );
      },
    );
  }

  Future<void> _showAddEditDialog({String? docId, Map<String, dynamic>? existingData, String? parentId}) async {
    final nameController = TextEditingController(text: existingData?['name']);
    String? iconUrl = existingData?['icon'];
    Uint8List? selectedImageBytes;
    String? selectedParentId = existingData?['parent_id'] ?? parentId;
    
    // If editing, preserve original parent unless user changes it
    final isEditing = docId != null;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit : Icons.add,
                color: const Color(0xFF0D9759),
              ),
              const SizedBox(width: 12),
              Text(isEditing ? 'Edit Category' : 'Add Category'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // INDEX HEALTH CHECK INSIDE DIALOG
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('categories')
                        .where('parent_id', isEqualTo: 'index_check') // Match the composite index requirement
                        .orderBy('sort_order')
                        .limit(1)
                        .snapshots(),
                    builder: (context, testSnapshot) {
                      if (testSnapshot.hasError) {
                        final errorMsg = testSnapshot.error.toString();
                        String? indexUrl;
                        if (errorMsg.contains('https://console.firebase.google.com')) {
                          final urlMatch = RegExp(r'https://console\.firebase\.google\.com[^\s\)]+').firstMatch(errorMsg);
                          if (urlMatch != null) {
                            indexUrl = urlMatch.group(0);
                          }
                        }
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber, size: 20, color: Colors.orange[700]),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Database Setup Required',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'To create categories, you must first enable the index in Firebase.',
                                style: TextStyle(fontSize: 12),
                              ),
                              if (indexUrl != null) ...[ 
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      html.window.open(indexUrl!, '_blank');
                                    },
                                    icon: const Icon(Icons.open_in_new, size: 14),
                                    label: const Text('Click to Create Index', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Center(
                                  child: Text(
                                    'After clicking, wait 1-2 mins and reopen this dialog',
                                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Parent Category Selector
                  const Text('Parent Category:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildParentCategorySelector(
                    selectedParentId,
                    (newParentId) {
                      setDialogState(() {
                        selectedParentId = newParentId;
                      });
                    },
                    excludeId: docId, // Don't allow selecting self or descendants
                  ),
                  const SizedBox(height: 16),

                  // Name Field
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Electronics, Mobile Phone',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Icon Upload
                  const Text('Category Icon:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        selectedImageBytes = await image.readAsBytes();
                        setDialogState(() {});
                      }
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey),
                        image: selectedImageBytes != null
                            ? DecorationImage(image: MemoryImage(selectedImageBytes!), fit: BoxFit.cover)
                            : (iconUrl != null
                                ? DecorationImage(image: NetworkImage(iconUrl), fit: BoxFit.cover)
                                : null),
                      ),
                      child: selectedImageBytes == null && iconUrl == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                SizedBox(height: 4),
                                Text('Upload Icon', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Guidelines
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Image Guidelines',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('• Format: PNG or SVG (Transparent background pref.)', style: TextStyle(fontSize: 11)),
                        Text('• Size: 512x512px (Square 1:1)', style: TextStyle(fontSize: 11)),
                        Text('• Max size: 2MB', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a category name')),
                  );
                  return;
                }

                try {
                  // Upload icon if new image selected
                  String? finalIconUrl = iconUrl;
                  if (selectedImageBytes != null) {
                    finalIconUrl = await CloudinaryService.uploadImage(
                      selectedImageBytes!,
                      folder: 'categories',
                    );
                  }

                  // Calculate level and paths
                  int level = 0;
                  List<String> pathIds = [];
                  List<String> pathNames = [];

                  if (selectedParentId != null) {
                    final parentDoc = await _firestore.collection('categories').doc(selectedParentId).get();
                    if (parentDoc.exists) {
                      final parentData = parentDoc.data()!;
                      level = (parentData['level'] ?? 0) + 1;
                      pathIds = List<String>.from(parentData['path'] ?? []);
                      pathNames = List<String>.from(parentData['path_names'] ?? []);
                      pathIds.add(selectedParentId!);
                      pathNames.add(parentData['name']);
                    }
                  }

                  final data = {
                    'name': nameController.text.trim(),
                    'icon': finalIconUrl,
                    'parent_id': selectedParentId,
                    'level': level,
                    'path': pathIds,
                    'path_names': pathNames,
                    'updated_at': FieldValue.serverTimestamp(),
                    'isActive': true,
                  };

                  if (isEditing) {
                    // Update existing
                    await _firestore.collection('categories').doc(docId).update(data);
                    
                    // If parent changed, update all descendants
                    if (existingData!['parent_id'] != selectedParentId) {
                      await _updateDescendantPaths(docId!, nameController.text.trim());
                    }
                  } else {
                    // Create new - get max sort_order for this parent
                    final siblingsQuery = await _firestore
                        .collection('categories')
                        .where('parent_id', isEqualTo: selectedParentId)
                        .get();

                    // Sort in memory to avoid requiring composite index
                    int maxOrder = 0;
                    if (siblingsQuery.docs.isNotEmpty) {
                      var sortedDocs = siblingsQuery.docs.toList();
                      sortedDocs.sort((a, b) {
                        final aOrder = (a.data())['sort_order'] ?? 0;
                        final bOrder = (b.data())['sort_order'] ?? 0;
                        return bOrder.compareTo(aOrder); // descending
                      });
                      maxOrder = (sortedDocs.first.data())['sort_order'] ?? 0;
                    }

                    data['created_at'] = FieldValue.serverTimestamp();
                    data['sort_order'] = maxOrder + 1;

                    await _firestore.collection('categories').add(data);
                  }

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEditing ? 'Category updated!' : 'Category created!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentCategorySelector(String? selectedParentId, Function(String?) onChanged, {String? excludeId}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('categories').snapshots(),
      builder: (context, snapshot) {
        // Handle errors (index missing, etc.)
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

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Index Required',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Firestore index needed for category queries.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                
                if (indexUrl != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        html.window.open(indexUrl!, '_blank');
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Create Index'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                else
                  const Text(
                    'Check console for index creation link',
                    style: TextStyle(fontSize: 11),
                  ),
                
                const SizedBox(height: 8),
                Text(
                  'After creating, wait 1-2 minutes',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        List<DropdownMenuItem<String>> items = [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Root Level (No Parent)'),
          ),
        ];

        // Filter and sort categories
        var categories = snapshot.data!.docs.where((doc) {
          // Exclude the category being edited and its descendants
          if (excludeId != null && doc.id == excludeId) {
            return false;
          }
          return true;
        }).toList();

        // Sort by level first, then by name
        categories.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aLevel = aData['level'] ?? 0;
          final bLevel = bData['level'] ?? 0;
          
          if (aLevel != bLevel) {
            return aLevel.compareTo(bLevel);
          }
          
          final aName = aData['name'] ?? '';
          final bName = bData['name'] ?? '';
          return aName.compareTo(bName);
        });

        for (var doc in categories) {
          final data = doc.data() as Map<String, dynamic>;
          final pathNames = data['path_names'] != null ? List<String>.from(data['path_names']) : <String>[];
          final name = data['name'] ?? 'Unnamed';
          final level = data['level'] ?? 0;

          String displayName;
          if (pathNames.isNotEmpty) {
            displayName = '${'  ' * level}${pathNames.join(' > ')} > $name';
          } else {
            displayName = '${'  ' * level}$name';
          }

          items.add(
            DropdownMenuItem<String>(
              value: doc.id,
              child: Text(displayName, overflow: TextOverflow.ellipsis),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedParentId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: items,
          onChanged: onChanged,
          isExpanded: true,
        );
      },
    );
  }

  bool _isDescendant(String potentialDescendantId, String ancestorId) {
    // This is a placeholder - in practice, you'd check the path array
    return false; // TODO: Implement proper descendant check
  }

  Future<void> _updateDescendantPaths(String categoryId, String newName) async {
    // Get the updated category to build new path
    final categoryDoc = await _firestore.collection('categories').doc(categoryId).get();
    if (!categoryDoc.exists) return;

    final categoryData = categoryDoc.data()!;
    final newPath = List<String>.from(categoryData['path'] ?? []);
    newPath.add(categoryId);
    final newPathNames = List<String>.from(categoryData['path_names'] ?? []);
    newPathNames.add(newName);

    // Find all children
    final children = await _firestore
        .collection('categories')
        .where('parent_id', isEqualTo: categoryId)
        .get();

    final batch = _firestore.batch();
    for (var child in children.docs) {
      batch.update(child.reference, {
        'path': newPath,
        'path_names': newPathNames,
        'level': newPathNames.length,
      });
    }

    await batch.commit();

    // Recursively update grandchildren
    for (var child in children.docs) {
      await _updateDescendantPaths(child.id, child.data()['name']);
    }
  }

  Future<void> _deleteCategory(String docId, String name, Map<String, dynamic> data) async {
    // Check if has children
    final childrenQuery = await _firestore
        .collection('categories')
        .where('parent_id', isEqualTo: docId)
        .limit(1)
        .get();

    if (childrenQuery.docs.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: Text('Category "$name" has subcategories. Please delete them first or move them to another category.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "$name"?'),
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
      await _firestore.collection('categories').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category "$name" deleted')),
        );
      }
    }
  }
  // Level fix dialog
  Future<void> _showLevelFixDialog() async {
    // First, get the stats
    final stats = await _levelFixer.getCategoryLevelStats();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.build, color: Colors.orange),
            SizedBox(width: 12),
            Text('Fix Category Levels'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This tool will recalculate all category levels based on their parent relationships.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                
                // Stats display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: stats.hasIssues ? Colors.orange[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: stats.hasIssues ? Colors.orange : Colors.green,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            stats.hasIssues ? Icons.warning : Icons.check_circle,
                            color: stats.hasIssues ? Colors.orange : Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            stats.hasIssues ? 'Issues Found' : 'All Levels Correct',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: stats.hasIssues ? Colors.orange : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Total Categories: ${stats.totalCategories}'),
                      const SizedBox(height: 8),
                      const Text('Distribution:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ...stats.levelCounts.entries.map((entry) => 
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: Text('Level ${entry.key}: ${entry.value} categories'),
                        ),
                      ),
                      
                      if (stats.hasIssues) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const Text(
                          'Problems:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        if (stats.rootCategoriesWithWrongLevel > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠ ${stats.rootCategoriesWithWrongLevel} root categories have wrong level',
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        if (stats.childrenWithWrongLevel > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠ ${stats.childrenWithWrongLevel} child categories marked as level 0',
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        if (stats.categoriesWithoutLevel > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠ ${stats.categoriesWithoutLevel} categories missing level field',
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (stats.hasIssues)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Fixing category levels...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                // Run the fix
                final fixResult = await _levelFixer.fixAllCategoryLevels();

                if (mounted) {
                  Navigator.pop(context); // Close loading dialog

                  // Show result
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        fixResult.success 
                            ? '✓ Fixed ${fixResult.updatedCategories} categories!'
                            : '✗ Error: ${fixResult.message}',
                      ),
                      backgroundColor: fixResult.success ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );

                  // Refresh the view
                  setState(() {});
                }
              },
              icon: const Icon(Icons.build),
              label: const Text('Fix Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.check_circle),
              label: const Text('All Good!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String docId;
  final String name;
  final String? iconUrl;
  final int level;
  final bool hasChildren;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onAddChild;

  const _CategoryCard({
    required this.docId,
    required this.name,
    required this.iconUrl,
    required this.level,
    this.hasChildren = false,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    required this.onAddChild,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? const Color(0xFF0D9759) : Colors.grey.shade200,
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Image Container
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        image: widget.iconUrl != null
                            ? DecorationImage(
                                image: NetworkImage(widget.iconUrl!),
                                fit: BoxFit.cover,
                                onError: (_, __) {},
                              )
                            : null,
                      ),
                      child: widget.iconUrl == null
                          ? const Center(
                              child: Icon(Icons.folder, size: 48, color: Colors.grey),
                            )
                          : null,
                    ),
                  ),
                  // Category Name
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Level ${widget.level}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (widget.hasChildren) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Overlay Action Buttons
              if (_isHovered)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    children: [
                      _buildActionButton(
                        icon: Icons.add,
                        tooltip: 'Add Child',
                        color: const Color(0xFF0D9759),
                        onPressed: widget.onAddChild,
                      ),
                      const SizedBox(height: 4),
                      _buildActionButton(
                        icon: Icons.edit,
                        tooltip: 'Edit',
                        color: Colors.blue,
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(height: 4),
                      _buildActionButton(
                        icon: Icons.delete,
                        tooltip: 'Delete',
                        color: Colors.red,
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ),
              // Click-to-navigate indicator
              if (_isHovered)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9759).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Open',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: () {
          onPressed();
          // Prevent card tap event from firing
        },
        color: color,
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }


}
