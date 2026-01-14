import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/services/product_display_settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductDisplaySettings extends StatefulWidget {
  const ProductDisplaySettings({super.key});

  @override
  State<ProductDisplaySettings> createState() => _ProductDisplaySettingsState();
}

class _ProductDisplaySettingsState extends State<ProductDisplaySettings> {
  final ProductDisplaySettingsService _settingsService = ProductDisplaySettingsService();
  
  bool _isLoading = true;
  bool _isSaving = false;

  // Image Settings
  bool _enableImageZoom = true;
  bool _enableFullscreenMode = true;
  bool _enablePinchToZoom = true;
  bool _showImageCounter = true;
  bool _showImageDots = true;
  int _maxImagesPerProduct = 8;
  String _imageAspectRatio = 'square';

  // Description Settings
  bool _showDescriptionSection = true;
  bool _makeDescriptionCollapsible = true;
  String _descriptionDefaultState = 'collapsed';
  int _collapsedPreviewLines = 3;
  bool _showKeyFeaturesBox = false;
  int _numberOfKeyFeatures = 4;
  String _descriptionTextSize = 'medium';
  bool _allowTextFormatting = true;

  // Recommendations Settings
  bool _showRecommendationsSection = true;
  final TextEditingController _recommendationsTitleController = TextEditingController();
  int _numberOfRecommendations = 8;
  String _recommendationLogic = 'same_category';
  bool _filterSameCategory = true;
  bool _filterSimilarPrice = true;
  int _priceRangePercentage = 50;
  bool _excludeCurrentProduct = true;
  bool _showDiscountBadge = true;
  bool _showAddButton = true;

  // Product Details & Disclaimers Settings
  bool _showProductDetailsTable = true;
  bool _showSellerInfo = true;
  final TextEditingController _defaultDisclaimerController = TextEditingController();
  // Map<CategoryName or 'Category:Subcategory', DisclaimerText>
  Map<String, String> _categoryDisclaimers = {};
  
  // Helper to manage category disclaimers in UI
  final TextEditingController _newCategoryDisclaimerController = TextEditingController();
  String? _selectedDisclaimerCategory;
  String? _selectedDisclaimerSubcategory;
  String? _selectedDisclaimerCategoryId; // To filter subcategories

