
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'package:kirihat_core/services/cloudinary_service.dart';
import 'package:kirihat_core/models/category_specification_model.dart';
import 'package:kirihat_core/services/category_specification_service.dart';
import 'widgets/dynamic_specification_renderer.dart';
import 'widgets/keyword_suggestion_widget.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

class AddProductScreen extends StatefulWidget {
  final SellerModel seller;

  const AddProductScreen({super.key, required this.seller});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sellerService = SellerService();
  final _categorySpecService = CategorySpecificationService();
  bool _isLoading = false;
  
  CategorySpecification? _currentTemplate;
  Map<String, dynamic> _specifications = {};

  // Controllers
  final _nameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _shortDescController = TextEditingController(); // NEW
  final _unitController = TextEditingController();
  final _barcodeController = TextEditingController(); // NEW
  
  // SEO Controllers
  final _seoTitleController = TextEditingController();
  final _seoDescController = TextEditingController();
  List<String> _keywords = [];

  String? _selectedCategory;
  String? _selectedCategoryId;
  List<String> _selectedCategoryPath = [];
  List<String> _selectedCategoryPathNames = [];
  int _selectedCategoryLevel = 0;
  
  // For navigation within category tree
  String? _currentParentId;
  List<String> _breadcrumbIds = [];
  List<String> _breadcrumbNames = [];
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; 
  
