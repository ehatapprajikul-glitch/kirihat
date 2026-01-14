import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to manage product display settings from Firestore
/// Settings control image zoom, descriptions, and recommendations on product detail pages
class ProductDisplaySettingsService {
  static final ProductDisplaySettingsService _instance = ProductDisplaySettingsService._internal();
  factory ProductDisplaySettingsService() => _instance;
  ProductDisplaySettingsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for settings to reduce Firestore reads
  Map<String, dynamic>? _cachedSettings;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 30);
  bool _isPreview = false;

  /// Initialize settings by loading from Firestore
  /// [isPreview] - if provided, updates the preview mode. If null, keeps current mode.
  Future<void> initialize({bool? isPreview}) async {
    if (isPreview != null) _isPreview = isPreview;
    try {
      await _loadSettings();
    } catch (e) {
      debugPrint('Error initializing ProductDisplaySettings: $e');
      _cachedSettings = getDefaultSettings();
    }
  }

  /// Load settings from Firestore
  Future<void> _loadSettings() async {
    final docId = _isPreview ? 'preview_config' : 'product_display_config';
    final doc = await _firestore
        .collection('platform_settings')
        .doc(docId)
        .get();

    if (doc.exists && doc.data() != null) {
      _cachedSettings = doc.data()!;
      _lastCacheUpdate = DateTime.now();
    } else {
      // Document doesn't exist, use defaults
      _cachedSettings = getDefaultSettings();
      _lastCacheUpdate = DateTime.now();
    }
  }

  /// Get a specific setting value with a default fallback
  dynamic getSetting(String key, dynamic defaultValue) {
    // Check if cache is expired
    if (_cachedSettings == null || 
        _lastCacheUpdate == null ||
        DateTime.now().difference(_lastCacheUpdate!) > _cacheExpiry) {
      // Return default while we refresh in background
      _loadSettings().catchError((e) => debugPrint('Background refresh failed: $e'));
      return defaultValue;
    }

    // Navigate nested keys (e.g., "image_settings.enable_image_zoom")
    if (key.contains('.')) {
      final parts = key.split('.');
      dynamic value = _cachedSettings;
      for (final part in parts) {
        if (value is Map && value.containsKey(part)) {
          value = value[part];
        } else {
          return defaultValue;
        }
      }
      return value ?? defaultValue;
    }

    return _cachedSettings![key] ?? defaultValue;
  }

  /// Watch settings for real-time updates
  Stream<Map<String, dynamic>> watchSettings() {
    final docId = _isPreview ? 'preview_config' : 'product_display_config';
    return _firestore
        .collection('platform_settings')
        .doc(docId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            _cachedSettings = doc.data()!;
            _lastCacheUpdate = DateTime.now();
            return doc.data()!;
          }
          return getDefaultSettings();
        });
  }

  /// Save settings to Firestore (Admin only)
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      await _firestore
          .collection('platform_settings')
          .doc('product_display_config')
          .set({
            ...settings,
            'updated_at': FieldValue.serverTimestamp(),
          });

      // Update cache
      _cachedSettings = settings;
      _lastCacheUpdate = DateTime.now();
    } catch (e) {
      debugPrint('Error saving product display settings: $e');
      rethrow;
    }
  }

  /// Save PREVIEW settings to Firestore (Temporary)
  Future<void> savePreviewSettings(Map<String, dynamic> settings) async {
        try {
      await _firestore
          .collection('platform_settings')
          .doc('preview_config')
          .set({
            ...settings,
            'updated_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error saving preview settings: $e');
      rethrow;
    }
  }

  /// Force refresh settings from Firestore
  Future<void> refresh() async {
    await _loadSettings();
  }

  /// Get all current settings
  Map<String, dynamic> getAllSettings() {
    return _cachedSettings ?? getDefaultSettings();
  }

  /// Get default settings structure
  static const List<String> _defaultExcludedFields = [
    "keywords", 
    "seo_title", 
    "seo_description", 
    "cost_price", 
    "id", 
    "created_at", 
    "updated_at", 
    "isActive", 
    "images", 
    "imageUrl", 
    "seller_id", 
    "category_id",
    "status",
    "approved_at",
    "approved_by",
    "rejection_reason",
    "rejected_at",
    "rejected_by",
    "seller_ids",
    "user_id",
    "vendor_id",
    "isAvailable",
    "isAvailableInCurrentVendor",
    "stock_quantity",
    "specifications",
    "tags",
    "description",
    "name",
    "mrp",
    "price"
  ];

  Map<String, dynamic> getDefaultSettings() {
    return {
      'image_settings': {
        'enable_image_zoom': true,
        'enable_fullscreen_mode': true,
        'enable_pinch_to_zoom': true,
        'show_image_counter': true,
        'show_image_dots': true,
        'max_images_per_product': 8,
        'image_aspect_ratio': 'square', // square, portrait, landscape
      },
      'description_settings': {
        'show_description_section': true,
        'make_description_collapsible': true,
        'description_default_state': 'collapsed', // collapsed, expanded
        'collapsed_preview_lines': 3,
        'show_key_features_box': false, // Disabled by default as products may not have structured features
        'number_of_key_features': 4,
        'description_text_size': 'medium', // small, medium, large
        'allow_text_formatting': true,
      },
      'recommendations_settings': {
        'show_recommendations_section': true,
        'recommendations_section_title': 'You may also like',
        'number_of_recommendations': 8,
        'recommendation_logic': 'same_category', // same_category, same_brand, similar_price, random
        'filter_same_category': true,
        'filter_similar_price': true,
        'price_range_percentage': 50, // ±50%
        'exclude_current_product': true,
        'show_discount_badge': true,
        'show_add_button': true,
      },
      'product_details_settings': {
        'show_product_details_table': true,
        'show_seller_info': true,
        'default_disclaimer': 'Images are for illustration purposes only. Actual product may vary.',
        'category_disclaimers': {
          'Electronics': 'Warranty valid only with original invoice.',
        },
        'excluded_fields': _defaultExcludedFields,
        'excluded_fields': _defaultExcludedFields,
      },
      'section_order': [
        'images', 
        'overview', 
        'description', 
        'details', 
        'related'
      ],
    };
  }

  // Convenience getters for common settings
  // Image Settings
  bool get enableImageZoom => getSetting('image_settings.enable_image_zoom', true);
  bool get enableFullscreenMode => getSetting('image_settings.enable_fullscreen_mode', true);
  bool get enablePinchToZoom => getSetting('image_settings.enable_pinch_to_zoom', true);
  bool get showImageCounter => getSetting('image_settings.show_image_counter', true);
  bool get showImageDots => getSetting('image_settings.show_image_dots', true);
  int get maxImagesPerProduct => getSetting('image_settings.max_images_per_product', 8);
  String get imageAspectRatio => getSetting('image_settings.image_aspect_ratio', 'square');

  // Description Settings
  bool get showDescriptionSection => getSetting('description_settings.show_description_section', true);
  bool get makeDescriptionCollapsible => getSetting('description_settings.make_description_collapsible', true);
  String get descriptionDefaultState => getSetting('description_settings.description_default_state', 'collapsed');
  int get collapsedPreviewLines => getSetting('description_settings.collapsed_preview_lines', 3);
  bool get showKeyFeaturesBox => getSetting('description_settings.show_key_features_box', false);
  int get numberOfKeyFeatures => getSetting('description_settings.number_of_key_features', 4);
  String get descriptionTextSize => getSetting('description_settings.description_text_size', 'medium');
  bool get allowTextFormatting => getSetting('description_settings.allow_text_formatting', true);

  // Recommendations Settings
  bool get showRecommendationsSection => getSetting('recommendations_settings.show_recommendations_section', true);
  String get recommendationsSectionTitle => getSetting('recommendations_settings.recommendations_section_title', 'You may also like');
  int get numberOfRecommendations => getSetting('recommendations_settings.number_of_recommendations', 8);
  String get recommendationLogic => getSetting('recommendations_settings.recommendation_logic', 'same_category');
  bool get filterSameCategory => getSetting('recommendations_settings.filter_same_category', true);
  bool get filterSimilarPrice => getSetting('recommendations_settings.filter_similar_price', true);
  int get priceRangePercentage => getSetting('recommendations_settings.price_range_percentage', 50);
  bool get excludeCurrentProduct => getSetting('recommendations_settings.exclude_current_product', true);
  bool get showDiscountBadge => getSetting('recommendations_settings.show_discount_badge', true);
  bool get showAddButton => getSetting('recommendations_settings.show_add_button', true);

  // Product Details Settings
  bool get showProductDetailsTable => getSetting('product_details_settings.show_product_details_table', true);
  bool get showSellerInfo => getSetting('product_details_settings.show_seller_info', true);
  String get defaultDisclaimer => getSetting('product_details_settings.default_disclaimer', 'Images are for illustration purposes only. Actual product may vary.');
  Map<String, dynamic> get categoryDisclaimers {
    final val = getSetting('product_details_settings.category_disclaimers', {});
    if (val is Map) {
      return Map<String, dynamic>.from(val);
    }
    return {};
  }
  List<String> get excludedFields {
    final val = getSetting('product_details_settings.excluded_fields', _defaultExcludedFields);
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return _defaultExcludedFields;
  }
  
  // Section Order
  List<String> get sectionOrder {
    final val = getSetting('section_order', ['images', 'overview', 'description', 'details', 'related']);
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return ['images', 'overview', 'description', 'details', 'related'];
  }

  /// Helper to get font size based on text size setting
  double getDescriptionFontSize() {
    switch (descriptionTextSize) {
      case 'small':
        return 12.0;
      case 'large':
        return 16.0;
      case 'medium':
      default:
        return 14.0;
    }
  }

  /// Helper to calculate price range for filtering
  Map<String, double> getPriceRange(double basePrice) {
    final percentage = priceRangePercentage / 100;
    return {
      'min': basePrice * (1 - percentage),
      'max': basePrice * (1 + percentage),
    };
  }

  /// Helper to get the appropriate disclaimer text
  String getDisclaimerForCategory(String categoryName, {String? subcategoryName}) {
    final disclaimers = categoryDisclaimers;
    
    // 1. Check for specific Subcategory match (Format: "Category:Subcategory")
    if (subcategoryName != null && subcategoryName.isNotEmpty) {
      final specificKey = "$categoryName:$subcategoryName";
      if (disclaimers.containsKey(specificKey)) {
        return disclaimers[specificKey] as String;
      }
    }

    // 2. Check for Category match
    if (disclaimers.containsKey(categoryName)) {
      return disclaimers[categoryName] as String;
    }

    // 3. Return default
    return defaultDisclaimer;
  }
}
