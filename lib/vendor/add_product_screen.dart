import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/image_validation_helper.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData; // For Edit Mode
  final String? docId; // For Edit Mode

  const AddProductScreen({super.key, this.initialData, this.docId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with SingleTickerProviderStateMixin { // Add Mixin
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController; // Explicit Controller
  bool _isLoading = false;

  // ... (Keep existing Controllers)
  final _titleController = TextEditingController();
  final _unitController = TextEditingController(); 
  final _shortDescController = TextEditingController();
  final _longDescController = TextEditingController();
  final _brandController = TextEditingController();
  final _tagsController = TextEditingController();
  String? _selectedCategory;
  String? _selectedCategoryId; // Track category ID for subcategories
  final _subcategoryController = TextEditingController();
  List<String> _categories = [];
  Map<String, String> _categoryMap = {}; // name -> id mapping

  // ... (Keep Pricing & Inventory)
  final _regularPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _skuController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController();
  final _aisleController = TextEditingController();
  final _shelfController = TextEditingController();
  final _binController = TextEditingController();
  String _taxStatus = 'Taxable';
  String _stockStatus = 'In Stock';
  bool _allowBackorders = false;

  // ... (Keep Shipping)
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  String _shippingClass = 'Standard';
  String _processingTime = '1-2 business days';
  bool _freeShipping = false;

  // ... (Keep Attributes)
  final _seoTitleController = TextEditingController();
  final _seoDescController = TextEditingController();
  List<Map<String, String>> _attributes = [];

  // ... (Keep Media)
  List<dynamic> _imageUrls = [];
  final _videoUrlController = TextEditingController();
  String _productStatus = 'Published';
  String _visibility = 'Public';
  bool _isFeatured = false;

  final ImagePicker _picker = ImagePicker();

  // ... (Keep Dropdown Options)
  final List<String> _taxOptions = ['Taxable', 'None', 'Zero Rate'];
  final List<String> _stockStatusOptions = ['In Stock', 'Out of Stock', 'On Backorder'];
  final List<String> _shippingClasses = ['Standard', 'Express', 'Heavy', 'Fragile'];
  final List<String> _processingTimes = ['Same day', '1-2 business days', '3-5 business days', '1 week'];
  // Removed Status options as we are using publish button logic
  final List<String> _visibilityOptions = ['Public', 'Hidden', 'Search Only'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Initialize Controller
    _fetchCategories();
    if (widget.initialData != null) _loadExistingData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ... (Keep _loadExistingData)
  void _loadExistingData() {
    var data = widget.initialData!;
    _titleController.text = data['name'] ?? '';
    _unitController.text = data['unit'] ?? '';
    _shortDescController.text = data['short_description'] ?? '';
    _longDescController.text = data['description'] ?? '';
    _brandController.text = data['brand'] ?? '';
    _tagsController.text = (data['tags'] as List<dynamic>? ?? []).join(', ');
    _selectedCategory = data['category'];
    _subcategoryController.text = data['subcategory'] ?? '';

    _regularPriceController.text = data['regular_price']?.toString() ?? '';
    _salePriceController.text = data['sale_price']?.toString() ?? '';
    _costPriceController.text = data['cost_price']?.toString() ?? '';
    _skuController.text = data['sku'] ?? '';
    _stockController.text = data['stock_quantity']?.toString() ?? '';
    _lowStockController.text = data['low_stock_threshold']?.toString() ?? '';
    _taxStatus = data['tax_status'] ?? 'Taxable';
    _stockStatus = data['stock_status'] ?? 'In Stock';
    _allowBackorders = data['allow_backorders'] ?? false;

    if (data['storage_location'] != null) {
      _aisleController.text = data['storage_location']['aisle'] ?? '';
      _shelfController.text = data['storage_location']['shelf'] ?? '';
      _binController.text = data['storage_location']['bin'] ?? '';
    }

    _weightController.text = data['weight']?.toString() ?? '';
    _lengthController.text = data['dimensions']?['length']?.toString() ?? '';
    _widthController.text = data['dimensions']?['width']?.toString() ?? '';
    _heightController.text = data['dimensions']?['height']?.toString() ?? '';
    _shippingClass = data['shipping_class'] ?? 'Standard';
    _processingTime = data['processing_time'] ?? '1-2 business days';
    _freeShipping = data['free_shipping'] ?? false;

    _seoTitleController.text = data['seo_title'] ?? '';
    _seoDescController.text = data['seo_description'] ?? '';
    if (data['attributes'] != null) {
      _attributes = List<Map<String, String>>.from((data['attributes'] as List)
          .map((item) => Map<String, String>.from(item)));
    }

    _imageUrls = List.from(data['images'] ?? []);
    _videoUrlController.text = data['video_url'] ?? '';
    _productStatus = data['status'] ?? 'Published';
    _visibility = data['visibility'] ?? 'Public';
    _isFeatured = data['is_featured'] ?? false;
  }

  // ... (Keep _showCreateSubcategoryDialog, _fetchCategories, _generateSKU, _addAttribute, _removeAttribute)
  void _showCreateSubcategoryDialog() {
      // ... (Same logic, too long to paste efficiently, user can assume it's kept or I can try precise replace)
      // Since I am replacing the whole class, I must include this method.
      // PRO TIP: Use a smaller diff if possible. I'll include it.
      if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category first")),
      );
      return;
    }

    final TextEditingController subcategoryNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Create Subcategory for $_selectedCategory"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subcategoryNameController,
              decoration: const InputDecoration(
                labelText: "Subcategory Name",
                border: OutlineInputBorder(),
                hintText: "e.g. Fresh Fruits, Dairy Products",
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              String subcategoryName = subcategoryNameController.text.trim();
              if (subcategoryName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a name")),
                );
                return;
              }

              try {
                // Check if subcategory already exists
                var existing = await FirebaseFirestore.instance
                    .collection('subcategories')
                    .where('category_id', isEqualTo: _selectedCategoryId)
                    .where('name', isEqualTo: subcategoryName)
                    .get();

                if (existing.docs.isNotEmpty) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
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

                // Create new subcategory
                await FirebaseFirestore.instance.collection('subcategories').add({
                  'name': subcategoryName,
                  'category_id': _selectedCategoryId,
                  'position': countQuery.count ?? 0,
                  'created_at': FieldValue.serverTimestamp(),
                });

                setState(() {
                  _subcategoryController.text = subcategoryName;
                });

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Subcategory '$subcategoryName' created!")),
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
            child: const Text("CREATE"),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchCategories() async {
    var snapshot =
        await FirebaseFirestore.instance.collection('categories').get();
    setState(() {
      _categories = snapshot.docs.map((d) => d['name'].toString()).toList();
      if (_categories.isEmpty) _categories = ['General'];
    });
  }

  void _generateSKU() {
    var rng = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code =
        List.generate(8, (index) => chars[rng.nextInt(chars.length)]).join();
    setState(() => _skuController.text = "SKU-$code");
  }

  void _addAttribute() {
    setState(() {
      _attributes.add({'name': '', 'value': ''});
    });
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes.removeAt(index);
    });
  }

  // --- UPDATED IMAGE UPLOAD ---
  Future<String?> _uploadToCloudinary(Uint8List bytes) async {
    try {
      var uri =
          Uri.parse("https://api.cloudinary.com/v1_1/du634o3sf/image/upload");
      var request = http.MultipartRequest("POST", uri);
      
      request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: "product.jpg"));
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
        // Validate image using new Helper (returns bytes)
        var validation = await ImageValidationHelper.validateProductImage(img);
        
        if (!validation['success']) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(validation['error'] ?? 'Invalid image')),
            );
          }
          continue; 
        }
        
        // Show success msg
        if (mounted && validation['compressed'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image processed successfully')),
          );
        }
        
        // Upload bytes directly
        if (validation['bytes'] != null) {
           String? url = await _uploadToCloudinary(validation['bytes']);
           if (url != null) setState(() => _imageUrls.add(url));
        }
      }
      
      setState(() => _isLoading = false);
    }
  }
 
  // --- UPDATED SAVE FUNCTION ---
  Future<void> _saveProduct({bool isDraft = false}) async {
    if (!_formKey.currentState!.validate()) {
       // Also check if valid and inform user to check tabs
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fix errors in previous tabs")),
       );
       return;
    }

    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please upload at least one image")));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Status Logic
      String finalStatus = isDraft ? 'Draft' : 'Published';
      bool finalIsActive = !isDraft; // Active if Published

      // Prepare Search Keywords
      List<String> keywords = _titleController.text.toLowerCase().split(' ');
      List<String> tags = _tagsController.text
          .toLowerCase()
          .split(',')
          .map((e) => e.trim())
          .toList();
      List<String> searchIndex = [
        ...keywords,
        ...tags,
        _brandController.text.toLowerCase()
      ];
      searchIndex.removeWhere((e) => e.isEmpty);

      Map<String, dynamic> data = {
        'vendor_id': user.uid,
        'vendor_email': user.email,

        'name': _titleController.text.trim(),
        'unit': _unitController.text.trim(),
        'short_description': _shortDescController.text.trim(),
        'description': _longDescController.text.trim(),
        'brand': _brandController.text.trim(),
        'tags': tags,
        'category': _selectedCategory,
        'subcategory': _subcategoryController.text.trim(),
        'search_keywords': searchIndex,

        'regular_price': double.tryParse(_regularPriceController.text) ?? 0,
        'sale_price': double.tryParse(_salePriceController.text),
        'price': _salePriceController.text.isNotEmpty
            ? double.parse(_salePriceController.text)
            : double.parse(_regularPriceController.text),
        'cost_price': double.tryParse(_costPriceController.text),
        'tax_status': _taxStatus,

        'sku': _skuController.text.trim(),
        'stock_quantity': int.tryParse(_stockController.text) ?? 0,
        'low_stock_threshold': int.tryParse(_lowStockController.text) ?? 5,
        'stock_status': _stockStatus,
        'allow_backorders': _allowBackorders,

        'storage_location': {
          'aisle': _aisleController.text.trim(),
          'shelf': _shelfController.text.trim(),
          'bin': _binController.text.trim(),
        },

        'weight': double.tryParse(_weightController.text),
        'dimensions': {
          'length': double.tryParse(_lengthController.text),
          'width': double.tryParse(_widthController.text),
          'height': double.tryParse(_heightController.text),
        },
        'shipping_class': _shippingClass,
        'processing_time': _processingTime,
        'free_shipping': _freeShipping,

        'attributes': _attributes,
        'seo_title': _seoTitleController.text.trim(),
        'seo_description': _seoDescController.text.trim(),

        'imageUrl': _imageUrls.first,
        'images': _imageUrls,
        'video_url': _videoUrlController.text.trim(),
        
        // Critical for Customer Visibility
        'status': finalStatus,
        'visibility': _visibility, // Kept manual control if needed
        'is_featured': _isFeatured,
        'isActive': finalIsActive,

        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.docId == null) {
        data['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('products').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.docId)
            .update(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Product ${isDraft ? 'Draft Saved' : 'Published'}!")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // --- NAVIGATION HELPERS ---
  void _nextTab() {
    if (_tabController.index < 4) {
      _tabController.animateTo(_tabController.index + 1);
    }
  }

  void _prevTab() {
     if (_tabController.index > 0) {
      _tabController.animateTo(_tabController.index - 1);
    }
  }

  // ... (Keep UI Helpers _buildTextField, _buildDropdown)
  Widget _buildTextField(TextEditingController ctrl, String label,
      {int maxLines = 1, bool isNumber = false, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: required ? "$label *" : label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: required
            ? (val) => (val == null || val.isEmpty) ? "Required" : null
            : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docId == null ? "Add Product" : "Edit Product"),
        backgroundColor: Colors.orange[100],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: "General"),
            Tab(text: "Price & Stock"),
            Tab(text: "Shipping"),
            Tab(text: "Attributes"),
            Tab(text: "Media"),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. GENERAL
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _buildTextField(_titleController, "Product Title", required: true),
                      _buildTextField(_unitController, "Unit / Variant (e.g. 500g, 1L)"),
                      _buildTextField(_shortDescController, "Short Description", maxLines: 2),
                      _buildTextField(_longDescController, "Long Description",
                          maxLines: 6, required: true),
                      Row(children: [
                        Expanded(child: _buildTextField(_brandController, "Brand")),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            hint: const Text("Category *"),
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: _categories
                                .toSet()
                                .union({
                                  if (_selectedCategory != null) _selectedCategory!
                                })
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) => setState(() {
                              _selectedCategory = val;
                              _selectedCategoryId = val != null ? _categoryMap[val] : null;
                            }),
                            validator: (val) => val == null ? "Required" : null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      if (_selectedCategory != null) ...[
                        Row(children: [
                          Expanded(
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
                                  subcategories = snapshot.data!.docs
                                      .map((doc) => doc['name'] as String)
                                      .toList();
                                }
                                String currentSubcategory = _subcategoryController.text.trim();
                                if (currentSubcategory.isNotEmpty && !subcategories.contains(currentSubcategory)) {
                                  subcategories.insert(0, currentSubcategory);
                                }
                                return DropdownButtonFormField<String>(
                                  value: currentSubcategory.isEmpty ? null : currentSubcategory,
                                  hint: const Text("Subcategory (Optional)"),
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(), labelText: 'Subcategory'),
                                  items: subcategories
                                      .map((sub) => DropdownMenuItem(value: sub, child: Text(sub)))
                                      .toList(),
                                  onChanged: (val) => setState(() => _subcategoryController.text = val ?? ''),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _showCreateSubcategoryDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New'),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 10),
                      _buildTextField(_tagsController, "Tags (comma separated)"),
                    ]),
                  ),

                  // 2. PRICING & INVENTORY
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                            child: _buildTextField(_regularPriceController, "Regular Price",
                                isNumber: true, required: true)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildTextField(_salePriceController, "Sale Price", isNumber: true)),
                      ]),
                      _buildTextField(_costPriceController, "Cost Price (Hidden)", isNumber: true),
                      _buildDropdown("Tax Status", _taxStatus, _taxOptions,
                          (v) => setState(() => _taxStatus = v!)),
                      const Divider(),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(_skuController, "SKU", required: true)),
                        const SizedBox(width: 10),
                        ElevatedButton(
                            onPressed: _generateSKU, child: const Text("Auto SKU")),
                      ]),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(_stockController, "Stock Qty",
                                isNumber: true, required: true)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildTextField(_lowStockController, "Low Stock Alert", isNumber: true)),
                      ]),
                      _buildDropdown("Stock Status", _stockStatus, _stockStatusOptions,
                          (v) => setState(() => _stockStatus = v!)),
                      SwitchListTile(
                        title: const Text("Allow Backorders?"),
                        value: _allowBackorders,
                        onChanged: (val) => setState(() => _allowBackorders = val),
                      ),
                      const Divider(),
                      const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Storage Location",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _buildTextField(_aisleController, "Aisle")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(_shelfController, "Shelf")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(_binController, "Bin")),
                      ]),
                    ]),
                  ),

                  // 3. SHIPPING
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _buildTextField(_weightController, "Weight (kg)", isNumber: true),
                      Row(children: [
                        Expanded(child: _buildTextField(_lengthController, "Length (cm)", isNumber: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(_widthController, "Width (cm)", isNumber: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(_heightController, "Height (cm)", isNumber: true)),
                      ]),
                      _buildDropdown("Shipping Class", _shippingClass, _shippingClasses, (v) => setState(() => _shippingClass = v!)),
                      _buildDropdown("Processing Time", _processingTime, _processingTimes, (v) => setState(() => _processingTime = v!)),
                      SwitchListTile(
                        title: const Text("Free Shipping?"),
                        value: _freeShipping,
                        onChanged: (val) => setState(() => _freeShipping = val),
                      ),
                    ]),
                  ),

                  // 4. ATTRIBUTES & SEO
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Custom Attributes",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          ..._attributes.asMap().entries.map((entry) {
                            int idx = entry.key;
                            return Row(children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: entry.value['name'],
                                  decoration: const InputDecoration(labelText: "Name (e.g. Color)"),
                                  onChanged: (val) => _attributes[idx]['name'] = val,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  initialValue: entry.value['value'],
                                  decoration: const InputDecoration(labelText: "Value (e.g. Red)"),
                                  onChanged: (val) => _attributes[idx]['value'] = val,
                                ),
                              ),
                              IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeAttribute(idx)),
                            ]);
                          }),
                          TextButton.icon(
                              onPressed: _addAttribute,
                              icon: const Icon(Icons.add),
                              label: const Text("Add Attribute")),
                          const Divider(height: 30),
                          const Text("SEO",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          _buildTextField(_seoTitleController, "SEO Title"),
                          _buildTextField(_seoDescController, "SEO Description", maxLines: 3),
                        ]),
                  ),

                  // 5. MEDIA
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      ElevatedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text("Upload Images (Max 5)"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: _imageUrls.asMap().entries.map((entry) {
                          return Stack(
                            children: [
                              Image.network(entry.value,
                                  width: 80, height: 80, fit: BoxFit.cover),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _imageUrls.removeAt(entry.key)),
                                  child: Container(
                                    color: Colors.black54,
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                       _buildTextField(_videoUrlController, "Video URL (Optional)"),
                       SwitchListTile(
                        title: const Text("Feature Product on Home?"),
                        value: _isFeatured,
                        onChanged: (val) => setState(() => _isFeatured = val),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          
          // --- BOTTOM BAR NAVIGATION ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3), 
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button (Hidden on first tab)
                if (_tabController.index > 0)
                  OutlinedButton(
                    onPressed: _prevTab,
                    child: const Text("Previous"),
                  )
                else
                   // Placeholder to keep spacing
                   const SizedBox(width: 80),

                // Next or Publish Button
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                     bool isLastTab = _tabController.index == 4;
                     return isLastTab 
                       ? ElevatedButton(
                           onPressed: _isLoading ? null : () => _saveProduct(isDraft: false),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.green,
                             padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                           ),
                           child: _isLoading 
                             ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                             : const Text("PUBLISH PRODUCT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                         )
                       : ElevatedButton(
                           onPressed: _nextTab,
                           child: const Text("Next Step"),
                         );
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
