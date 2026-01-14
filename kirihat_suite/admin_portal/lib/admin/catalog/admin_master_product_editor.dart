import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/category_specification_model.dart';
import 'package:kirihat_core/services/cloudinary_service.dart';
import 'package:kirihat_core/services/category_specification_service.dart';
import 'package:kirihat_core/services/seller_service.dart';
import '../../seller/products/widgets/progress_indicator_widget.dart';
import '../../seller/products/widgets/dynamic_specification_renderer.dart';
import '../../seller/products/widgets/keyword_suggestion_widget.dart';

class AdminMasterProductEditor extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> product;

  const AdminMasterProductEditor({
    super.key, 
    required this.docId, 
    required this.product
  });

  @override
  State<AdminMasterProductEditor> createState() => _AdminMasterProductEditorState();
}

class _AdminMasterProductEditorState extends State<AdminMasterProductEditor> {
  final _formKey = GlobalKey<FormState>();
  final _specService = CategorySpecificationService();
  bool _isLoading = false;

  // Current step
  int _currentStep = 0;
  final int _totalSteps = 7; // Category, Info, Specs, Pricing(MRP), Images, SEO, Review

  final List<String> _stepLabels = [
    'Category',
    'Basic Info',
    'Specs',
    'Pricing',
    'Images',
    'SEO',
    'Review',
  ];

  // Step 1: Category Selection (Hierarchical)
  String? _selectedCategory;
  String? _selectedCategoryId;
  List<String> _selectedCategoryPath = [];
  List<String> _selectedCategoryPathNames = [];
  int _selectedCategoryLevel = 0;
  
  // For navigation within category tree
  String? _currentParentId;
  List<String> _breadcrumbIds = [];
  List<String> _breadcrumbNames = [];

  // Step 2: Basic Information
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _unitController = TextEditingController();
  final _barcodeController = TextEditingController();
  bool _isActive = true;

  // Step 3: Specifications (dynamic)
  CategorySpecification? _template;
  Map<String, dynamic> _specifications = {};

  // Step 4: Pricing (MRP Only for Master)
  final _mrpController = TextEditingController();
  final _costPriceController = TextEditingController(); // NEW
  final _sellingPriceController = TextEditingController(); // NEW

  // Step 5: Images
  List<dynamic> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();

  // Step 6: SEO
  final _seoTitleController = TextEditingController();
  final _seoDescController = TextEditingController();
  List<String> _keywords = []; // Using as "tags"

  // NEW: Basic Info Fields
  final _unitValueController = TextEditingController();
  String? _selectedUnitType;
  final List<String> _unitTypes = ['g', 'kg', 'ml', 'L', 'pc', 'box', 'pack', 'dozen'];
  
  // Product Dimensions (No Package)
  final _dimLengthController = TextEditingController();
  final _dimBreadthController = TextEditingController();
  final _dimHeightController = TextEditingController();
  final _netWeightController = TextEditingController();
  
  // Package Dimensions
  final _pkgLengthController = TextEditingController();
  final _pkgBreadthController = TextEditingController();
  final _pkgHeightController = TextEditingController();
  final _grossWeightController = TextEditingController();