  // Display Order Settings
  List<String> _sectionOrder = ['images', 'overview', 'description', 'details', 'related'];
  final Map<String, String> _sectionLabels = {
    'images': 'Image Gallery',
    'overview': 'Product Info (Name, Price)',
    'description': 'Description',
    'details': 'Product Details Table',
    'related': 'Related Products',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _recommendationsTitleController.dispose();
    _defaultDisclaimerController.dispose();
    _newCategoryDisclaimerController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      await _settingsService.initialize();
      final settings = _settingsService.getAllSettings();
      
      setState(() {
        // Image Settings
        final imageSettings = settings['image_settings'] as Map<String, dynamic>? ?? {};
        _enableImageZoom = imageSettings['enable_image_zoom'] ?? true;
        _enableFullscreenMode = imageSettings['enable_fullscreen_mode'] ?? true;
        _enablePinchToZoom = imageSettings['enable_pinch_to_zoom'] ?? true;
        _showImageCounter = imageSettings['show_image_counter'] ?? true;
        _showImageDots = imageSettings['show_image_dots'] ?? true;
        _maxImagesPerProduct = imageSettings['max_images_per_product'] ?? 8;
        _imageAspectRatio = imageSettings['image_aspect_ratio'] ?? 'square';

        // Description Settings
        final descSettings = settings['description_settings'] as Map<String, dynamic>? ?? {};
        _showDescriptionSection = descSettings['show_description_section'] ?? true;
        _makeDescriptionCollapsible = descSettings['make_description_collapsible'] ?? true;
        _descriptionDefaultState = descSettings['description_default_state'] ?? 'collapsed';
        _collapsedPreviewLines = descSettings['collapsed_preview_lines'] ?? 3;
        _showKeyFeaturesBox = descSettings['show_key_features_box'] ?? false;
        _numberOfKeyFeatures = descSettings['number_of_key_features'] ?? 4;
        _descriptionTextSize = descSettings['description_text_size'] ?? 'medium';
        _allowTextFormatting = descSettings['allow_text_formatting'] ?? true;

        // Recommendations Settings
        final recSettings = settings['recommendations_settings'] as Map<String, dynamic>? ?? {};
        _showRecommendationsSection = recSettings['show_recommendations_section'] ?? true;
        _recommendationsTitleController.text = recSettings['recommendations_section_title'] ?? 'You may also like';
        _numberOfRecommendations = recSettings['number_of_recommendations'] ?? 8;
        _recommendationLogic = recSettings['recommendation_logic'] ?? 'same_category';
        _filterSameCategory = recSettings['filter_same_category'] ?? true;
        _filterSimilarPrice = recSettings['filter_similar_price'] ?? true;
        _priceRangePercentage = recSettings['price_range_percentage'] ?? 50;
        _excludeCurrentProduct = recSettings['exclude_current_product'] ?? true;
        _showDiscountBadge = recSettings['show_discount_badge'] ?? true;
        _showAddButton = recSettings['show_add_button'] ?? true;

         // Product Details Settings
        final detailsSettings = settings['product_details_settings'] as Map<String, dynamic>? ?? {};
        _showProductDetailsTable = detailsSettings['show_product_details_table'] ?? true;
        _showSellerInfo = detailsSettings['show_seller_info'] ?? true;
        _defaultDisclaimerController.text = detailsSettings['default_disclaimer'] ?? 'Images are for illustration purposes only. Actual product may vary.';
        if (detailsSettings['category_disclaimers'] != null) {
          _categoryDisclaimers = Map<String, String>.from(detailsSettings['category_disclaimers']);
        }

        // Section Order (Safe cast)
        if (settings['section_order'] is List) {
          _sectionOrder = List<String>.from(settings['section_order']);
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final settings = {
        'image_settings': {
          'enable_image_zoom': _enableImageZoom,
          'enable_fullscreen_mode': _enableFullscreenMode,
          'enable_pinch_to_zoom': _enablePinchToZoom,
          'show_image_counter': _showImageCounter,
          'show_image_dots': _showImageDots,
          'max_images_per_product': _maxImagesPerProduct,
          'image_aspect_ratio': _imageAspectRatio,
        },
        'description_settings': {
          'show_description_section': _showDescriptionSection,
          'make_description_collapsible': _makeDescriptionCollapsible,
          'description_default_state': _descriptionDefaultState,
          'collapsed_preview_lines': _collapsedPreviewLines,
          'show_key_features_box': _showKeyFeaturesBox,
          'number_of_key_features': _numberOfKeyFeatures,
          'description_text_size': _descriptionTextSize,
          'allow_text_formatting': _allowTextFormatting,
        },
        'recommendations_settings': {
          'show_recommendations_section': _showRecommendationsSection,
          'recommendations_section_title': _recommendationsTitleController.text,
          'number_of_recommendations': _numberOfRecommendations,
          'recommendation_logic': _recommendationLogic,
          'filter_same_category': _filterSameCategory,
          'filter_similar_price': _filterSimilarPrice,
          'price_range_percentage': _priceRangePercentage,
          'exclude_current_product': _excludeCurrentProduct,
          'show_discount_badge': _showDiscountBadge,
          'show_add_button': _showAddButton,
        },
        'product_details_settings': {
          'show_product_details_table': _showProductDetailsTable,
          'show_seller_info': _showSellerInfo,
          'default_disclaimer': _defaultDisclaimerController.text,
          'category_disclaimers': _categoryDisclaimers,
          // Hardcoded excluded fields for now, could be dynamic later
          'excluded_fields': ["keywords", "seo_title", "seo_description", "cost_price", "id", "created_at", "updated_at", "isActive", "images", "imageUrl", "seller_id", "category_id"],
        },
        'section_order': _sectionOrder,
      };

      await _settingsService.saveSettings(settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _savePreview() async {
    setState(() => _isSaving = true);
    try {
      // Construct settings map (same as save logic)
      final settings = {
        'image_settings': {
          'enable_image_zoom': _enableImageZoom,
          'enable_fullscreen_mode': _enableFullscreenMode,
          'enable_pinch_to_zoom': _enablePinchToZoom,
          'show_image_counter': _showImageCounter,
          'show_image_dots': _showImageDots,
          'max_images_per_product': _maxImagesPerProduct,
          'image_aspect_ratio': _imageAspectRatio,
        },
        'description_settings': {
          'show_description_section': _showDescriptionSection,
          'make_description_collapsible': _makeDescriptionCollapsible,
          'description_default_state': _descriptionDefaultState,
          'collapsed_preview_lines': _collapsedPreviewLines,
          'show_key_features_box': _showKeyFeaturesBox,
          'number_of_key_features': _numberOfKeyFeatures,
          'description_text_size': _descriptionTextSize,
          'allow_text_formatting': _allowTextFormatting,
        },
        'recommendations_settings': {
          'show_recommendations_section': _showRecommendationsSection,
          'recommendations_section_title': _recommendationsTitleController.text,
          'number_of_recommendations': _numberOfRecommendations,
          'recommendation_logic': _recommendationLogic,
          'filter_same_category': _filterSameCategory,
          'filter_similar_price': _filterSimilarPrice,
          'price_range_percentage': _priceRangePercentage,
          'exclude_current_product': _excludeCurrentProduct,
          'show_discount_badge': _showDiscountBadge,
          'show_add_button': _showAddButton,
        },
        'product_details_settings': {
          'show_product_details_table': _showProductDetailsTable,
          'show_seller_info': _showSellerInfo,
          'default_disclaimer': _defaultDisclaimerController.text,
          'category_disclaimers': _categoryDisclaimers,
          'excluded_fields': ["keywords", "seo_title", "seo_description", "cost_price", "id", "created_at", "updated_at", "isActive", "images", "imageUrl", "seller_id", "category_id"],
        },
        'section_order': _sectionOrder,
      };

      await _settingsService.savePreviewSettings(settings);

      // Launch Customer App with preview mode
      // Replace with your actual customer app URL
      const customerAppUrl = 'http://localhost:8081/#/?mode=preview'; 
      if (await canLaunchUrl(Uri.parse(customerAppUrl))) {
        await launchUrl(Uri.parse(customerAppUrl));
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch preview URL. Ensure Customer App is running on port 8081.'), backgroundColor: Colors.orange),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating preview: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Product Display Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure how products are displayed in the customer app',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),

          const SizedBox(height: 32),

          // Section A: Image Settings
          _buildImageSettings(),

          const SizedBox(height: 24),

          // Section B: Description Settings
          _buildDescriptionSettings(),

          const SizedBox(height: 24),

          // Section C: Recommendations Settings
          _buildRecommendationsSettings(),

          const SizedBox(height: 24),

          // Section D: Product Details & Disclaimers
          // Section D: Product Details & Disclaimers
          _buildProductDetailsSettings(),

          const SizedBox(height: 24),

          // Section E: Display Order
          _buildDisplayOrderSettings(),

          const SizedBox(height: 32),


          // Save Button
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _savePreview,
                  icon: const Icon(Icons.visibility),
                  label: const Text('PREVIEW CHANGES'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF0D9759)),
                    foregroundColor: const Color(0xFF0D9759),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: const Icon(Icons.save),
                  label: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('SAVE SETTINGS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9759),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageSettings() {
    return _buildSection(
      title: 'Image Display Settings',
      children: [
        _buildSwitchTile(
          title: 'Enable Image Zoom',
          subtitle: 'Allow customers to tap and zoom product images',
          value: _enableImageZoom,
          onChanged: (val) => setState(() => _enableImageZoom = val),
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Enable Fullscreen Mode',
          subtitle: 'Allow customers to view images in fullscreen',
          value: _enableFullscreenMode,
          onChanged: (val) => setState(() => _enableFullscreenMode = val),
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Enable Pinch to Zoom',
          subtitle: 'Allow pinch gesture to zoom in/out',
          value: _enablePinchToZoom,
          onChanged: (val) => setState(() => _enablePinchToZoom = val),
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Show Image Counter',
          subtitle: 'Display "1 of 4" text on images',
          value: _showImageCounter,
          onChanged: (val) => setState(() => _showImageCounter = val),
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Show Image Dots',
          subtitle: 'Display dot indicators for multiple images',
          value: _showImageDots,
          onChanged: (val) => setState(() => _showImageDots = val),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Maximum Images Per Product',
          value: _maxImagesPerProduct,
          items: [4, 6, 8, 10, 12],
          onChanged: (val) => setState(() => _maxImagesPerProduct = val!),
        ),
        const SizedBox(height: 16),
        _buildDropdown<String>(
          label: 'Image Aspect Ratio',
          value: _imageAspectRatio,
          items: ['square', 'portrait', 'landscape'],
          itemLabels: {
            'square': 'Square (1:1)',
            'portrait': 'Portrait (3:4)',
            'landscape': 'Landscape (16:9)',
          },
          onChanged: (val) => setState(() => _imageAspectRatio = val!),
        ),
      ],
    );
  }

  Widget _buildDescriptionSettings() {
    return _buildSection(
      title: 'Product Description Settings',
      children: [
        _buildSwitchTile(
          title: 'Show Product Description Section',
          subtitle: 'Display description on product page',
          value: _showDescriptionSection,
          onChanged: (val) => setState(() => _showDescriptionSection = val),
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Make Description Collapsible',
          subtitle: 'Allow customers to expand/collapse description',
          value: _makeDescriptionCollapsible,
          onChanged: (val) => setState(() => _makeDescriptionCollapsible = val),
        ),
        const SizedBox(height: 16),
        _buildDropdown<String>(
          label: 'Default State',
          value: _descriptionDefaultState,
          items: ['collapsed', 'expanded'],
          itemLabels: {
            'collapsed': 'Collapsed',
            'expanded': 'Expanded',
          },
          onChanged: (val) => setState(() => _descriptionDefaultState = val!),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Collapsed Preview Lines',
          value: _collapsedPreviewLines,
          items: [2, 3, 4, 5],
          itemLabels: {
            2: '2 lines',
            3: '3 lines',
            4: '4 lines',
            5: '5 lines',
          },
          onChanged: (val) => setState(() => _collapsedPreviewLines = val!),
        ),
        const SizedBox(height: 16),
        const Divider(),
        _buildSwitchTile(
          title: 'Show "Key Features" Box',
          subtitle: 'Display highlighted key features box above description',
          value: _showKeyFeaturesBox,
          onChanged: (val) => setState(() => _showKeyFeaturesBox = val),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Number of Key Features',
          value: _numberOfKeyFeatures,
          items: [3, 4, 5],
          itemLabels: {
            3: '3 features',
            4: '4 features',
            5: '5 features',
          },
          onChanged: (val) => setState(() => _numberOfKeyFeatures = val!),
        ),
        const SizedBox(height: 16),
        _buildDropdown<String>(
          label: 'Description Text Size',
          value: _descriptionTextSize,
          items: ['small', 'medium', 'large'],
          itemLabels: {
            'small': 'Small',
            'medium': 'Medium',
            'large': 'Large',
          },
          onChanged: (val) => setState(() => _descriptionTextSize = val!),
        ),
        const SizedBox(height: 16),
        const Divider(),
        _buildSwitchTile(
          title: 'Allow Text Formatting',
          subtitle: 'Enable bold, bullets, etc. in descriptions',
          value: _allowTextFormatting,
          onChanged: (val) => setState(() => _allowTextFormatting = val),
        ),
      ],
    );
  }

  Widget _buildRecommendationsSettings() {
    return _buildSection(
      title: '"You May Also Like" Settings',
      children: [
        _buildSwitchTile(
          title: 'Show Recommendations Section',
          subtitle: 'Display "You may also like" products',
          value: _showRecommendationsSection,
          onChanged: (val) => setState(() => _showRecommendationsSection = val),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _recommendationsTitleController,
          decoration: const InputDecoration(
            labelText: 'Section Title',
            border: OutlineInputBorder(),
            hintText: 'You may also like',
          ),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Number of Products to Show',
          value: _numberOfRecommendations,
          items: [4, 6, 8, 10, 12],
          onChanged: (val) => setState(() => _numberOfRecommendations = val!),
        ),
        const SizedBox(height: 16),
        _buildDropdown<String>(
          label: 'Recommendation Logic',
          value: _recommendationLogic,
          items: ['same_category', 'same_brand', 'similar_price', 'random'],
          itemLabels: {
            'same_category': 'Same Category',
            'same_brand': 'Same Brand',
            'similar_price': 'Similar Price Range (±50%)',
            'random': 'Random Mix',
          },
          onChanged: (val) => setState(() => _recommendationLogic = val!),
        ),
        const SizedBox(height: 16),
        const Divider(),
        _buildSwitchTile(
          title: 'Show Products from Same Category',
          subtitle: 'Filter recommendations to same category',
          value: _filterSameCategory,
          onChanged: (val) => setState(() => _filterSameCategory = val),
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Show Products in Similar Price Range',
          subtitle: '±${_priceRangePercentage}% of current product price',
          value: _filterSimilarPrice,
          onChanged: (val) => setState(() => _filterSimilarPrice = val),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Price Range Percentage',
          value: _priceRangePercentage,
          items: [30, 50, 70, 100],
          itemLabels: {
            30: '±30%',
            50: '±50%',
            70: '±70%',
            100: '±100% (any price)',
          },
          onChanged: (val) => setState(() => _priceRangePercentage = val!),
        ),
        const SizedBox(height: 16),
        const Divider(),
        _buildSwitchTile(
          title: 'Exclude Current Product',
          subtitle: "Don't show the same product in recommendations",
          value: _excludeCurrentProduct,
          onChanged: (val) => setState(() => _excludeCurrentProduct = val),
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Show Discount Badge on Cards',
          subtitle: 'Display "54% OFF" badge on product cards',
          value: _showDiscountBadge,
          onChanged: (val) => setState(() => _showDiscountBadge = val),
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Show "Add to Cart" Button on Cards',
          subtitle: 'Allow quick add from recommendation cards',
          value: _showAddButton,
          onChanged: (val) => setState(() => _showAddButton = val),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      activeColor: const Color(0xFF0D9759),
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    Map<T, String>? itemLabels,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(itemLabels?[item] ?? item.toString()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
  Widget _buildProductDetailsSettings() {
    return _buildSection(
      title: 'Product Details & Disclaimers',
      children: [
        _buildSwitchTile(
          title: 'Show Product Details Table',
          subtitle: 'Display formatted table of product specifications',
          value: _showProductDetailsTable,
          onChanged: (val) => setState(() => _showProductDetailsTable = val),
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Show Seller Information',
          subtitle: 'Display "Sold by [Seller Name]"',
          value: _showSellerInfo,
          onChanged: (val) => setState(() => _showSellerInfo = val),
        ),
        const SizedBox(height: 16),
        const Text('Default Disclaimer', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _defaultDisclaimerController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter default disclaimer text...',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             const Text('Category Disclaimers', style: TextStyle(fontWeight: FontWeight.bold)),
             TextButton.icon(
               onPressed: _showCategoryDisclaimerDialog,
               icon: const Icon(Icons.add),
               label: const Text('Add Rule'),
             ),
          ],
        ),
        if (_categoryDisclaimers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _categoryDisclaimers.entries.map((entry) {
                // Parse key to see if it has subcategory
                final parts = entry.key.split(':');
                final category = parts[0];
                final subcategory = parts.length > 1 ? parts[1] : null;
                
                return ListTile(
                  title: Text(subcategory != null ? '$category > $subcategory' : category),
                  subtitle: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _categoryDisclaimers.remove(entry.key);
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  void _showCategoryDisclaimerDialog() {
    _newCategoryDisclaimerController.clear();
    _selectedDisclaimerCategory = null;
    _selectedDisclaimerSubcategory = null;
    _selectedDisclaimerCategoryId = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Add Category Disclaimer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('categories').orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      final categories = snapshot.data!.docs;
                      
                      return DropdownButtonFormField<String>(
                        value: _selectedDisclaimerCategory,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories.map((doc) => DropdownMenuItem(
                          value: doc['name'] as String,
                          child: Text(doc['name'] as String),
                          onTap: () {
                             setStateDialog(() {
                               _selectedDisclaimerCategoryId = doc.id;
                               _selectedDisclaimerSubcategory = null;
                             });
                          },
                        )).toList(),
                        onChanged: (val) {
                          setStateDialog(() => _selectedDisclaimerCategory = val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Subcategory Dropdown (Optional)
                  if (_selectedDisclaimerCategoryId != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('subcategories')
                          .where('category_id', isEqualTo: _selectedDisclaimerCategoryId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final subcategories = snapshot.data!.docs;
                         if (subcategories.isEmpty) return const SizedBox();

                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedDisclaimerSubcategory,
                              decoration: const InputDecoration(
                                labelText: 'Subcategory (Optional)',
                                helperText: 'Leave empty to apply to entire category',
                              ),
                              items: subcategories.map((doc) => DropdownMenuItem(
                                value: doc['name'] as String,
                                child: Text(doc['name'] as String),
                              )).toList(),
                              onChanged: (val) {
                                setStateDialog(() => _selectedDisclaimerSubcategory = val);
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),

                  TextField(
                    controller: _newCategoryDisclaimerController,
                    decoration: const InputDecoration(
                      labelText: 'Disclaimer Text',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
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
                onPressed: () {
                  if (_selectedDisclaimerCategory != null && _newCategoryDisclaimerController.text.isNotEmpty) {
                    
                    String key = _selectedDisclaimerCategory!;
                    if (_selectedDisclaimerSubcategory != null) {
                      key = "$key:$_selectedDisclaimerSubcategory";
                    }

                    this.setState(() {
                      _categoryDisclaimers[key] = _newCategoryDisclaimerController.text;
                    });
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9759), foregroundColor: Colors.white),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
  Widget _buildDisplayOrderSettings() {
    return _buildSection(
      title: 'Section Display Order',
      children: [
        const Text(
          'Drag and drop to reorder sections on the product page.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _sectionOrder.map((key) {
              return ListTile(
                key: ValueKey(key),
                leading: const Icon(Icons.drag_handle, color: Colors.grey),
                title: Text(_sectionLabels[key] ?? key),
                tileColor: Colors.white,
              );
            }).toList(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final String item = _sectionOrder.removeAt(oldIndex);
                _sectionOrder.insert(newIndex, item);
              });
            },
          ),
        ),
      ],
    );
  }
}
