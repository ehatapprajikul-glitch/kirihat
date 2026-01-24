import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a specification field definition for a category
class SpecificationField {
  final String fieldName;
  final String fieldType; // text, numeric, dropdown, multiSelect, date, textarea
  final bool isRequired;
  final String helpText;
  final String section; // Grouping (e.g., "General", "Warranty")
  final int sectionOrder; // Controls section display order (lower = appears first)
  final List<String>? options; // For dropdown/multiSelect types
  final List<String>? unitOptions; // List of available units
  final bool isUnitLocked; // If true, seller cannot change the default unit
  final String? defaultUnit; // Pre-selected unit
  final String? defaultValue; // Default value for the field
  final bool isSellerEditable; // If false, seller cannot change the value (admin only/default value locked)
  final Map<String, dynamic>? validation; // Custom validation rules
  final int displayOrder;

  SpecificationField({
    required this.fieldName,
    required this.fieldType,
    this.section = 'General',
    this.sectionOrder = 0,
    this.isRequired = false,
    this.helpText = '',
    this.options,
    this.unitOptions,
    this.isUnitLocked = false,
    this.defaultUnit,
    this.defaultValue,
    this.isSellerEditable = true,
    this.validation,
    this.displayOrder = 0,
  });

  factory SpecificationField.fromMap(Map<String, dynamic> map) {
    return SpecificationField(
      fieldName: map['field_name'] ?? '',
      fieldType: map['field_type'] ?? 'text',
      section: map['section'] ?? 'General',
      sectionOrder: map['section_order'] ?? 0,
      isRequired: map['is_required'] ?? false,
      helpText: map['help_text'] ?? '',
      options: map['options'] != null ? List<String>.from(map['options']) : null,
      unitOptions: map['unit_options'] != null ? List<String>.from(map['unit_options']) : null,
      isUnitLocked: map['is_unit_locked'] ?? false,
      defaultUnit: map['default_unit'],
      defaultValue: map['default_value'],
      isSellerEditable: map['is_seller_editable'] ?? true,
      validation: map['validation'],
      displayOrder: map['display_order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'field_name': fieldName,
      'field_type': fieldType,
      'section': section,
      'section_order': sectionOrder,
      'is_required': isRequired,
      'help_text': helpText,
      'options': options,
      'unit_options': unitOptions,
      'is_unit_locked': isUnitLocked,
      'default_unit': defaultUnit,
      'default_value': defaultValue,
      'is_seller_editable': isSellerEditable,
      'validation': validation,
      'display_order': displayOrder,
    };
  }
}

/// Represents a category-specific specification template
class CategorySpecification {
  final String id;
  final String categoryId; // The target category ID
  final String categoryName; // The target category name
  final List<String> categoryPath; // Full path of IDs from root to this category
  final List<String> categoryPathNames; // Full path of names for display
  final int level; // Nesting depth (0 = root, 1 = first child, etc.)
  final List<SpecificationField> fields;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  // Legacy fields for backward compatibility (deprecated)
  @Deprecated('Use categoryPath instead')
  final String? subcategoryId;
  @Deprecated('Use categoryPathNames instead')
  final String? subcategoryName;

  CategorySpecification({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    List<String>? categoryPath,
    List<String>? categoryPathNames,
    this.level = 0,
    required this.fields,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.subcategoryId, // Legacy
    this.subcategoryName, // Legacy
  })  : categoryPath = categoryPath ?? [],
        categoryPathNames = categoryPathNames ?? [];

  factory CategorySpecification.fromMap(Map<String, dynamic> map, String id) {
    return CategorySpecification(
      id: id,
      categoryId: map['category_id'] ?? '',
      categoryName: map['category_name'] ?? '',
      categoryPath: map['category_path'] != null 
          ? List<String>.from(map['category_path']) 
          : [],
      categoryPathNames: map['category_path_names'] != null
          ? List<String>.from(map['category_path_names'])
          : [],
      level: map['level'] ?? 0,
      fields: (map['fields'] as List<dynamic>?)
              ?.map((f) => SpecificationField.fromMap(f))
              .toList() ??
          [],
      version: map['version'] ?? 1,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['created_by'],
      // Legacy fields for backward compatibility
      subcategoryId: map['subcategory_id'],
      subcategoryName: map['subcategory_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category_id': categoryId,
      'category_name': categoryName,
      'category_path': categoryPath,
      'category_path_names': categoryPathNames,
      'level': level,
      'fields': fields.map((f) => f.toMap()).toList(),
      'version': version,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'created_by': createdBy,
      // Legacy fields kept for backward compatibility
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (subcategoryName != null) 'subcategory_name': subcategoryName,
    };
  }

  /// Create a new version of this template with updated fields
  CategorySpecification copyWithNewVersion(List<SpecificationField> newFields) {
    return CategorySpecification(
      id: '', // Will be assigned new ID
      categoryId: categoryId,
      categoryName: categoryName,
      categoryPath: categoryPath,
      categoryPathNames: categoryPathNames,
      level: level,
      fields: newFields,
      version: version + 1,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );
  }
}
