import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../services/cloudinary_service.dart';

class HeroCategoryManagementScreen extends StatefulWidget {
  const HeroCategoryManagementScreen({super.key});

  @override
  State<HeroCategoryManagementScreen> createState() => _HeroCategoryManagementScreenState();
}

class _HeroCategoryManagementScreenState extends State<HeroCategoryManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Expansion state tracking
  final Map<String, bool> _expandedHeros = {};
  final Map<String, bool> _expandedCategories = {};
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hero Categories'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('hero_categories').orderBy('position').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final heroCats = snapshot.data!.docs;

          if (heroCats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No hero categories yet', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Hero Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue[50],
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Hero categories group regular categories together. Drag to reorder.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              
              // List
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: heroCats.length,
                  onReorder: (oldIndex, newIndex) => _reorderHeroCategories(heroCats, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final data = heroCats[index].data() as Map<String, dynamic>;
                    final docId = heroCats[index].id;
                    
                    return _buildHeroCategoryCard(docId, data, index, key: ValueKey(docId));
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Hero Category'),
      ),
    );
  }

  Widget _buildHeroCategoryCard(String docId, Map<String, dynamic> data, int index, {required Key key}) {
    String name = data['name'] ?? 'Unnamed';
    String? iconUrl = data['icon_url'];
    int position = data['position'] ?? index;
    List<String> categoryIds = List<String>.from(data['category_ids'] ?? []);
    bool isExpanded = _expandedHeros[docId] ?? false;

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Hero Header
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_handle, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    image: iconUrl != null
                        ? DecorationImage(image: NetworkImage(iconUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: iconUrl == null
                      ? const Icon(Icons.category, color: Colors.grey)
                      : null,
                ),
              ],
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${categoryIds.length} categories | Position: ${position + 1}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _expandedHeros[docId] = !isExpanded;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showAddEditDialog(docId: docId, existingData: data),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteHeroCategory(docId, name),
                ),
              ],
            ),
          ),
          
          // Expandable Categories Section
          if (isExpanded)
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(16),
              child: categoryIds.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No categories assigned',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : _buildCategoriesList(docId, categoryIds),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(String heroId, List<String> categoryIds) {
    // Safety check - should not happen but prevents errors
    if (categoryIds.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('categories')
          .where(FieldPath.documentId, whereIn: categoryIds)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Sort categories by the order in categoryIds
        final categories = snapshot.data!.docs;
        categories.sort((a, b) {
          final aIndex = categoryIds.indexOf(a.id);
          final bIndex = categoryIds.indexOf(b.id);
          return aIndex.compareTo(bIndex);
        });

        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          onReorder: (oldIndex, newIndex) => _reorderCategoriesInHero(heroId, categoryIds, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final categoryDoc = categories[index];
            final categoryData = categoryDoc.data() as Map<String, dynamic>;
            final categoryId = categoryDoc.id;
            
            return _buildCategoryCard(heroId, categoryId, categoryData, index, key: ValueKey(categoryId));
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(String heroId, String categoryId, Map<String, dynamic> data, int index, {required Key key}) {
    String name = data['name'] ?? 'Unnamed';
    String? iconUrl = data['icon_url'];
    bool isExpanded = _expandedCategories['$heroId-$categoryId'] ?? false;

    return Card(
      key: key,
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_handle, size: 20, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                    image: iconUrl != null
                        ? DecorationImage(image: NetworkImage(iconUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: iconUrl == null
                      ? const Icon(Icons.category_outlined, size: 20, color: Colors.grey)
                      : null,
                ),
              ],
            ),
            title: Text(name, style: const TextStyle(fontSize: 14)),
            subtitle: Text('Position ${index + 1}', style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
              onPressed: () {
                setState(() {
                  _expandedCategories['$heroId-$categoryId'] = !isExpanded;
                });
              },
            ),
          ),
          
          // Expandable Subcategories Section
          if (isExpanded)
            Container(
              color: Colors.blue[50],
              padding: const EdgeInsets.all(12),
              child: _buildSubcategoriesList(categoryId),
            ),
        ],
      ),
    );
  }

  Widget _buildSubcategoriesList(String categoryId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('subcategories')
          .where('category_id', isEqualTo: categoryId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final subcategories = snapshot.data!.docs;
        
        // Sort by position if it exists, otherwise by document ID
        subcategories.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aPos = aData['position'] ?? 99999;
          final bPos = bData['position'] ?? 99999;
          return aPos.compareTo(bPos);
        });

        if (subcategories.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No subcategories',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          );
        }

        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subcategories.length,
          onReorder: (oldIndex, newIndex) => _reorderSubcategories(subcategories, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final subcategoryDoc = subcategories[index];
            final subcategoryData = subcategoryDoc.data() as Map<String, dynamic>;
            final subcategoryId = subcategoryDoc.id;
            final name = subcategoryData['name'] ?? 'Unnamed';
            
            return ListTile(
              key: ValueKey(subcategoryId),
              dense: true,
              leading: Icon(Icons.drag_handle, size: 16, color: Colors.grey[400]),
              title: Text(name, style: const TextStyle(fontSize: 13)),
              subtitle: Text('Position ${index + 1}', style: const TextStyle(fontSize: 11)),
              tileColor: Colors.white,
            );
          },
        );
      },
    );
  }

  Future<void> _reorderHeroCategories(List<QueryDocumentSnapshot> docs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    
    final batch = _firestore.batch();
    
    // Update positions
    for (int i = 0; i < docs.length; i++) {
      int newPosition = i;
      if (i == oldIndex) {
        newPosition = newIndex;
      } else if (oldIndex < newIndex && i > oldIndex && i <= newIndex) {
        newPosition = i - 1;
      } else if (newIndex < oldIndex && i >= newIndex && i < oldIndex) {
        newPosition = i + 1;
      }
      
      batch.update(docs[i].reference, {'position': newPosition});
    }
    
    await batch.commit();
  }

  Future<void> _reorderCategoriesInHero(String heroId, List<String> categoryIds, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    
    // Reorder the category IDs array
    final List<String> reorderedIds = List.from(categoryIds);
    final item = reorderedIds.removeAt(oldIndex);
    reorderedIds.insert(newIndex, item);
    
    // Update the hero_categories document with new order
    await _firestore.collection('hero_categories').doc(heroId).update({
      'category_ids': reorderedIds,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reorderSubcategories(List<QueryDocumentSnapshot> docs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    
    final batch = _firestore.batch();
    
    // Update positions for all subcategories
    for (int i = 0; i < docs.length; i++) {
      int newPosition = i;
      if (i == oldIndex) {
        newPosition = newIndex;
      } else if (oldIndex < newIndex && i > oldIndex && i <= newIndex) {
        newPosition = i - 1;
      } else if (newIndex < oldIndex && i >= newIndex && i < oldIndex) {
        newPosition = i + 1;
      }
      
      batch.update(docs[i].reference, {'position': newPosition});
    }
    
    await batch.commit();
  }


  Future<void> _showAddEditDialog({String? docId, Map<String, dynamic>? existingData}) async {
    final nameController = TextEditingController(text: existingData?['name']);
    String? iconUrl = existingData?['icon_url'];
    Uint8List? selectedImageBytes;
    List<String> selectedCategoryIds = List<String>.from(existingData?['category_ids'] ?? []);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(docId == null ? 'Add Hero Category' : 'Edit Hero Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Icon Upload
                const Text('Icon:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      selectedImageBytes = await image.readAsBytes();
                      setState(() {});
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
                              Text('Upload Icon', style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Category Selection
                const Text('Assign Categories:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final selected = await _showCategorySelectionDialog(selectedCategoryIds);
                    if (selected != null) {
                      setState(() => selectedCategoryIds = selected);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text('${selectedCategoryIds.length} selected'),
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
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }

                // Upload icon if new image selected
                String? finalIconUrl = iconUrl;
                if (selectedImageBytes != null) {
                  finalIconUrl = await CloudinaryService.uploadImage(selectedImageBytes!, folder: 'hero_categories');
                }

                final data = {
                  'name': nameController.text,
                  'icon_url': finalIconUrl,
                  'category_ids': selectedCategoryIds,
                  'updated_at': FieldValue.serverTimestamp(),
                };

                if (docId == null) {
                  // Create new
                  final count = await _firestore.collection('hero_categories').count().get();
                  data['position'] = count.count;
                  data['created_at'] = FieldValue.serverTimestamp();
                  await _firestore.collection('hero_categories').add(data);
                } else {
                  // Update existing
                  await _firestore.collection('hero_categories').doc(docId).update(data);
                }

                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>?> _showCategorySelectionDialog(List<String> currentSelection) async {
    List<String> tempSelection = List.from(currentSelection);

    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Categories'),
          content: SizedBox(
            width: 400,
            height: 500,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('categories').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final categories = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final doc = categories[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final catId = doc.id;
                    final name = data['name'] ?? 'Unnamed';
                    final isSelected = tempSelection.contains(catId);

                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(name),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelection.add(catId);
                          } else {
                            tempSelection.remove(catId);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, tempSelection),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteHeroCategory(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hero Category?'),
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
      await _firestore.collection('hero_categories').doc(docId).delete();
    }
  }
}