  // Pricing - GST
  bool _gstAvailable = false;
  final _igstController = TextEditingController();
  final _cgstController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    var data = widget.product;
    _nameController.text = data['name'] ?? '';
    _brandController.text = data['brand'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _shortDescController.text = data['short_description'] ?? '';
    _unitController.text = data['unit'] ?? '';
    _barcodeController.text = data['barcode'] ?? '';
    _barcodeController.text = data['barcode'] ?? '';
    _mrpController.text = data['mrp']?.toString() ?? '';
    _costPriceController.text = data['cost_price']?.toString() ?? ''; 
    _sellingPriceController.text = data['price']?.toString() ?? '';
    
    // NEW: Load new fields
    // Unit (Try to parse if exists as single string or object)
    if (data['unit_value'] != null) {
      _unitValueController.text = data['unit_value'].toString();
      _selectedUnitType = data['unit_type'];
    } else if (data['unit'] != null) {
      // Legacy fallback: try to split '500 g'
      final parts = data['unit'].toString().split(' ');
      if (parts.isNotEmpty) _unitValueController.text = parts[0];
      if (parts.length > 1) _selectedUnitType = parts[1];
    }
    if (_selectedUnitType != null && !_unitTypes.contains(_selectedUnitType)) {
      _selectedUnitType = null; // Reset if invalid
    }
    
    // Dimensions
    if (data['dimensions'] != null) {
      final dims = data['dimensions'];
      if (dims['product'] != null) {
        _dimLengthController.text = dims['product']['length']?.toString() ?? '';
        _dimBreadthController.text = dims['product']['breadth']?.toString() ?? '';
        _dimHeightController.text = dims['product']['height']?.toString() ?? '';
        _netWeightController.text = dims['product']['net_weight']?.toString() ?? '';
      }
      if (dims['package'] != null) {
        _pkgLengthController.text = dims['package']['length']?.toString() ?? '';
        _pkgBreadthController.text = dims['package']['breadth']?.toString() ?? '';
        _pkgHeightController.text = dims['package']['height']?.toString() ?? '';
        _grossWeightController.text = dims['package']['gross_weight']?.toString() ?? '';
      }
    }
    
    // GST
    if (data['gst'] != null) {
      _gstAvailable = data['gst']['available'] ?? false;
      _igstController.text = data['gst']['igst']?.toString() ?? '';
      _cgstController.text = data['gst']['cgst']?.toString() ?? '';
    }
    
    _selectedCategory = data['category'];
    _isActive = data['isActive'] ?? true;
    
    // Try to load category path if available
    if (data['category_path_names'] != null) {
      _selectedCategoryPathNames = List<String>.from(data['category_path_names']);
    }
    if (data['category_level'] != null) {
      _selectedCategoryLevel = data['category_level'] as int;
    }
    _imageUrls = List.from(data['images'] ?? []);
    
    _seoTitleController.text = data['seo_title'] ?? '';
    _seoDescController.text = data['seo_description'] ?? '';
    
    if (data['tags'] != null) {
      _keywords = List<String>.from(data['tags']);
    }

    if (data['specifications'] != null) {
      _specifications = Map<String, dynamic>.from(data['specifications']);
    }

    // Look up category IDs for fetching specs template
    // This is async in background, usually we trust the name or need to fetch ID 
    // We'll rely on _selectedCategory name for UI but we need ID for template loading.
    // Let's try to find the ID from Firestore based on name if not present.
    _fetchCategoryIds();
  }

