import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/models/category_specification_model.dart';
import 'package:kirihat_core/utils/currency_helper.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'package:kirihat_core/services/cloudinary_service.dart';
import 'package:kirihat_core/services/category_specification_service.dart';
import 'widgets/progress_indicator_widget.dart';
import 'widgets/dynamic_specification_renderer.dart';
import 'widgets/keyword_suggestion_widget.dart';

class EnhancedAddProductScreen extends StatefulWidget {
  final SellerModel seller;
  final String? draftId; // Optional draft ID to resume
  final Map<String, dynamic>? productToEdit; // Optional product to edit
  final String? requestToResubmitId; // For resubmitting rejected/revision request

  const EnhancedAddProductScreen({
    super.key,
    required this.seller,
    this.draftId,
    this.productToEdit,
    this.requestToResubmitId,
  });

  @override
  State<EnhancedAddProductScreen> createState() => _EnhancedAddProductScreenState();
}

class _EnhancedAddProductScreenState extends State<EnhancedAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sellerService = SellerService();
  final _specService = CategorySpecificationService();
  bool _isLoading = false;
  bool _isDraftLoaded = false;
  bool _isEditing = false;
  String? _currentDraftId; // Track which draft is being edited

  // Current step
  int _currentStep = 0;
  final int _totalSteps = 7;

  final List<String> _stepLabels = [
    'Category',
    'Basic Info',
    'Specifications',
    'Pricing',
    'Images',
    'Keywords',
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
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Step 2: Basic Information
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitController = TextEditingController(); // Legacy, to be removed or kept for safety? Keeping to minimize errors, but new UI uses _unitValueController
  
  // NEW: Basic Info Fields
  final _unitValueController = TextEditingController();
  final _barcodeController = TextEditingController();
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

  // GST
  bool _gstAvailable = false;
  final _igstController = TextEditingController();
  final _cgstController = TextEditingController();

  // Step 3: Specifications (dynamic)
  CategorySpecification? _template;
  Map<String, dynamic> _specifications = {};

  // Step 4: Pricing
  final _mrpController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController();

  // Step 5: Images
  List<dynamic> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();

  // Step 6: Keywords
  List<String> _keywords = [];

  @override
  void initState() {
    super.initState();
    // Use productToEdit if provided, otherwise draftId
    if (widget.productToEdit != null) {
        _loadProductToEdit();
    } else if (widget.draftId != null) {
      _loadDraft(widget.draftId!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose(); // Dispose MRP
    _quantityController.dispose();
    _searchController.dispose();
    
    // New Controllers Dispose
    _unitValueController.dispose();
    _barcodeController.dispose();
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
  
  void _loadProductToEdit() {
      final product = widget.productToEdit!;
      setState(() {
          _isEditing = true;
          _selectedCategory = product['category'];
          _selectedCategoryId = product['category_id'];
          _selectedCategoryLevel = product['category_level'] ?? 0;
          _selectedCategoryPath = List<String>.from(product['category_path'] ?? []);
          _selectedCategoryPathNames = List<String>.from(product['category_path_names'] ?? []);
          
          _nameController.text = product['name'] ?? '';
          _brandController.text = product['brand'] ?? '';
          _descriptionController.text = product['description'] ?? '';
          _unitController.text = product['unit'] ?? '';
          
          _costPriceController.text = product['cost_price']?.toString() ?? '';
          _sellingPriceController.text = product['selling_price']?.toString() ?? '';
          _mrpController.text = product['mrp']?.toString() ?? ''; // Load MRP
          _quantityController.text = product['stock_quantity']?.toString() ?? '0'; // Note: stock_quantity key
          
           if (product['specifications'] != null) {
            _specifications = Map<String, dynamic>.from(product['specifications']);
          }
          
          if (product['tags'] != null) { // Note: tags vs keywords
            _keywords = List<String>.from(product['tags']);
          }
          
          if (product['images'] != null) {
            _imageUrls = List<dynamic>.from(product['images']);
          }
          
          // Load New Fields
          _barcodeController.text = product['barcode'] ?? '';
          if (product['unit_value'] != null) {
            _unitValueController.text = product['unit_value'].toString();
            _selectedUnitType = product['unit_type'];
          }
          if (product['dimensions'] != null) {
             final dims = product['dimensions'];
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
          if (product['gst'] != null) {
             _gstAvailable = product['gst']['available'] ?? false;
             _igstController.text = product['gst']['igst']?.toString() ?? '';
             _cgstController.text = product['gst']['cgst']?.toString() ?? '';
          }
      });
  }

  // Load draft by ID
  Future<void> _loadDraft(String draftId) async {
    try {
      final draftDoc = await _sellerService.getProductDraftById(draftId);
      if (draftDoc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final draft = draftDoc['draft_data'] as Map<String, dynamic>?;
      if (draft != null && mounted) {
        setState(() {
          _selectedCategory = draft['category'];
          _selectedCategoryId = draft['category_id'];
          _selectedCategoryLevel = draft['category_level'] ?? 0;
          _selectedCategoryPath = List<String>.from(draft['category_path'] ?? []);
          _selectedCategoryPathNames = List<String>.from(draft['category_path_names'] ?? []);
          
          _nameController.text = draft['name'] ?? '';
          _brandController.text = draft['brand'] ?? '';
          _descriptionController.text = draft['description'] ?? '';
          _unitController.text = draft['unit'] ?? '';
          
          _costPriceController.text = draft['cost_price']?.toString() ?? '';
          _sellingPriceController.text = draft['selling_price']?.toString() ?? '';
          _quantityController.text = draft['quantity']?.toString() ?? '';
          
          if (draft['specifications'] != null) {
            _specifications = Map<String, dynamic>.from(draft['specifications']);
          }
          
          if (draft['keywords'] != null) {
            _keywords = List<String>.from(draft['keywords']);
          }
          
          if (draft['images'] != null) {
            _imageUrls = List<dynamic>.from(draft['images']);
          }
           // Load New Fields
          _barcodeController.text = draft['barcode'] ?? '';
          if (draft['unit_value'] != null) {
            _unitValueController.text = draft['unit_value'].toString();
            _selectedUnitType = draft['unit_type'];
          }
          if (draft['dimensions'] != null) {
             final dims = draft['dimensions'];
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
          if (draft['gst'] != null) {
             _gstAvailable = draft['gst']['available'] ?? false;
             _igstController.text = draft['gst']['igst']?.toString() ?? '';
             _cgstController.text = draft['gst']['cgst']?.toString() ?? '';
          }
          
          _isDraftLoaded = true;
          _currentDraftId = draftId;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft loaded successfully'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading draft: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          setState(() => _currentStep--);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
               if (_currentStep > 0) {
                 setState(() => _currentStep--);
               } else {
                 Navigator.pop(context);
               }
            },
          ),
          title: Row(
            children: [
              const Text('Add New Product'),
              if (_isDraftLoaded) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Draft',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: const Color(0xFF34A853),
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
                child: _buildStepContent(),
              ),
            ),

            // Navigation Buttons
            _buildNavigationBar(),
          ],
        ),
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
        return _buildKeywords();
      case 6:
        return _buildReview();
      default:
        return const Center(child: Text('Invalid step'));
    }
  }

  // STEP 1: Category Selection
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
                colors: [const Color(0xFF34A853).withOpacity(0.1), const Color(0xFF34A853).withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF34A853), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34A853).withOpacity(0.2),
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
                        color: Color(0xFF34A853),
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
                              color: Color(0xFF34A853),
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
                              color: Color(0xFF34A853),
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
                          _currentParentId = null;
                          _breadcrumbIds.clear();
                          _breadcrumbNames.clear();
                          _searchQuery = '';
                          _searchController.clear();
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
                // Header with Search
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.category, color: Color(0xFF34A853), size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Select Category',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
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

                // Category Grid/List
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

        // Sort by sort_order, then by name
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
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No categories found matching "$_searchQuery"'
                      : (_currentParentId == null
                          ? 'No root categories available (Level 0)'
                          : 'No subcategories in this category'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (_searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Search'),
                    ),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: allCategories.length,
          itemBuilder: (context, index) {
            var category = allCategories[index];
            var data = category.data() as Map<String, dynamic>;
            final categoryId = category.id;
            final name = data['name'] ?? 'Category';
            final level = data['level'] ?? 0;
            final isSelected = _selectedCategoryId == categoryId;

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('categories')
                  .where('parent_id', isEqualTo: categoryId)
                  .limit(1)
                  .get(),
              builder: (context, childrenSnapshot) {
                final hasChildren = childrenSnapshot.hasData && childrenSnapshot.data!.docs.isNotEmpty;
                
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    color: isSelected ? const Color(0xFF34A853).withOpacity(0.05) : Colors.white,
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? const Color(0xFF34A853) : Colors.black87,
                            ),
                          ),
                        ),
                        if (hasChildren)
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 20,
                          )
                        else if (isSelected)
                          const Icon(
                            Icons.check,
                            color: Color(0xFF34A853),
                            size: 20,
                          ),
                      ],
                    ),
                    onTap: () {
                      if (hasChildren) {
                        // Navigate to subcategories
                        _navigateIntoCategory(categoryId, name);
                      } else {
                        // Select this category
                        setState(() {
                          _selectedCategoryId = categoryId;
                          _selectedCategory = name;
                          _selectedCategoryLevel = level;
                          _selectedCategoryPath = List<String>.from(data['path'] ?? []);
                          _selectedCategoryPathNames = List<String>.from(data['path_names'] ?? []);
                        });
                      }
                    },
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
    return FutureBuilder<void>(
      future: _loadSpecificationTemplate(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Specifications',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill in category-specific details for $_selectedCategory',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _template != null && _template!.fields.isNotEmpty
                  ? DynamicSpecificationRenderer(
                      fields: _template!.fields,
                      initialValues: _specifications,
                      isSellerMode: true, // Enforce locking for sellers
                      onValuesChanged: (values) {
                        // Update values without rebuilding the entire screen
                        _specifications = values;
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No additional specifications required',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You can proceed to the next step',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // STEP 4: Pricing
  Widget _buildPricing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricing & Stock',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Set your selling price and inventory.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 32),

          // Pricing Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _mrpController,
                  decoration: const InputDecoration(
                    labelText: 'MRP *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                    helperText: 'Max Retail Price',
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
            ],
          ),
          const SizedBox(height: 24),

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
                  validator: (val) {
                    if (val!.isEmpty) return 'Required';
                    if (double.tryParse(val) == null) return 'Invalid';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _sellingPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Selling Price *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sell),
                    helperText: 'Final price for customer',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val!.isEmpty) return 'Required';
                    final sp = double.tryParse(val);
                    if (sp == null) return 'Invalid';
                    
                    final mrpText = _mrpController.text;
                    if (mrpText.isNotEmpty) {
                      final mrp = double.tryParse(mrpText);
                      if (mrp != null && sp > mrp) {
                        return 'Cannot be > MRP';
                      }
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Profit Margin Display
          if (_sellingPriceController.text.isNotEmpty && _costPriceController.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF34A853)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Color(0xFF34A853)),
                  const SizedBox(width: 12),
                  Text(
                    'Profit Margin: ${double.parse(_calculateMargin().toStringAsFixed(1))}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF34A853),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
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

          TextFormField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Initial Quantity *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.inventory),
            ),
            keyboardType: TextInputType.number,
            validator: (val) {
              if (val!.isEmpty) return 'Required';
              int? qty = int.tryParse(val);
              if (qty == null) return 'Invalid';
              if (qty <= 0) return 'Must be positive';
              return null;
            },
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your selling price will be automatically synchronized to all vendors who add this product to their stores.',
                    style: TextStyle(color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            children: [
              const Text(
                'Product Images',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Upload and arrange images. The first image will be the main cover.',
                child: Icon(Icons.info_outline, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Upload high-quality images. Drag and drop to reorder.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 24),

          _buildInfoBox(
            '\u2022 Minimum resolution: 1000 x 1000 pixels\n'
            '\u2022 Supported formats: JPG, PNG\n'
            '\u2022 Maximum 5 images\n'
            '\u2022 Drag images to change their order',
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Uploaded Images (${_imageUrls.length}/5)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (_imageUrls.length < 5)
                      ElevatedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34A853),
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_imageUrls.isEmpty)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No images uploaded yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 220, // Height for the horizontal list
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = _imageUrls.removeAt(oldIndex);
                          _imageUrls.insert(newIndex, item);
                        });
                      },
                      itemCount: _imageUrls.length,
                      itemBuilder: (context, index) {
                        return Container(
                          key: ValueKey(_imageUrls[index]),
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                  image: DecorationImage(
                                    image: NetworkImage(_imageUrls[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              if (index == 0)
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF34A853),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Primary',
                                      style: TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () {
                                    setState(() => _imageUrls.removeAt(index));
                                  },
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(24, 24),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.drag_handle, 
                                    color: Colors.white, 
                                    size: 16
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // STEP 6: Keywords
  Widget _buildKeywords() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SEO Keywords',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose keywords to improve product discoverability',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 32),

          KeywordSuggestionWidget(
            categoryName: _selectedCategory ?? '',
            productTitle: _nameController.text,
            initialKeywords: _keywords,
            onKeywordsChanged: (keywords) {
              setState(() => _keywords = keywords);
            },
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
          const Text(
            'Review & Submit',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Review all information before submitting',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 32),

          _buildReviewSection('Category', [
            'Category: $_selectedCategory',
            if (_selectedCategoryPathNames.isNotEmpty) 'Path: ${_selectedCategoryPathNames.join(' > ')} > $_selectedCategory',
            if (_selectedCategoryLevel > 0) 'Level: $_selectedCategoryLevel',
          ], () => setState(() => _currentStep = 0)),

          _buildReviewSection('Basic Information', [
            'Title: ${_nameController.text}',
            'Brand: ${_brandController.text}',
            if (_unitController.text.isNotEmpty) 'Unit: ${_unitController.text}',
          ], () => setState(() => _currentStep = 1)),

          if (_specifications.isNotEmpty)
            _buildReviewSection(
              'Specifications',
              _specifications.entries.map((e) => '${e.key}: ${e.value}').toList(),
              () => setState(() => _currentStep = 2),
            ),

          _buildReviewSection('Pricing', [
            'MRP: ${CurrencyHelper.format(_mrpController.text.isEmpty ? 0 : double.tryParse(_mrpController.text))}',
            'Selling Price: ${CurrencyHelper.format(_sellingPriceController.text.isEmpty ? 0 : double.tryParse(_sellingPriceController.text))}',
            'Cost Price: ${CurrencyHelper.format(_costPriceController.text.isEmpty ? 0 : double.tryParse(_costPriceController.text))}',
            'Quantity: ${_quantityController.text}',
          ], () => setState(() => _currentStep = 3)),

          _buildReviewSection('Images', [
            '${_imageUrls.length} images uploaded',
          ], () => setState(() => _currentStep = 4)),

          _buildReviewSection('Keywords', [
            _keywords.join(', '),
          ], () => setState(() => _currentStep = 5)),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, List<String> items, VoidCallback onEdit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF34A853)),
              ),
            ],
          ),
          const Divider(),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(item, style: TextStyle(color: Colors.grey[700])),
              )),
        ],
      ),
    );
  }

  double _calculateMargin() {
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0;
    final costPrice = double.tryParse(_costPriceController.text) ?? 0;
    if (costPrice == 0) return 0;
    return ((sellingPrice - costPrice) / costPrice) * 100;
  }


  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _currentStep--),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          
          // Save as Draft button
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _saveDraft,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Draft'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Start New button (only show if draft is loaded)
          if (_isDraftLoaded)
            Expanded(
              flex: _currentStep == 0 ? 1 : 1,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _startNew,
                icon: const Icon(Icons.add),
                label: const Text('Start New'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          if (_isDraftLoaded) const SizedBox(width: 16),
          
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34A853),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_currentStep == _totalSteps - 1 ? 'Submit Request' : 'Next'),
                        const SizedBox(width: 8),
                        Icon(_currentStep == _totalSteps - 1 ? Icons.check : Icons.arrow_forward),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Start new product (clear form)
  void _startNew() {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Product?'),
        content: const Text(
          'Current changes will be lost if not saved. Do you want to start a new product listing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close current form
              // Re-open form without draft
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedAddProductScreen(
                    seller: widget.seller,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Start New'),
          ),
        ],
      ),
    );
  }

  // Save draft
  Future<void> _saveDraft() async {
    setState(() => _isLoading = true);

    try {
      final draftData = {
        'category': _selectedCategory,
        'category_id': _selectedCategoryId,
        'category_level': _selectedCategoryLevel,
        'category_path': _selectedCategoryPath,
        'category_path_names': _selectedCategoryPathNames,
        'name': _nameController.text.trim(),
        'brand': _brandController.text.trim(),
        'description': _descriptionController.text.trim(),
        'unit': _unitController.text.trim(),
        'cost_price': _costPriceController.text.isEmpty ? null : double.tryParse(_costPriceController.text),
        'selling_price': _sellingPriceController.text.isEmpty ? null : double.tryParse(_sellingPriceController.text),
        'mrp': _mrpController.text.isEmpty ? null : double.tryParse(_mrpController.text), // Added MRP
        'quantity': _quantityController.text.isEmpty ? null : int.tryParse(_quantityController.text),
        'specifications': _specifications,
        'keywords': _keywords,
        'images': _imageUrls,
        
        // NEW FIELDS for Draft
        'barcode': _barcodeController.text.trim(),
        'unit_value': double.tryParse(_unitValueController.text),
        'unit_type': _selectedUnitType,
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
          'igst': _igstController.text.isNotEmpty ? double.tryParse(_igstController.text) : null,
          'cgst': _cgstController.text.isNotEmpty ? double.tryParse(_cgstController.text) : null,
        },
      };

      final draftId = await _sellerService.saveProductDraft(
        widget.seller.id,
        draftData,
        draftId: _currentDraftId, // Update existing or create new
      );

      if (mounted && draftId != null) {
        setState(() {
          _isDraftLoaded = true;
          _currentDraftId = draftId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully!'),
            backgroundColor: Colors.blue,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save draft'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFF34A853)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSpecificationTemplate() async {
    if (_selectedCategoryId == null) return;
    
    _template = await _specService.getSpecificationTemplate(
      _selectedCategoryId!,
      _selectedCategory!,
    );

    // Auto-populate Brand from Basic Info if it exists in template
    if (_template != null && _brandController.text.isNotEmpty) {
      bool hasBrandField = _template!.fields.any((f) => f.fieldName == 'Brand');
      if (hasBrandField && (_specifications['Brand'] == null || _specifications['Brand'].toString().isEmpty)) {
        _specifications['Brand'] = _brandController.text;
      }
    }
  }

  void _handleNext() {
    // Validate current step
    if (!_validateCurrentStep()) return;

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _submitRequest();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedCategoryId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a category')),
          );
          return false;
        }
        return true;
      case 1:
      case 3:
        if (!_formKey.currentState!.validate()) return false;
        return true;
      case 4:
        if (_imageUrls.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please upload at least one image')),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(limit: 5 - _imageUrls.length);
    if (images.isEmpty) return;

    setState(() => _isLoading = true);

    for (var img in images) {
      var bytes = await img.readAsBytes();
      String? url = await CloudinaryService.uploadImage(bytes, folder: "seller_products");
      if (url != null) {
        setState(() => _imageUrls.add(url));
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _submitRequest() async {
    setState(() => _isLoading = true);

    try {
      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'mrp': double.parse(_mrpController.text),
        'selling_price': double.parse(_sellingPriceController.text),
        'cost_price': double.parse(_costPriceController.text),
        'quantity': int.parse(_quantityController.text),
        'brand': _brandController.text.trim(),
        // 'unit': _unitController.text.trim(), // Removed legacy unit field
        'category': _selectedCategory,
        'category_id': _selectedCategoryId,
        'category_level': _selectedCategoryLevel,
        'category_path': _selectedCategoryPath,
        'category_path_names': _selectedCategoryPathNames,
        'images': _imageUrls,
        'image_url': _imageUrls.isNotEmpty ? _imageUrls.first : null,
        'seller_id': widget.seller.id,
        'submitted_by_name': widget.seller.ownerName,
        'business_name': widget.seller.businessName,
        
        // NEW FIELDS
        'barcode': _barcodeController.text.trim(),
        'unit': '${_unitValueController.text} $_selectedUnitType', // Composite unit string
        'unit_value': double.tryParse(_unitValueController.text),
        'unit_type': _selectedUnitType,
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
      };

      // Add specifications and keywords to request
      final requestData = {
        ...productData,
        'specifications': _specifications,
        'keywords': _keywords,
        'template_version': _template?.version.toString(),
      };

      if (widget.requestToResubmitId != null) {
        // RESUBMIT REQUEST
        final success = await _sellerService.resubmitProductRequest(
          widget.requestToResubmitId!,
          requestData,
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Request updated and resubmitted successfully!')),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to resubmit request')),
            );
          }
        }
      } else if (_isEditing && widget.productToEdit != null) {
          // UPDATE EXISTING PRODUCT
          final updateData = {
              'name': productData['name'],
              'description': productData['description'],
              'mrp': productData['mrp'], // Explicit MRP update
              'price': productData['selling_price'], // 'price' is standard for selling price
              'selling_price': productData['selling_price'],
              'cost_price': productData['cost_price'],
              'stock_quantity': productData['quantity'], // Note: 'quantity' mapping to 'stock_quantity'
              'brand': productData['brand'],
              'unit': productData['unit'],
              'specifications': _specifications,
              'tags': _keywords, // Mapping 'keywords' to 'tags'
              'images': _imageUrls,
              'imageUrl': _imageUrls.isNotEmpty ? _imageUrls.first : null,
          };
          
          bool success = await _sellerService.updateProduct(widget.productToEdit!['id'], updateData);
          
          if (mounted) {
              if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Product updated successfully!'), backgroundColor: Color(0xFF34A853)),
                  );
                  Navigator.pop(context);
              } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update product'), backgroundColor: Colors.red),
                  );
              }
          }
      } else {
          // CREATE NEW REQUEST
          await _sellerService.submitProductRequest(widget.seller.id, requestData);
          
          // Delete draft after successful submission if it exists
          if (_currentDraftId != null) {
            await _sellerService.deleteProductDraft(_currentDraftId!);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product request submitted successfully!'),
                backgroundColor: Color(0xFF34A853),
              ),
            );
            Navigator.pop(context);
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
