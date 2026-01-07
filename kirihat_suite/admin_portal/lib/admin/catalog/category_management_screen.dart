import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data'; // for web bytes
import 'dart:io'; // for File (mobile) NOTE: kIsWeb handling is preferred but adhering to existing patterns
import 'category_products_view.dart'; // Ensure imports are correct

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Category Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showCategoryDialog(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .orderBy('sort_order') // Updated to respect Sort Order
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
                      Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No categories yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _showCategoryDialog(context, null),
                        child: const Text('Add First Category'),
                      ),
                    ],
                  ),
                );
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                onReorder: (oldIndex, newIndex) async {
                   if (oldIndex < newIndex) {
                     newIndex -= 1;
                   }
                   // We ideally need to update the list locally but with StreamBuilder it's hard.
                   // We can just manipulate the docs list and write to DB.
                   var docs = snapshot.data!.docs; // Reference to current list
                   final doc = docs.removeAt(oldIndex);
                   docs.insert(newIndex, doc);
                   
                   final batch = FirebaseFirestore.instance.batch();
                   for(int i=0; i<docs.length; i++){
                     batch.update(docs[i].reference, {'sort_order': i});
                   }
                   await batch.commit();
                },
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  // We can reuse _CategoryCard logic but inside a list tile for better drag UX?
                  // Or just keep the detailed card.
                  return Card(
                    key: ValueKey(doc.id),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       leading: Container(
                         width: 50, height: 50,
                         decoration: BoxDecoration(
                           color: Colors.grey[100],
                           borderRadius: BorderRadius.circular(8),
                           image: (data['icon'] != null && data['icon'].isNotEmpty)
                             ? DecorationImage(image: NetworkImage(data['icon']), fit: BoxFit.cover)
                             : null
                         ),
                         child: (data['icon'] == null || data['icon'].isEmpty) 
                           ? const Icon(Icons.category, color: Colors.grey)
                           : null,
                       ),
                       title: Text(data['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       trailing: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           IconButton(
                             icon: const Icon(Icons.edit, color: Colors.blue),
                             onPressed: () => _showCategoryDialog(context, {'id': doc.id, ...data}),
                           ),
                           const Icon(Icons.drag_handle, color: Colors.grey),
                         ],
                       ),
                       onTap: () => _navigateToCategoryProducts(context, data['name'] ?? 'Unnamed'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCategoryDialog(BuildContext context, Map<String, dynamic>? category) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          child: CategoryFormDialog(category: category),
        ),
      ),
    );
  }

  void _navigateToCategoryProducts(BuildContext context, String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryProductsView(categoryName: categoryName),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.categoryId,
    required this.categoryName,
    required this.data,
    required this.onEdit,
    required this.onTap,
    super.key,
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
                        image: widget.data['icon'] != null
                            ? DecorationImage(
                                image: NetworkImage(widget.data['icon']),
                                fit: BoxFit.cover,
                                onError: (_, __) {},
                              )
                            : null,
                      ),
                      child: widget.data['icon'] == null
                          ? const Center(
                              child: Icon(Icons.category, size: 48, color: Colors.grey),
                            )
                          : null,
                    ),
                  ),
                  // Category Name
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.categoryName,
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
                          onPressed: () {
                            widget.onEdit();
                          },
                          color: const Color(0xFF0D9759),
                          tooltip: 'Edit Category',
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
                          onPressed: () => _confirmDelete(context, widget.categoryId, widget.categoryName),
                          tooltip: 'Delete Category',
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

  void _confirmDelete(BuildContext context, String categoryId, String? name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('categories')
                  .doc(categoryId)
                  .delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category deleted')),
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

class CategoryFormDialog extends StatefulWidget {
  final Map<String, dynamic>? category;

  const CategoryFormDialog({super.key, this.category});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _nameController = TextEditingController();
  XFile? _imageFile;
  bool _isLoading = false;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!['name'] ?? '';
      _existingImageUrl = widget.category!['icon'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  Future<String?> _uploadToCloudinary(XFile image) async {
    try {
      var uri = Uri.parse("https://api.cloudinary.com/v1_1/du634o3sf/image/upload");
      var request = http.MultipartRequest("POST", uri);
      Uint8List bytes = await image.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: "category.jpg"));
      request.fields['upload_preset'] = "ouofgw7n";
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var jsonMap = jsonDecode(String.fromCharCodes(responseData));
        return jsonMap['secure_url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name is required")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _existingImageUrl;

      // Upload new image if selected
      if (_imageFile != null) {
        imageUrl = await _uploadToCloudinary(_imageFile!);
        if (imageUrl == null) {
          throw Exception("Image upload failed");
        }
      }

      var data = {
        'name': _nameController.text.trim(),
        'icon': imageUrl,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.category == null) {
        // Create new - get max sort_order and add 1
        final categoriesSnap = await FirebaseFirestore.instance
            .collection('categories')
            .orderBy('sort_order', descending: true)
            .limit(1)
            .get();
        
        int maxOrder = categoriesSnap.docs.isEmpty ? 0 : (categoriesSnap.docs.first.data()['sort_order'] ?? 0);
        
        data['created_at'] = FieldValue.serverTimestamp();
        data['sort_order'] = maxOrder + 1;
        await FirebaseFirestore.instance.collection('categories').add(data);
      } else {
        // Update existing
        await FirebaseFirestore.instance
            .collection('categories')
            .doc(widget.category!['id'])
            .update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.category == null ? 'Category created!' : 'Category updated!',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0D9759),
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.category, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                widget.category == null ? 'Add Category' : 'Edit Category',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),

        // Form
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: _imageFile != null
                        ? FileImage(File(_imageFile!.path))
                        : (_existingImageUrl != null
                            ? NetworkImage(_existingImageUrl!) as ImageProvider
                            : null),
                    child: (_imageFile == null && _existingImageUrl == null)
                        ? const Icon(Icons.add_a_photo, size: 30, color: Colors.grey)
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
                const SizedBox(height: 16),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Category Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(widget.category == null ? 'Create' : 'Update'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