  Future<void> _fetchCategoryIds() async {
    if (_selectedCategory == null) return;
    
    // Search for category by name - could be at any level
    var catQuery = await FirebaseFirestore.instance
        .collection('categories')
        .where('name', isEqualTo: _selectedCategory)
        .limit(1)
        .get();
        
    if (catQuery.docs.isNotEmpty) {
      if (mounted) {
        final doc = catQuery.docs.first;
        final docData = doc.data();
        setState(() {
          _selectedCategoryId = doc.id;
          _selectedCategoryLevel = docData['level'] ?? 0;
          _selectedCategoryPath = List<String>.from(docData['path'] ?? []);
          _selectedCategoryPathNames = List<String>.from(docData['path_names'] ?? []);
        });
        
        // Load Template now that we have ID
        _loadSpecificationTemplate();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _shortDescController.dispose();
    _unitController.dispose();
    _barcodeController.dispose();
    _barcodeController.dispose();
    _mrpController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _seoTitleController.dispose();
    _seoDescController.dispose();
    
    // New Controllers Dispose
    _unitValueController.dispose();
    _dimLengthController.dispose();
    _dimBreadthController.dispose();
    _dimHeightController.dispose();
    _netWeightController.dispose();
    _pkgLengthController.dispose();
    _pkgBreadthController.dispose();
    _pkgHeightController.dispose();
    _grossWeightController.dispose();
    _igstController.dispose();
    _cgstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Master Product'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress Indicator
          ProgressIndicatorWidget(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
            stepLabels: _stepLabels,
          ),
          
          const Divider(height: 1),

          // Step Content
          Expanded(
            child: Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),

          // Navigation Buttons
          _buildNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildCategorySelection();
      case 1:
        return _buildBasicInformation();
      case 2:
        return _buildSpecifications();
      case 3:
        return _buildPricing();
      case 4:
        return _buildImages();
      case 5:
        return _buildSEO();
      case 6:
        return _buildReview();
      default:
        return const Center(child: Text('Invalid step'));
    }
  }

  // STEP 1: Category Selection (Hierarchical)
  Widget _buildCategorySelection() {
    return Column(
      children: [
        // Selected Category Display Banner
        if (_selectedCategoryId != null)
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0D9759).withOpacity(0.1), const Color(0xFF0D9759).withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0D9759), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9759).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D9759),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Category',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0D9759),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedCategory ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFF0D9759),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategoryId = null;
                          _selectedCategory = null;
                          _selectedCategoryPath.clear();
                          _selectedCategoryPathNames.clear();
                          _selectedCategoryLevel = 0;
                          _specifications = {};
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: 'Change Category',
                    ),
                  ],
                ),
                if (_selectedCategoryPathNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_tree, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_selectedCategoryPathNames.join(' > ')} > $_selectedCategory',
                            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Main Selection Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.category, color: Color(0xFF0D9759), size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Select Category',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Breadcrumb Navigation
                if (_breadcrumbNames.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.navigation, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _currentParentId = null;
                                      _breadcrumbIds.clear();
                                      _breadcrumbNames.clear();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.blue[300]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.home, size: 14, color: Colors.blue[700]),
                                        const SizedBox(width: 4),
                                        Text('Root', style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                                for (int i = 0; i < _breadcrumbNames.length; i++) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                                  ),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: i < _breadcrumbNames.length - 1 ? Colors.white : Colors.blue[100],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: i < _breadcrumbNames.length - 1 ? Colors.blue[300]! : Colors.blue[400]!,
                                        ),
                                      ),
                                      child: Text(
                                        _breadcrumbNames[i],
                                        style: TextStyle(
                                          color: i < _breadcrumbNames.length - 1 ? Colors.blue[700] : Colors.blue[900],
                                          fontSize: 12,
                                          fontWeight: i < _breadcrumbNames.length - 1 ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Category Grid
                Expanded(
                  child: _buildCategoryGrid(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCategoryGrid() {
    return StreamBuilder<QuerySnapshot>(
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
        var categories = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (_currentParentId == null) {
            return (data['level'] ?? 0) == 0;
          }
          return true;
        }).toList();

        // Sort by sort_order, then by name
        categories.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aOrder = aData['sort_order'] ?? 0;
          final bOrder = bData['sort_order'] ?? 0;
          if (aOrder != bOrder) return aOrder.compareTo(bOrder);
          final aName = aData['name'] ?? '';
          final bName = bData['name'] ?? '';
          return aName.compareTo(bName);
        });

        if (categories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    _currentParentId == null
                        ? 'No root categories available (Level 0)'
                        : 'No subcategories in this category',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            var category = categories[index];
            var data = category.data() as Map<String, dynamic>;
            final categoryId = category.id;
            final name = data['name'] ?? 'Category';
            final level = data['level'] ?? 0;
            final iconUrl = data['icon'];
            final isSelected = _selectedCategoryId == categoryId;

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('categories')
                  .where('parent_id', isEqualTo: categoryId)
                  .limit(1)
                  .get(),
              builder: (context, childrenSnapshot) {
                final hasChildren = childrenSnapshot.hasData && childrenSnapshot.data!.docs.isNotEmpty;
                
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Select this category
                      if (_selectedCategoryId != categoryId) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Category selected. Specifications will be loaded.")),
                        );
                        setState(() {
                          _selectedCategoryId = categoryId;
                          _selectedCategory = name;
                          _selectedCategoryLevel = level;
                          _selectedCategoryPath = List<String>.from(data['path'] ?? []);
                          _selectedCategoryPathNames = List<String>.from(data['path_names'] ?? []);
                          _specifications = {}; // Reset specs
                        });
                        _loadSpecificationTemplate();
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [const Color(0xFF0D9759).withOpacity(0.15), const Color(0xFF0D9759).withOpacity(0.05)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : Colors.white,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0D9759) : Colors.grey[300]!,
                          width: isSelected ? 2.5 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0D9759).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0D9759).withOpacity(0.1) : Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: iconUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          iconUrl,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            hasChildren ? Icons.folder : Icons.category,
                                            size: 32,
                                            color: isSelected ? const Color(0xFF0D9759) : Colors.grey[600],
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        hasChildren ? Icons.folder : Icons.category,
                                        size: 32,
                                        color: isSelected ? const Color(0xFF0D9759) : Colors.grey[600],
                                      ),
                              ),
                              if (hasChildren)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_forward, size: 12, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? const Color(0xFF0D9759) : Colors.black87,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasChildren && !isSelected) ...[
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () => _navigateIntoCategory(categoryId, name),
                              icon: const Icon(Icons.arrow_forward, size: 12),
                              label: const Text('Browse', style: TextStyle(fontSize: 10)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 24),
                                side: const BorderSide(color: Colors.blue, width: 1),
                              ),
                            ),
                          ],
                          if (isSelected) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9759),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Selected', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  // Helper to navigate into category
  void _navigateIntoCategory(String categoryId, String categoryName) {
    setState(() {
      _breadcrumbIds.add(categoryId);
      _breadcrumbNames.add(categoryName);
      _currentParentId = categoryId;
    });
  }

  // STEP 2: Basic Information
  Widget _buildBasicInformation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Product Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'All fields are mandatory.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 32),

          // 1. Brand Name & Product Title
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(
                    labelText: 'Brand Name *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Samsung, Nike',
                  ),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Title *',
                    border: OutlineInputBorder(),
                    hintText: 'Full product name',
                  ),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Unit
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _unitValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Unit Value *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 500, 1',
                  ),
                  validator: (v) {
                    if (v?.trim().isEmpty == true) return 'Required';
                    if (double.tryParse(v!) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedUnitType,
                  decoration: const InputDecoration(
                    labelText: 'Unit Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: _unitTypes.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (val) => setState(() => _selectedUnitType = val),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 3. Product Dimensions (Without Package)
          const Text('Product Dimensions (Without Package)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDimField(_dimLengthController, 'Length (cm)')),
              const SizedBox(width: 12),
              Expanded(child: _buildDimField(_dimBreadthController, 'Breadth (cm)')),
              const SizedBox(width: 12),
              Expanded(child: _buildDimField(_dimHeightController, 'Height (cm)')),
              const SizedBox(width: 12),
              Expanded(child: _buildDimField(_netWeightController, 'Net Weight (g)')),
            ],
          ),
          const SizedBox(height: 32),

          // 4. Product Dimensions (With Package)
          const Text('Package Dimensions (With Packaging)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDimField(_pkgLengthController, 'Length (cm)')),
              const SizedBox(width: 12),
              Expanded(child: _buildDimField(_pkgBreadthController, 'Breadth (cm)')),
              const SizedBox(width: 12),
              Expanded(child: _buildDimField(_pkgHeightController, 'Height (cm)')),
              const SizedBox(width: 12),
              Expanded(child: _buildDimField(_grossWeightController, 'Gross Weight (g)')),
            ],
          ),
          const SizedBox(height: 32),

          // 5. Barcode
          TextFormField(
            controller: _barcodeController,
            decoration: const InputDecoration(
              labelText: 'Barcode *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code),
            ),
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDimField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '$label *',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      validator: (v) {
        if (v?.trim().isEmpty == true) return 'Req';
        if (double.tryParse(v!) == null) return 'Invalid';
        return null;
      },
    );
  }


  // STEP 3: Specifications
  Widget _buildSpecifications() {
     if (_template == null && _selectedCategoryId != null) {
         // Retry loading if template is missing but category selected (maybe network delay)
         _loadSpecificationTemplate();
     }
     
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                 const Text("Specifications", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                 Text("Define specs for $_selectedCategory", style: TextStyle(color: Colors.grey[600]))
             ],
          )
        ),
        _template != null && _template!.fields.isNotEmpty
            ? Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DynamicSpecificationRenderer(
                    fields: _template!.fields,
                    initialValues: _specifications,
                    onValuesChanged: (values) {
                      _specifications = values;
                    },
                  ),
                ),
              )
            : const Expanded(
                child: Center(
                  child: Text("Select a category to view specs or no specs defined for this category")
                ),
              ),
      ],
    );
  }



  // STEP 4: Pricing
  Widget _buildPricing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pricing & Tax', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Existing Price Fields
          Row(
            children: [
               Expanded(
                 child: TextFormField(
                   controller: _mrpController,
                   keyboardType: TextInputType.number,
                   decoration: const InputDecoration(labelText: 'MRP *', border: OutlineInputBorder(), prefixText: '\u20B9 '),
                   validator: (v) => v?.isEmpty == true ? 'Required' : null,
                 ),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: TextFormField(
                   controller: _sellingPriceController,
                   keyboardType: TextInputType.number,
                   decoration: const InputDecoration(labelText: 'Selling Price *', border: OutlineInputBorder(), prefixText: '\u20B9 '),
                   validator: (v) => v?.isEmpty == true ? 'Required' : null,
                 ),
               ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
             controller: _costPriceController,
             keyboardType: TextInputType.number,
             decoration: const InputDecoration(labelText: 'Cost Price *', border: OutlineInputBorder(), prefixText: '\u20B9 '),
             validator: (v) => v?.isEmpty == true ? 'Required' : null,
          ),
          
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          
          // NEW: GST Section
          const Text('Goods and Services Tax (GST)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<bool>(
            value: _gstAvailable,
            items: const [
              DropdownMenuItem(value: true, child: Text("Yes, GST Applicable")),
              DropdownMenuItem(value: false, child: Text("No, Exempted")),
            ],
            onChanged: (val) => setState(() => _gstAvailable = val ?? false),
            decoration: const InputDecoration(labelText: 'GST Available? *', border: OutlineInputBorder()),
          ),
          
          if (_gstAvailable) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _igstController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'IGST (%) *', border: OutlineInputBorder(), suffixText: '%'),
                    validator: (v) => _gstAvailable && v?.isEmpty == true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cgstController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'CGST (%) *', border: OutlineInputBorder(), suffixText: '%'),
                    validator: (v) => _gstAvailable && v?.isEmpty == true ? 'Required' : null,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 24),
          _buildPricingIndicators(),
        ],
      ),
    );
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
        if (profitMargin > 0) ...[
          Row(
            children: [
              const Icon(Icons.trending_up, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Profit Margin: ${profitMargin.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: [Colors.green.shade100, Colors.green.shade400]),
            ),
            child: Row(
              children: [
                Container(
                  width: (profitMargin.clamp(0, 100) / 100) * MediaQuery.of(context).size.width * 0.4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Profit: \u20B9${(sellingPrice - costPrice).toStringAsFixed(2)} per unit',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
        ],

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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discount: \u20B9${(mrp - sellingPrice).toStringAsFixed(2)} off MRP', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('\u20B9$mrp \u2192 \u20B9$sellingPrice', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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

  // STEP 5: Images
  Widget _buildImages() {
     return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Images', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.upload),
                label: const Text("Upload"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9759), foregroundColor: Colors.white)
              )
            ],
          ),
          const SizedBox(height: 20),
          
          if (_imageUrls.isEmpty)
             Container(
               height: 200,
               decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
               child: const Center(child: Text("No images uploaded")),
             )
          else
             Wrap(
               spacing: 12,
               runSpacing: 12,
               children: _imageUrls.asMap().entries.map((entry) {
                  return Stack(
                    children: [
                        Container(
                           width: 150, height: 150,
                           decoration: BoxDecoration(
                               border: Border.all(color: Colors.grey.shade300),
                               borderRadius: BorderRadius.circular(8),
                               image: DecorationImage(image: NetworkImage(entry.value), fit: BoxFit.cover)
                           ),
                        ),
                        Positioned(
                             top: 4, right: 4,
                             child: IconButton(
                                 onPressed: () => setState(() => _imageUrls.removeAt(entry.key)),
                                 icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                 style: IconButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(4)),
                             )
                        )
                    ],
                  );
               }).toList(),
             )
        ],
      ),
     );
  }

  // STEP 6: SEO
  Widget _buildSEO() {
     return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              const Text('SEO & Discovery', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              
              TextFormField(
                  controller: _seoTitleController,
                  decoration: const InputDecoration(labelText: 'SEO Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                  controller: _seoDescController,
                  decoration: const InputDecoration(labelText: 'SEO Description', border: OutlineInputBorder()),
                  maxLines: 3,
              ),
              const SizedBox(height: 32),
              
              KeywordSuggestionWidget(
                  categoryName: _selectedCategory ?? '',
                  productTitle: _nameController.text,
                  initialKeywords: _keywords,
                  onKeywordsChanged: (k) => setState(() => _keywords = k),
              ),
          ],
      ),
     );
  }
  
  // STEP 7: Review
  Widget _buildReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Text("Review Changes", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
           const SizedBox(height: 20),
           
           _buildReviewSection("Basic Info", [
               "Name: ${_nameController.text}",
               "Brand: ${_brandController.text}",
               "Category: $_selectedCategory",
               if (_selectedCategoryPathNames.isNotEmpty) "Path: ${_selectedCategoryPathNames.join(' > ')} > $_selectedCategory",
               "Level: $_selectedCategoryLevel",
               "Active: $_isActive"
           ], () => setState(() => _currentStep = 1)),
           
           _buildReviewSection("Pricing", ["MRP: ${_mrpController.text}"], () => setState(() => _currentStep = 3)),
           
           _buildReviewSection("Images", ["${_imageUrls.length} images"], () => setState(() => _currentStep = 4)),
           
           _buildReviewSection("SEO", ["Keywords: ${_keywords.length}"], () => setState(() => _currentStep = 5)),
        ],
      ),
    );
  }
  
  Widget _buildReviewSection(String title, List<String> items, VoidCallback onEdit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                 TextButton(onPressed: onEdit, child: const Text("Edit"))
             ]),
             const Divider(),
             ...items.map((i) => Text(i)).toList()
         ],
      ),
    );
  }

  Widget _buildNavigationBar() {
      return Container(
         padding: const EdgeInsets.all(20),
         decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
         child: Row(
            children: [
                if (_currentStep > 0)
                   Expanded(
                       child: OutlinedButton(
                           onPressed: () => setState(() => _currentStep--),
                           style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                           child: const Text("Previous"),
                       )
                   ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                    flex: 2,
                    child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleNext,
                         style: ElevatedButton.styleFrom(
                             backgroundColor: const Color(0xFF0D9759),
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 16),
                         ),
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_currentStep == _totalSteps - 1 ? "Update Product" : "Next"),
                    )
                )
            ],
         ),
      );
  }

  void _handleNext() {
      if (_currentStep == 0 && _selectedCategoryId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select Category")));
          return;
      }
      if (_currentStep == 1 && !_formKey.currentState!.validate()) return;
      if (_currentStep == 3 && !_formKey.currentState!.validate()) return;
      
      if (_currentStep < _totalSteps - 1) {
          setState(() => _currentStep++);
      } else {
          _updateMasterProduct();
      }
  }

  Future<void> _loadSpecificationTemplate() async {
    if (_selectedCategoryId == null) return;
    _template = await _specService.getSpecificationTemplate(
      _selectedCategoryId!,
      _selectedCategory!,
    );
    setState(() {});
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(limit: 5 - _imageUrls.length);
    if (images.isEmpty) return;
    setState(() => _isLoading = true);
    for (var img in images) {
      var bytes = await img.readAsBytes();
      String? url = await CloudinaryService.uploadImage(bytes, folder: "master_products");
      if (url != null && mounted) setState(() => _imageUrls.add(url));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateMasterProduct() async {
      setState(() => _isLoading = true);
      try {
          // Construct Data
          Map<String, dynamic> data = {
              'name': _nameController.text.trim(),
              'brand': _brandController.text.trim(),
              'description': _descriptionController.text.trim(),
              'short_description': _shortDescController.text.trim(),
              
              // NEW FIELDS
              'barcode': _barcodeController.text.trim(),
              'unit': '${_unitValueController.text} ${_selectedUnitType ?? ''}'.trim(), // Composite
              'unit_value': double.tryParse(_unitValueController.text),
              'unit_type': _selectedUnitType,
              
              'mrp': double.parse(_mrpController.text),
              'cost_price': double.tryParse(_costPriceController.text) ?? 0,
              'price': double.tryParse(_sellingPriceController.text) ?? 0,
              'selling_price': double.tryParse(_sellingPriceController.text) ?? 0, // Ensure selling_price is set
              
              'dimensions': {
                'product': {
                  'length': double.tryParse(_dimLengthController.text),
                  'breadth': double.tryParse(_dimBreadthController.text),
                  'height': double.tryParse(_dimHeightController.text),
                  'net_weight': double.tryParse(_netWeightController.text),
                },
                'package': {
                  'length': double.tryParse(_pkgLengthController.text),
                  'breadth': double.tryParse(_pkgBreadthController.text),
                  'height': double.tryParse(_pkgHeightController.text),
                  'gross_weight': double.tryParse(_grossWeightController.text),
                }
              },
              'gst': {
                'available': _gstAvailable,
                'igst': _gstAvailable ? double.tryParse(_igstController.text) : 0,
                'cgst': _gstAvailable ? double.tryParse(_cgstController.text) : 0,
              },

              'category': _selectedCategory,
              'category_id': _selectedCategoryId,
              'category_level': _selectedCategoryLevel,
              'category_path': _selectedCategoryPath,
              'category_path_names': _selectedCategoryPathNames,
              'images': _imageUrls,
              'imageUrl': _imageUrls.isNotEmpty ? _imageUrls.first : null,
              'isActive': _isActive,
              'seo_title': _seoTitleController.text.trim(),
              'seo_description': _seoDescController.text.trim(),
              'tags': _keywords,
              'specifications': _specifications,
              'updated_at': FieldValue.serverTimestamp(),
          };
          
          // Use SellerService to update so that it triggers the Price Sync logic (Vendor Inventory Cascade)
          final sellerService = SellerService();
          await sellerService.updateProduct(widget.docId, data);
          
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Master Product Updated!")));
              Navigator.pop(context);
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
          if (mounted) setState(() => _isLoading = false);
      }
  }
}
