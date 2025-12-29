import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData; // For Edit Mode
  final String? docId; // For Edit Mode

  const AddProductScreen({super.key, this.initialData, this.docId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // --- 1. GENERAL INFO ---
  final _titleController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _longDescController = TextEditingController();
  final _brandController = TextEditingController();
  final _tagsController = TextEditingController();
  String? _selectedCategory;
  List<String> _categories = [];

  // --- 2. PRICING & INVENTORY ---
  final _regularPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _skuController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController();

  // NEW: STORAGE LOCATION CONTROLLERS
  final _aisleController = TextEditingController();
  final _shelfController = TextEditingController();
  final _binController = TextEditingController();

  String _taxStatus = 'Taxable';
  String _stockStatus = 'In Stock';
  bool _allowBackorders = false;

  // --- 3. SHIPPING ---
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  String _shippingClass = 'Standard';
  String _processingTime = '1-2 business days';
  bool _freeShipping = false;

  // --- 4. ATTRIBUTES & SEO ---
  final _seoTitleController = TextEditingController();
  final _seoDescController = TextEditingController();
  List<Map<String, String>> _attributes = [];

  // --- 5. MEDIA & SETTINGS ---
  List<dynamic> _imageUrls = [];
  final _videoUrlController = TextEditingController();
  String _productStatus = 'Published';
  String _visibility = 'Public';
  bool _isFeatured = false;

  final ImagePicker _picker = ImagePicker();

  // DROPDOWN OPTIONS
  final List<String> _taxOptions = ['Taxable', 'None', 'Zero Rate'];
  final List<String> _stockStatusOptions = [
    'In Stock',
    'Out of Stock',
    'On Backorder'
  ];
  final List<String> _shippingClasses = [
    'Standard',
    'Express',
    'Heavy',
    'Fragile'
  ];
  final List<String> _processingTimes = [
    'Same day',
    '1-2 business days',
    '3-5 business days',
    '1 week'
  ];
  final List<String> _statusOptions = [
    'Draft',
    'Pending Review',
    'Published',
    'Archived'
  ];
  final List<String> _visibilityOptions = ['Public', 'Hidden', 'Search Only'];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.initialData != null) _loadExistingData();
  }

  void _loadExistingData() {
    var data = widget.initialData!;
    // General
    _titleController.text = data['name'] ?? '';
    _shortDescController.text = data['short_description'] ?? '';
    _longDescController.text = data['description'] ?? '';
    _brandController.text = data['brand'] ?? '';
    _tagsController.text = (data['tags'] as List<dynamic>? ?? []).join(', ');
    _selectedCategory = data['category'];

    // Pricing
    _regularPriceController.text = data['regular_price']?.toString() ?? '';
    _salePriceController.text = data['sale_price']?.toString() ?? '';
    _costPriceController.text = data['cost_price']?.toString() ?? '';
    _skuController.text = data['sku'] ?? '';
    _stockController.text = data['stock_quantity']?.toString() ?? '';
    _lowStockController.text = data['low_stock_threshold']?.toString() ?? '';
    _taxStatus = data['tax_status'] ?? 'Taxable';
    _stockStatus = data['stock_status'] ?? 'In Stock';
    _allowBackorders = data['allow_backorders'] ?? false;

    // NEW: Load Storage Data
    if (data['storage_location'] != null) {
      _aisleController.text = data['storage_location']['aisle'] ?? '';
      _shelfController.text = data['storage_location']['shelf'] ?? '';
      _binController.text = data['storage_location']['bin'] ?? '';
    }

    // Shipping
    _weightController.text = data['weight']?.toString() ?? '';
    _lengthController.text = data['dimensions']?['length']?.toString() ?? '';
    _widthController.text = data['dimensions']?['width']?.toString() ?? '';
    _heightController.text = data['dimensions']?['height']?.toString() ?? '';
    _shippingClass = data['shipping_class'] ?? 'Standard';
    _processingTime = data['processing_time'] ?? '1-2 business days';
    _freeShipping = data['free_shipping'] ?? false;

    // Attributes & SEO
    _seoTitleController.text = data['seo_title'] ?? '';
    _seoDescController.text = data['seo_description'] ?? '';
    if (data['attributes'] != null) {
      _attributes = List<Map<String, String>>.from((data['attributes'] as List)
          .map((item) => Map<String, String>.from(item)));
    }

    // Media & Settings
    _imageUrls = List.from(data['images'] ?? []);
    _videoUrlController.text = data['video_url'] ?? '';
    _productStatus = data['status'] ?? 'Published';
    _visibility = data['visibility'] ?? 'Public';
    _isFeatured = data['is_featured'] ?? false;
  }

  Future<void> _fetchCategories() async {
    var snapshot =
        await FirebaseFirestore.instance.collection('categories').get();
    setState(() {
      _categories = snapshot.docs.map((d) => d['name'].toString()).toList();
      if (_categories.isEmpty) _categories = ['General'];
    });
  }

  // --- LOGIC ---
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

  Future<String?> _uploadToCloudinary(XFile image) async {
    try {
      var uri =
          Uri.parse("https://api.cloudinary.com/v1_1/du634o3sf/image/upload");
      var request = http.MultipartRequest("POST", uri);
      Uint8List bytes = await image.readAsBytes();
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
        String? url = await _uploadToCloudinary(img);
        if (url != null) setState(() => _imageUrls.add(url));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please upload at least one image")));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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

        // 1. General
        'name': _titleController.text.trim(),
        'short_description': _shortDescController.text.trim(),
        'description': _longDescController.text.trim(),
        'brand': _brandController.text.trim(),
        'tags': tags,
        'category': _selectedCategory,
        'search_keywords': searchIndex,

        // 2. Pricing
        'regular_price': double.tryParse(_regularPriceController.text) ?? 0,
        'sale_price': double.tryParse(_salePriceController.text),
        'price': _salePriceController.text.isNotEmpty
            ? double.parse(_salePriceController.text)
            : double.parse(_regularPriceController.text),
        'cost_price': double.tryParse(_costPriceController.text),
        'tax_status': _taxStatus,

        // Inventory
        'sku': _skuController.text.trim(),
        'stock_quantity': int.tryParse(_stockController.text) ?? 0,
        'low_stock_threshold': int.tryParse(_lowStockController.text) ?? 5,
        'stock_status': _stockStatus,
        'allow_backorders': _allowBackorders,

        // NEW: Save Storage Location
        'storage_location': {
          'aisle': _aisleController.text.trim(),
          'shelf': _shelfController.text.trim(),
          'bin': _binController.text.trim(),
        },

        // 3. Shipping
        'weight': double.tryParse(_weightController.text),
        'dimensions': {
          'length': double.tryParse(_lengthController.text),
          'width': double.tryParse(_widthController.text),
          'height': double.tryParse(_heightController.text),
        },
        'shipping_class': _shippingClass,
        'processing_time': _processingTime,
        'free_shipping': _freeShipping,

        // 4. Attributes & SEO
        'attributes': _attributes,
        'seo_title': _seoTitleController.text.trim(),
        'seo_description': _seoDescController.text.trim(),

        // 5. Media & Settings
        'imageUrl': _imageUrls.first,
        'images': _imageUrls,
        'video_url': _videoUrlController.text.trim(),
        'status': _productStatus,
        'visibility': _visibility,
        'is_featured': _isFeatured,
        'isActive': _productStatus == 'Published',

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
            const SnackBar(content: Text("Product Saved Successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // --- UI HELPERS ---
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
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.docId == null ? "Add Product" : "Edit Product"),
          backgroundColor: Colors.orange[100],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: "General"),
              Tab(text: "Price & Stock"),
              Tab(text: "Shipping"),
              Tab(text: "Attributes"),
              Tab(text: "Media"),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: TabBarView(
            children: [
              // 1. GENERAL
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _buildTextField(_titleController, "Product Title",
                      required: true),
                  _buildTextField(_shortDescController, "Short Description",
                      maxLines: 2),
                  _buildTextField(_longDescController, "Long Description",
                      maxLines: 6, required: true),
                  Row(children: [
                    Expanded(child: _buildTextField(_brandController, "Brand")),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        hint: const Text("Category *"),
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                        items: _categories
                            .toSet()
                            .union({
                              if (_selectedCategory != null) _selectedCategory!
                            })
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCategory = val),
                        validator: (val) => val == null ? "Required" : null,
                      ),
                    ),
                  ]),
                  _buildTextField(_tagsController, "Tags (comma separated)"),
                ]),
              ),

              // 2. PRICING & INVENTORY
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: _buildTextField(
                            _regularPriceController, "Regular Price",
                            isNumber: true, required: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField(
                            _salePriceController, "Sale Price",
                            isNumber: true)),
                  ]),
                  _buildTextField(_costPriceController, "Cost Price (Hidden)",
                      isNumber: true),
                  _buildDropdown("Tax Status", _taxStatus, _taxOptions,
                      (v) => setState(() => _taxStatus = v!)),
                  const Divider(),

                  // SKU & STOCK
                  Row(children: [
                    Expanded(
                        child: _buildTextField(_skuController, "SKU",
                            required: true)),
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
                        child: _buildTextField(
                            _lowStockController, "Low Stock Alert",
                            isNumber: true)),
                  ]),
                  _buildDropdown(
                      "Stock Status",
                      _stockStatus,
                      _stockStatusOptions,
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(height: 10),
                  // NEW: STORAGE FIELDS
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
                  _buildTextField(_weightController, "Weight (kg)",
                      isNumber: true),
                  Row(children: [
                    Expanded(
                        child: _buildTextField(_lengthController, "Length (cm)",
                            isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField(_widthController, "Width (cm)",
                            isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField(_heightController, "Height (cm)",
                            isNumber: true)),
                  ]),
                  _buildDropdown(
                      "Shipping Class",
                      _shippingClass,
                      _shippingClasses,
                      (v) => setState(() => _shippingClass = v!)),
                  _buildDropdown(
                      "Processing Time",
                      _processingTime,
                      _processingTimes,
                      (v) => setState(() => _processingTime = v!)),
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      ..._attributes.asMap().entries.map((entry) {
                        int idx = entry.key;
                        return Row(children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: entry.value['name'],
                              decoration: const InputDecoration(
                                  labelText: "Name (e.g. Color)"),
                              onChanged: (val) =>
                                  _attributes[idx]['name'] = val,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: entry.value['value'],
                              decoration: const InputDecoration(
                                  labelText: "Value (e.g. Red)"),
                              onChanged: (val) =>
                                  _attributes[idx]['value'] = val,
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      _buildTextField(_seoTitleController, "SEO Title"),
                      _buildTextField(_seoDescController, "SEO Description",
                          maxLines: 3),
                    ]),
              ),

              // 5. MEDIA & SETTINGS
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
                                  color: Colors.red,
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16)),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(_videoUrlController, "Video URL"),
                  const Divider(),
                  _buildDropdown(
                      "Product Status",
                      _productStatus,
                      _statusOptions,
                      (v) => setState(() => _productStatus = v!)),
                  _buildDropdown("Visibility", _visibility, _visibilityOptions,
                      (v) => setState(() => _visibility = v!)),
                  SwitchListTile(
                    title: const Text("Featured Product?"),
                    value: _isFeatured,
                    onChanged: (val) => setState(() => _isFeatured = val),
                  ),
                ]),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SAVE & PUBLISH",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