  List<dynamic> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _shortDescController.dispose(); // NEW
    _unitController.dispose();
    _barcodeController.dispose(); // NEW
    _seoTitleController.dispose();
    _seoDescController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(limit: 5);
    if (images.isNotEmpty) {
      if (_imageUrls.length + images.length > 5) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 images allowed')),
          );
        }
        return;
      }

      setState(() => _isLoading = true);
      
      for (var img in images) {
        var bytes = await img.readAsBytes();
        String? url = await CloudinaryService.uploadImage(bytes, folder: "seller_products");
        if (url != null) setState(() => _imageUrls.add(url));
      }
      
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload at least one image")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final costPrice = double.tryParse(_costPriceController.text) ?? 0;
      final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0;
      final mrp = double.tryParse(_mrpController.text) ?? sellingPrice;
      
      // Calculate discount percentage
      final discountPercent = mrp > sellingPrice 
          ? ((mrp - sellingPrice) / mrp * 100).roundToDouble()
          : 0.0;
      
      // Calculate profit margin
      final profitMargin = sellingPrice > costPrice
          ? ((sellingPrice - costPrice) / costPrice * 100).roundToDouble()
          : 0.0;

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'short_description': _shortDescController.text.trim(), // NEW
        'cost_price': costPrice,
        'price': sellingPrice, // Selling price
        'mrp': mrp,
        'discount_percent': discountPercent,
        'profit_margin': profitMargin,
        'brand': _brandController.text.trim(),
        'unit': _unitController.text.trim(),
        'barcode': _barcodeController.text.trim(), // NEW
        'category': _selectedCategory,
        'category_id': _selectedCategoryId,
        'category_level': _selectedCategoryLevel,
        'category_path': _selectedCategoryPath,
        'category_path_names': _selectedCategoryPathNames,
        'images': _imageUrls,
        'image_url': _imageUrls.first, // Main image
        'seller_id': widget.seller.id,
        'submitted_by_name': widget.seller.ownerName,
        'business_name': widget.seller.businessName,
        'status': 'pending', // Replaced status
        'is_draft': false, // Replaced is_draft
        'specifications': _specifications,
        'template_version': _currentTemplate?.version ?? 1,
        'seo_title': _seoTitleController.text.trim(), // NEW
        'seo_description': _seoDescController.text.trim(), // NEW
        'tags': _keywords, // NEW
      };

      await _sellerService.submitProductRequest(widget.seller.id, productData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product request submitted successfully!'),
            backgroundColor: Color(0xFF0D9759),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload at least one image")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final costPrice = double.tryParse(_costPriceController.text) ?? 0;
      final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0;
      final mrp = double.tryParse(_mrpController.text) ?? sellingPrice;
      
      final discountPercent = mrp > sellingPrice 
          ? ((mrp - sellingPrice) / mrp * 100).roundToDouble()
          : 0.0;
      
      final profitMargin = sellingPrice > costPrice
          ? ((sellingPrice - costPrice) / costPrice * 100).roundToDouble()
          : 0.0;

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'cost_price': costPrice,
        'price': sellingPrice,
        'mrp': mrp,
        'discount_percent': discountPercent,
        'profit_margin': profitMargin,
        'brand': _brandController.text.trim(),
        'unit': _unitController.text.trim(),
        'category': _selectedCategory,
        'category_id': _selectedCategoryId,
        'category_level': _selectedCategoryLevel,
        'category_path': _selectedCategoryPath,
        'category_path_names': _selectedCategoryPathNames,
        'images': _imageUrls,
        'image_url': _imageUrls.first,
        'seller_id': widget.seller.id,
        'submitted_by_name': widget.seller.ownerName,
        'business_name': widget.seller.businessName,
        'status': 'draft',
        'is_draft': true,
        'specifications': _specifications,
        'template_version': _currentTemplate?.version ?? 1,
        'seo_title': _seoTitleController.text.trim(),
        'seo_description': _seoDescController.text.trim(),
        'tags': _keywords,
      };

      await _sellerService.submitProductRequest(widget.seller.id, productData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving draft: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPricingIndicators() {
    final costPrice = double.tryParse(_costPriceController.text) ?? 0;
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0;
    final mrp = double.tryParse(_mrpController.text) ?? sellingPrice;

    final profitMargin = costPrice > 0 && sellingPrice > costPrice
        ? ((sellingPrice - costPrice) / costPrice * 100).roundToDouble()
        : 0.0;
    
    final discountPercent = mrp > sellingPrice
        ? ((mrp - sellingPrice) / mrp * 100).roundToDouble()
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profit Margin Indicator
        if (profitMargin > 0) ...[
          Row(
            children: [
              const Icon(Icons.trending_up, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Profit Margin: ${profitMargin.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Profit margin bar
          Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade100,
                  Colors.green.shade400,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: (profitMargin.clamp(0, 100) / 100) * MediaQuery.of(context).size.width * 0.7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade600,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You earn ${CurrencyHelper.format(sellingPrice - costPrice)} per unit',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
        ],

        // Discount Banner
        if (discountPercent > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${discountPercent.toStringAsFixed(0)}% OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discount: ${CurrencyHelper.format(mrp - sellingPrice)} off MRP',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Customers see: ${CurrencyHelper.format(mrp)} → ${CurrencyHelper.format(sellingPrice)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Image Upload Section
            _buildImageUploadSection(),
            const SizedBox(height: 24),
            
            // Basic Info
            const Text(
              'Basic Information',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            // Short Description
            TextFormField(
              controller: _shortDescController,
              decoration: const InputDecoration(
                labelText: 'Short Description',
                border: OutlineInputBorder(),
                helperText: 'Brief summary for list views',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // Barcode
            TextFormField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: 'Barcode / EAN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 16),

            // Pricing Section
            const Text(
              'Pricing & Profit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            
            // Three pricing fields
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money_off),
                      helperText: 'Your purchase cost',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}), // Trigger rebuild for indicators
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellingPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Selling Price *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sell),
                      helperText: 'Customer pays',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val!.isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _mrpController,
                    decoration: const InputDecoration(
                      labelText: 'MRP',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                      helperText: 'Max retail price',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Visual Indicators
            _buildPricingIndicators(),
            
            const SizedBox(height: 24),
            
            // Unit field
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit (e.g. 1kg, 500g, 1L) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.scale),
              ),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Brand',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.branding_watermark),
              ),
            ),
            const SizedBox(height: 16),

            // Category Selection
            _buildCategorySelection(),
            const SizedBox(height: 16),

            // Dynamic Specifications
            if (_currentTemplate != null) ...[
              const Text(
                'Product Specifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DynamicSpecificationRenderer(
                  fields: _currentTemplate!.fields,
                  initialValues: _specifications,
                  isSellerMode: true,
                  onValuesChanged: (values) {
                    setState(() => _specifications = values);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            
            const SizedBox(height: 24),
            
            // SEO Section (Collapsible)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ExpansionTile(
                title: const Text('SEO & Discovery', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Add keywords to improve search visibility'),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                   TextFormField(
                    controller: _seoTitleController,
                    decoration: const InputDecoration(
                      labelText: 'SEO Title',
                      border: OutlineInputBorder(),
                      helperText: 'Title shown in search engines',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _seoDescController,
                    decoration: const InputDecoration(
                      labelText: 'SEO Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  KeywordSuggestionWidget(
                    categoryName: _selectedCategory ?? '',
                    productTitle: _nameController.text,
                    initialKeywords: _keywords,
                    onKeywordsChanged: (k) => setState(() => _keywords = k),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _saveDraft,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.orange, width: 2),
                      foregroundColor: Colors.orange,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Save as Draft'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, size: 20),
                              SizedBox(width: 8),
                              Text('Submit for Approval'),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Product Images',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${_imageUrls.length}/5',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Add Button
                if (_imageUrls.length < 5)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('Add', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                
                // Existing Images
                ..._imageUrls.asMap().entries.map((entry) {
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                          image: DecorationImage(
                            image: NetworkImage(entry.value),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _imageUrls.removeAt(entry.key)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTemplate() async {
    if (_selectedCategoryId == null) return;
    
    setState(() {
      _isLoading = true;
      // Keep existing values that match new fields? 
      // For now reset to empty or keep map if keys match.
      // Better to clear to avoid stale data unless we map it intelligently.
      // But clearing wipes user data if they just switch subcat misclick.
      // Let's keep data, renderer handles extra keys gracefully.
    });

    try {
      final template = await _categorySpecService.getSpecificationTemplate(
        _selectedCategoryId!,
        _selectedCategory!,
      );
      
      if (mounted) {
        setState(() {
          _currentTemplate = template;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading template: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Category *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        
        // Selected Category Display
        if (_selectedCategoryId != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF34A853)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF34A853)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCategory ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (_selectedCategoryPathNames.isNotEmpty)
                        Text(
                          'Path: ${_selectedCategoryPathNames.join(' > ')} > $_selectedCategory',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryId = null;
                      _selectedCategory = null;
                      _selectedCategoryPath.clear();
                      _selectedCategoryPathNames.clear();
                      _selectedCategoryLevel = 0;
                      _currentTemplate = null;
                    });
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        
        // Category Selector Button/Modal
        if (_selectedCategoryId == null)
          OutlinedButton.icon(
            onPressed: () => _showCategorySelector(),
            icon: const Icon(Icons.category),
            label: const Text('Select Category'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
      ],
    );
  }
  
  void _showCategorySelector() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 700,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Category',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _currentParentId = null;
                        _breadcrumbIds.clear();
                        _breadcrumbNames.clear();
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF34A853), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Breadcrumb
              if (_breadcrumbNames.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _currentParentId = null;
                            _breadcrumbIds.clear();
                            _breadcrumbNames.clear();
                          });
                        },
                        child: Text('Root', style: TextStyle(color: Colors.blue[700], fontSize: 12)),
                      ),
                      for (int i = 0; i < _breadcrumbNames.length; i++) ...[
                        Text('>', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
                          child: Text(
                            _breadcrumbNames[i],
                            style: TextStyle(
                              color: i < _breadcrumbNames.length - 1 ? Colors.blue[700] : Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Category List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _currentParentId == null
                      ? FirebaseFirestore.instance
                          .collection('categories')
                          .where('parent_id', isEqualTo: null)
                          .snapshots()
                      : FirebaseFirestore.instance
                          .collection('categories')
                          .where('parent_id', isEqualTo: _currentParentId)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    // Filter by level: Only show Level 0 categories at root
                    var allCategories = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (_currentParentId == null) {
                        return (data['level'] ?? 0) == 0;
                      }
                      return true;
                    }).toList();
                    
                    // Apply search filter if search query exists
                    if (_searchQuery.isNotEmpty) {
                      allCategories = allCategories.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final pathNames = List<String>.from(data['path_names'] ?? []);
                        final fullPath = pathNames.join(' ').toLowerCase() + ' ' + name;
                        return name.contains(_searchQuery) || fullPath.contains(_searchQuery);
                      }).toList();
                    }
                    
                    // Sort by sort_order, then name
                    allCategories.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aOrder = aData['sort_order'] ?? 0;
                      final bOrder = bData['sort_order'] ?? 0;
                      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
                      final aName = aData['name'] ?? '';
                      final bName = bData['name'] ?? '';
                      return aName.compareTo(bName);
                    });
                    
                    if (allCategories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_open,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No categories found matching "$_searchQuery"'
                                  : (_currentParentId == null
                                      ? 'No root categories available'
                                      : 'No subcategories'),
                              style: TextStyle(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      itemCount: allCategories.length,
                      itemBuilder: (context, index) {
                        final doc = allCategories[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final categoryId = doc.id;
                        final name = data['name'] ?? 'Category';
                        final iconUrl = data['icon'];
                        
                        return FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('categories')
                              .where('parent_id', isEqualTo: categoryId)
                              .limit(1)
                              .get(),
                          builder: (context, childrenSnapshot) {
                            final hasChildren = childrenSnapshot.hasData && childrenSnapshot.data!.docs.isNotEmpty;
                            
                            final isSelected = _selectedCategoryId == categoryId;
                        
                        return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              elevation: isSelected ? 4 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF34A853) : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF34A853).withOpacity(0.1) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: iconUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            iconUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(
                                              hasChildren ? Icons.folder : Icons.category,
                                              color: isSelected ? const Color(0xFF34A853) : Colors.grey[600],
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          hasChildren ? Icons.folder : Icons.category,
                                          color: isSelected ? const Color(0xFF34A853) : Colors.grey[600],
                                        ),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF34A853) : Colors.black87,
                                  ),
                                ),
                                subtitle: hasChildren
                                    ? Text(
                                        'Tap to browse subcategories',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      )
                                    : null,
                                trailing: hasChildren
                                    ? IconButton(
                                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                        onPressed: () {
                                          setState(() {
                                            _breadcrumbIds.add(categoryId);
                                            _breadcrumbNames.add(name);
                                            _currentParentId = categoryId;
                                            _searchQuery = '';
                                            _searchController.clear();
                                          });
                                        },
                                        color: const Color(0xFF34A853),
                                      )
                                    : (isSelected
                                        ? const Icon(Icons.check_circle, color: Color(0xFF34A853))
                                        : null),
                                onTap: () {
                                  // Select this category
                                  setState(() {
                                    _selectedCategoryId = categoryId;
                                    _selectedCategory = name;
                                    _selectedCategoryLevel = data['level'] ?? 0;
                                    _selectedCategoryPath = List<String>.from(data['path'] ?? []);
                                    _selectedCategoryPathNames = List<String>.from(data['path_names'] ?? []);
                                    _currentTemplate = null;
                                  });
                                  Navigator.pop(context);
                                  _loadTemplate();
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentParentId = null;
                        _breadcrumbIds.clear();
                        _breadcrumbNames.clear();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
