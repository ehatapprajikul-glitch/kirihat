import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/category_specification_model.dart';

class CategorySpecificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, CategorySpecification> _cache = {};

  /// Get specification template for a category
  /// Works with hierarchical categories - just pass the target category ID
  Future<CategorySpecification?> getSpecificationTemplate(
    String categoryId,
    String categoryName,
  ) async {
    // Check cache first
    if (_cache.containsKey(categoryId)) {
      return _cache[categoryId];
    }

    try {
      // Query by category_id
      var query = await _firestore
          .collection('category_specifications')
          .where('category_id', isEqualTo: categoryId)
          .orderBy('version', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        var spec = CategorySpecification.fromMap(
          query.docs.first.data(),
          query.docs.first.id,
        );
        _cache[categoryId] = spec;
        return spec;
      }

      // Return null if no template found
      return null;
    } catch (e) {
      print('Error fetching specification template: $e');
      return null;
    }
  }

  /// Save or update a specification template (Admin only)
  Future<String?> saveSpecificationTemplate(
    CategorySpecification template,
    String adminId,
  ) async {
    try {
      var data = template.toMap();
      data['created_by'] = adminId;
      data['updated_at'] = FieldValue.serverTimestamp();

      if (template.id.isEmpty) {
        // Create new
        data['created_at'] = FieldValue.serverTimestamp();
        var docRef = await _firestore
            .collection('category_specifications')
            .add(data);
        
        // Clear cache
        _clearCache();
        return docRef.id;
      } else {
        // Update existing
        await _firestore
            .collection('category_specifications')
            .doc(template.id)
            .update(data);
        
        // Clear cache
        _clearCache();
        return template.id;
      }
    } catch (e) {
      print('Error saving specification template: $e');
      return null;
    }
  }

  /// Validate product specifications against template
  Map<String, String> validateSpecificationData(
    Map<String, dynamic> specifications,
    CategorySpecification template,
  ) {
    Map<String, String> errors = {};

    for (var field in template.fields) {
      var value = specifications[field.fieldName];

      // Check required fields
      if (field.isRequired && (value == null || value.toString().isEmpty)) {
        errors[field.fieldName] = '${field.fieldName} is required';
        continue;
      }

      // Skip validation if field is optional and empty
      if (value == null || value.toString().isEmpty) continue;

      // Type-specific validation
      switch (field.fieldType) {
        case 'numeric':
          if (double.tryParse(value.toString()) == null) {
            errors[field.fieldName] = '${field.fieldName} must be a valid number';
          }
          break;

        case 'dropdown':
        case 'multiSelect':
          if (field.options != null) {
            if (field.fieldType == 'dropdown') {
              if (!field.options!.contains(value.toString())) {
                errors[field.fieldName] = '${field.fieldName} must be one of: ${field.options!.join(", ")}';
              }
            } else {
              // multiSelect
              if (value is List) {
                for (var item in value) {
                  if (!field.options!.contains(item.toString())) {
                    errors[field.fieldName] = 'Invalid option in ${field.fieldName}';
                    break;
                  }
                }
              }
            }
          }
          break;

        case 'date':
          if (value is! Timestamp && DateTime.tryParse(value.toString()) == null) {
            errors[field.fieldName] = '${field.fieldName} must be a valid date';
          }
          break;
      }

      // Custom validation rules
      if (field.validation != null) {
        var validation = field.validation!;
        
        if (validation['min'] != null && value is num) {
          if (value < validation['min']) {
            errors[field.fieldName] = '${field.fieldName} must be at least ${validation['min']}';
          }
        }
        
        if (validation['max'] != null && value is num) {
          if (value > validation['max']) {
            errors[field.fieldName] = '${field.fieldName} must not exceed ${validation['max']}';
          }
        }

        if (validation['pattern'] != null && value is String) {
          var regex = RegExp(validation['pattern']);
          if (!regex.hasMatch(value)) {
            errors[field.fieldName] = '${field.fieldName} format is invalid';
          }
        }
      }
    }

    return errors;
  }

  /// Get all specification templates (Admin only)
  Stream<List<CategorySpecification>> getAllTemplates() {
    return _firestore
        .collection('category_specifications')
        .orderBy('category_name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategorySpecification.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Clear cache (useful after updates)
  void _clearCache() {
    _cache.clear();
  }

  String _getCacheKey(String categoryId, String? subcategoryId) {
    return '$categoryId${subcategoryId != null ? "_$subcategoryId" : ""}';
  }
}
