import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ComprehensiveMasterProductForm extends StatefulWidget {
  final Map<String, dynamic>? product;

  const ComprehensiveMasterProductForm({super.key, this.product});

  @override
  State<ComprehensiveMasterProductForm> createState() => _ComprehensiveMasterProductFormState();
}

class _ComprehensiveMasterProductFormState extends State<ComprehensiveMasterProductForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isLoading = false;

  // Controllers
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _longDescController = TextEditingController();
  final _brandController = TextEditingController();
  final _tagsController = TextEditingController();
  final _mrpController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _seoTitleController = TextEditingController();
  final _seoDescController = TextEditingController();

  String? _selectedCategory;
  String? _selectedCategoryId; // Track category ID for subcategories
  String? _selectedSubcategory;
  bool _isActive = true;
  List<dynamic> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.product != null) _loadExistingData();
  }

  void _loadExistingData() {
    var data = widget.product!;
    _nameController.text = data['name'] ?? '';
    _unitController.text = data['unit'] ?? '';
    _shortDescController.text = data['short_description'] ?? '';
    _longDescController.text = data['description'] ?? '';
    _brandController.text = data['brand'] ?? '';
    _mrpController.text = data['mrp']?.toString() ?? '';
    _barcodeController.text = data['barcode'] ?? '';
    _selectedCategory = data['category'];
    _selectedSubcategory = data['subcategory'];
    _isActive = data['isActive'] ?? true;
    _imageUrls = List.from(data['images'] ?? []);
    _seoTitleController.text = data['seo_title'] ?? '';
    _seoDescController.text = data['seo_description'] ?? '';
    
    List tags = data['tags'] ?? [];
    _tagsController.text = tags.join(', ');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    _shortDescController.dispose();
    _longDescController.dispose();
    _brandController.dispose();
    _tagsController.dispose();
    _mrpController.dispose();
    _barcodeController.dispose();
    _seoTitleController.dispose();
    _seoDescController.dispose();
    super.dispose();
  }

  Future<String?> _uploadToCloudinary(Uint8List bytes) async {
    try {
      var uri = Uri.parse("https://api.cloudinary.com/v1_1/du634o3sf/image/upload");
      var request = http.MultipartRequest("POST", uri);
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: "product.jpg"));
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

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(limit: 5);
    if (images.isNotEmpty) {
      setState(() => _isLoading = true);
      
      for (var img in images) {
        var bytes = await img.readAsBytes();
        String? url = await _uploadToCloudinary(bytes);
        if (url != null) setState(() => _imageUrls.add(url));
      }
      
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload at least one image")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      var data = {
        'name': _nameController.text.trim(),
        'unit': _unitController.text.trim(),
        'short_description': _shortDescController.text.trim(),
        'description': _longDescController.text.trim(),
        'brand': _brandController.text.trim(),
        'mrp': double.parse(_mrpController.text),
        'barcode': _barcodeController.text.trim(),
        'category': _selectedCategory,
        'subcategory': _selectedSubcategory,
        'tags': tags,
        'imageUrl': _imageUrls.first,
        'images': _imageUrls,
        'isActive': _isActive,
        'seo_title': _seoTitleController.text.trim(),
        'seo_description': _seoDescController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.product == null) {
        data['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('master_products').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('master_products')
            .doc(widget.product!['id'])
            .update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.product == null ? 'Product created!' : 'Product updated!'),
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
              const Icon(Icons.inventory_2, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                widget.product == null ? 'Add Master Product' : 'Edit Master Product',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),

        // Tab Bar
        Container(
          color: Colors.grey[100],
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0D9759),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0D9759),
            tabs: const [
              Tab(text: "General & Pricing"),
              Tab(text: "Media"),
              Tab(text: "SEO"),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: Form(
            key: _formKey,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildMediaTab(),
                _buildSEOTab(),
              ],
            ),
          ),
        ),

        // Footer Actions
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(widget.product == null ? 'Create Product' : 'Update Product'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddSubcategoryDialog() {
    if (_selectedCategory == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category first")),
      );
      return;
    }

    final TextEditingController subController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Subcategory to '$_selectedCategory'"),
        content: TextField(
          controller: subController,
          decoration: const InputDecoration(
            labelText: "Subcategory Name",
            hintText: "e.g. Milk, Cheese",
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String name = subController.text.trim();
              if (name.isEmpty) return;

              try {
                // Check duplicate using category_id
                var query = await FirebaseFirestore.instance
                    .collection('subcategories')
                    .where('category_id', isEqualTo: _selectedCategoryId)
                    .where('name', isEqualTo: name)
                    .get();

                if (query.docs.isNotEmpty) {
                    if(ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text("Subcategory already exists")),
                        );
                    }
                    return;
                }

                // Get the count for position
                final countQuery = await FirebaseFirestore.instance
                    .collection('subcategories')
                    .where('category_id', isEqualTo: _selectedCategoryId)
                    .count()
                    .get();

                await FirebaseFirestore.instance.collection('subcategories').add({
                  'name': name,
                  'category_id': _selectedCategoryId,
                  'position': countQuery.count ?? 0,
                  'created_at': FieldValue.serverTimestamp(),
                });

                setState(() {
                  _selectedSubcategory = name;
                });
                
                if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Subcategory '$name' added")),
                    );
                }
              } catch (e) {
                 if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                    );
                 }
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
          validator: (val) => val!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Unit (e.g., 500g, 1L)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _mrpController,
                decoration: const InputDecoration(labelText: 'MRP (₹) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val!.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _shortDescController,
          decoration: const InputDecoration(labelText: 'Short Description', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextFormField(
              controller: _longDescController,
              decoration: const InputDecoration(
                labelText: 'Long Description *', 
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () {
                final text = _longDescController.text;
                final selection = _longDescController.selection;
                final newText = "• ";
                
                if (selection.start >= 0) {
                  final newValue = text.replaceRange(selection.start, selection.end, newText);
                  _longDescController.value = TextEditingValue(
                    text: newValue,
                    selection: TextSelection.collapsed(offset: selection.start + newText.length),
                  );
                } else {
                  _longDescController.text += "\n$newText";
                }
              },
              icon: const Icon(Icons.format_list_bulleted, size: 16),
              label: const Text("Add Bullet Point"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(labelText: 'Barcode', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('categories')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  List<String> categories = [];
                  Map<String, String> categoryMap = {}; // name -> id mapping
                  
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      String name = doc['name'] as String;
                      categories.add(name);
                      categoryMap[name] = doc.id;
                    }
                  }
                  
                  // Validate selected value exists ONLY if data is loaded
                  if (snapshot.connectionState == ConnectionState.active || snapshot.connectionState == ConnectionState.done) {
                      if (_selectedCategory != null && !categories.contains(_selectedCategory)) {
                        _selectedCategory = null;
                        _selectedCategoryId = null; 
                      }
                  } else {
                     // Temporary keep value while loading
                     if (_selectedCategory != null) {
                        categories.add(_selectedCategory!);
                     }
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                         setState(() {
                             _selectedCategory = val;
                             _selectedCategoryId = val != null ? categoryMap[val] : null;
                             _selectedSubcategory = null; 
                         });
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: StreamBuilder<QuerySnapshot>(
                stream: _selectedCategoryId != null
                    ? FirebaseFirestore.instance
                        .collection('subcategories')
                        .where('category_id', isEqualTo: _selectedCategoryId)
                        .snapshots()
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  List<String> subcategories = [];
                  if (snapshot.hasData) {
                    subcategories = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
                  }

                  // Validate selected value exists ONLY if data is loaded
                  if (snapshot.connectionState == ConnectionState.active || snapshot.connectionState == ConnectionState.done) {
                      if (_selectedSubcategory != null && !subcategories.contains(_selectedSubcategory)) {
                        // Keep value if it's not in list? Or clear it? 
                        // If we clear it, it disappears for the user. 
                        // It's safer to keep it but maybe show warning, or just allow it (graceful degradation)
                        // But DropdownButton throws error if value not in items.
                        // So we MUST clear it OR add it to the items list temporarily.
                        
                        // Let's force add it to items if it exists in data but not in list (edge case)
                        // But usually, we just clear it.
                        // The issue was connectionState was likely 'waiting', so list was empty.
                         _selectedSubcategory = null;
                      }
                  } else {
                     // If waiting, ensure we don't pass a value that crashes if Dropdown tries to render items?
                     // Dropdown items map empty list -> empty items. 
                     // If value is set but items empty, DropdownButton crashes? 
                     // standard DropdownButton crashes. DropdownButtonFormField also crashes.
                     
                     // We can temporarily add the selected value to the list if loading
                     if (_selectedSubcategory != null) {
                        subcategories.add(_selectedSubcategory!);
                     }
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedSubcategory,
                    decoration: const InputDecoration(labelText: 'Subcategory', border: OutlineInputBorder()),
                    items: subcategories.map((sub) {
                      return DropdownMenuItem(value: sub, child: Text(sub));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedSubcategory = val),
                    validator: (val) => val == null ? 'Required' : null,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
                margin: const EdgeInsets.only(top: 4),
                child: IconButton.filled(
                    onPressed: _showAddSubcategoryDialog,
                    icon: const Icon(Icons.add),
                    tooltip: "Add Subcategory",
                    style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9759),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _tagsController,
          decoration: const InputDecoration(
            labelText: 'Tags (comma separated)',
            border: OutlineInputBorder(),
            hintText: 'organic, fresh, dairy',
          ),
        ),
        const SizedBox(height: 16),

        SwitchListTile(
          title: const Text('Active'),
          subtitle: const Text('Product is available for vendors'),
          value: _isActive,
          onChanged: (val) => setState(() => _isActive = val),
        ),
      ],
    );
  }

  Widget _buildMediaTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ElevatedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.cloud_upload),
          label: const Text("Upload Images (Max 5)"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 20),

        if (_imageUrls.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.image, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No images uploaded', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _imageUrls.asMap().entries.map((entry) {
              return Stack(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(entry.value, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageUrls.removeAt(entry.key)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSEOTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextFormField(
          controller: _seoTitleController,
          decoration: const InputDecoration(labelText: 'SEO Title', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _seoDescController,
          decoration: const InputDecoration(labelText: 'SEO Description', border: OutlineInputBorder()),
          maxLines: 4,
        ),
      ],
    );
  }
}
