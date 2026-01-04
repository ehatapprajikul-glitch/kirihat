import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../services/cloudinary_service.dart';
import 'subcategory_products_view.dart';

class SubcategoryManagementScreen extends StatefulWidget {
  const SubcategoryManagementScreen({super.key});

  @override
  State<SubcategoryManagementScreen> createState() => _SubcategoryManagementScreenState();
}

class _SubcategoryManagementScreenState extends State<SubcategoryManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subcategory Management'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Category Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('categories').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final categories = snapshot.data!.docs;
                
                return DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Select Category',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: categories.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Unnamed'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategoryId = value);
                  },
                );
              },
            ),
          ),

          // Subcategories List
          Expanded(
            child: _selectedCategoryId == null
                ? const Center(
                    child: Text(
                      'Please select a category to view subcategories',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('subcategories')
                        .where('category_id', isEqualTo: _selectedCategoryId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final subcats = snapshot.data!.docs;

                      if (subcats.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_outlined, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              const Text('No subcategories yet', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Subcategory'),
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
                        itemCount: subcats.length,
                        itemBuilder: (context, index) {
                          final doc = subcats[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          return _buildSubcategoryCard(doc.id, data);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedCategoryId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditDialog(),
              backgroundColor: const Color(0xFF0D9759),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Subcategory'),
            )
          : null,
    );
  }

  Widget _buildSubcategoryCard(String docId, Map<String, dynamic> data) {
    String name = data['name'] ?? 'Unnamed';
    String? iconUrl = data['icon_url'];

    return _SubcategoryCard(
      docId: docId,
      name: name,
      iconUrl: iconUrl,
      onEdit: () => _showAddEditDialog(docId: docId, existingData: data),
      onDelete: () => _deleteSubcategory(docId, name),
      onTap: () async {
        // Get category name from ID
        if (_selectedCategoryId != null) {
          final catDoc = await _firestore.collection('categories').doc(_selectedCategoryId).get();
          if (catDoc.exists && mounted) {
            String categoryName = catDoc.data()?['name'] ?? 'Unknown';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubcategoryProductsView(
                  categoryName: categoryName,
                  subcategoryName: name,
                ),
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _showAddEditDialog({String? docId, Map<String, dynamic>? existingData}) async {
    final nameController = TextEditingController(text: existingData?['name']);
    String? iconUrl = existingData?['icon_url'];
    Uint8List? selectedImageBytes;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(docId == null ? 'Add Subcategory' : 'Edit Subcategory'),
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
                  finalIconUrl = await CloudinaryService.uploadImage(
                    selectedImageBytes!,
                    folder: 'subcategories',
                  );
                }

                final data = {
                  'name': nameController.text,
                  'icon_url': finalIconUrl,
                  'category_id': _selectedCategoryId,
                  'updated_at': FieldValue.serverTimestamp(),
                };

                if (docId == null) {
                  // Create new
                  data['created_at'] = FieldValue.serverTimestamp();
                  await _firestore.collection('subcategories').add(data);
                } else {
                  // Update existing
                  await _firestore.collection('subcategories').doc(docId).update(data);
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

  Future<void> _deleteSubcategory(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subcategory?'),
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
      await _firestore.collection('subcategories').doc(docId).delete();
    }
  }
}

class _SubcategoryCard extends StatefulWidget {
  final String docId;
  final String name;
  final String? iconUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SubcategoryCard({
    required this.docId,
    required this.name,
    required this.iconUrl,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    super.key,
  });

  @override
  State<_SubcategoryCard> createState() => _SubcategoryCardState();
}

class _SubcategoryCardState extends State<_SubcategoryCard> {
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
                              child: Icon(Icons.category_outlined, size: 48, color: Colors.grey),
                            )
                          : null,
                    ),
                  ),
                  // Subcategory Name
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Overlay Action Buttons
              if (_isHovered)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: widget.onEdit,
                          color: const Color(0xFF0D9759),
                          tooltip: 'Edit Subcategory',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          color: Colors.red,
                          onPressed: widget.onDelete,
                          tooltip: 'Delete Subcategory',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

