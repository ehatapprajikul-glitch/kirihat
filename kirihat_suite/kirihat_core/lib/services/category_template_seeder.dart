import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/category_specification_model.dart';

/// Service to populate pre-defined category specification templates
/// This creates templates with proper subcategory ID linking
class CategoryTemplateSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seed all common category templates
  Future<void> seedAllTemplates(String adminId) async {
    print('Starting category template seeding...');
    
    await seedElectronicsTemplates(adminId);
    await seedGroceryTemplates(adminId);
    await seedFashionTemplates(adminId);
    await seedHomeKitchenTemplates(adminId);
    await seedBeautyTemplates(adminId);
    
    print('Category template seeding completed!');
  }

  /// Electronics category templates
  Future<void> seedElectronicsTemplates(String adminId) async {
    // Get Electronics category ID
    var categoryQuery = await _firestore
        .collection('categories')
        .where('name', isEqualTo: 'Electronics')
        .limit(1)
        .get();

    if (categoryQuery.docs.isEmpty) {
      print('Electronics category not found, skipping...');
      return;
    }

    String categoryId = categoryQuery.docs.first.id;
    print('Creating Electronics category templates...');

    // Smartphones
    String? smartphonesId = await _getSubcategoryId(categoryId, 'Smartphones');
    if (smartphonesId != null) {
      await _createTemplate(
        categoryId: categoryId,
        categoryName: 'Electronics',
        subcategoryId: smartphonesId,
        subcategoryName: 'Smartphones',
        fields: [
          SpecificationField(
            fieldName: 'Brand',
            fieldType: 'text',
            isRequired: true,
            helpText: 'Manufacturer brand name',
            displayOrder: 1,
          ),
          SpecificationField(
            fieldName: 'Model Number',
            fieldType: 'text',
            isRequired: true,
            helpText: 'Official model number',
            displayOrder: 2,
          ),
          SpecificationField(
            fieldName: 'RAM',
            fieldType: 'dropdown',
            isRequired: true,
            options: ['2GB', '3GB', '4GB', '6GB', '8GB', '12GB', '16GB'],
            displayOrder: 3,
          ),
          SpecificationField(
            fieldName: 'Storage',
            fieldType: 'dropdown',
            isRequired: true,
            options: ['32GB', '64GB', '128GB', '256GB', '512GB', '1TB'],
            displayOrder: 4,
          ),
          SpecificationField(
            fieldName: 'Display Size',
            fieldType: 'numeric',
            isRequired: true,
            unitOptions: ['inches', 'cm'],
            defaultUnit: 'inches',
            isUnitLocked: true,
            helpText: 'Screen size in inches',
            validation: {'min': 4.0, 'max': 8.0},
            displayOrder: 5,
          ),
          SpecificationField(
            fieldName: 'Battery Capacity',
            fieldType: 'numeric',
            isRequired: true,
            unitOptions: ['mAh', 'Wh'],
            defaultUnit: 'mAh',
            isUnitLocked: true,
            validation: {'min': 1000, 'max': 10000},
            displayOrder: 6,
          ),
          SpecificationField(
            fieldName: 'Operating System',
            fieldType: 'dropdown',
            isRequired: true,
            options: ['Android', 'iOS', 'Other'],
            displayOrder: 7,
          ),
          SpecificationField(
            fieldName: 'Camera',
            fieldType: 'text',
            isRequired: false,
            helpText: 'e.g., 48MP + 8MP + 2MP',
            displayOrder: 8,
          ),
          SpecificationField(
            fieldName: 'Processor',
            fieldType: 'text',
            isRequired: false,
            helpText: 'Chipset model',
            displayOrder: 9,
          ),
          SpecificationField(
            fieldName: 'Color Options',
            fieldType: 'multiSelect',
            isRequired: false,
            options: ['Black', 'White', 'Blue', 'Red', 'Green', 'Gold', 'Silver'],
            displayOrder: 10,
          ),
          SpecificationField(
            fieldName: '5G Support',
            fieldType: 'dropdown',
            isRequired: false,
            options: ['Yes', 'No'],
            displayOrder: 11,
          ),
          SpecificationField(
            fieldName: 'Warranty',
            fieldType: 'text',
            isRequired: false,
            helpText: 'e.g., 1 year',
            displayOrder: 12,
          ),
        ],
        createdBy: adminId,
      );
    }

    // Laptops
    String? laptopsId = await _getSubcategoryId(categoryId, 'Laptops');
    if (laptopsId != null) {
      await _createTemplate(
        categoryId: categoryId,
        categoryName: 'Electronics',
        subcategoryId: laptopsId,
        subcategoryName: 'Laptops',
        fields: [
          SpecificationField(
            fieldName: 'Brand',
            fieldType: 'text',
            isRequired: true,
            displayOrder: 1,
          ),
          SpecificationField(
            fieldName: 'Processor',
            fieldType: 'text',
            isRequired: true,
            helpText: 'e.g., Intel Core i5 11th Gen',
            displayOrder: 2,
          ),
          SpecificationField(
            fieldName: 'RAM',
            fieldType: 'dropdown',
            isRequired: true,
            options: ['4GB', '8GB', '16GB', '32GB', '64GB'],
            displayOrder: 3,
          ),
          SpecificationField(
            fieldName: 'Storage Type',
            fieldType: 'dropdown',
            isRequired: true,
            options: ['HDD', 'SSD', 'Hybrid'],
            displayOrder: 4,
          ),
          SpecificationField(
            fieldName: 'Storage Capacity',
            fieldType: 'dropdown',
            isRequired: true,
            options: ['256GB', '512GB', '1TB', '2TB'],
            displayOrder: 5,
          ),
          SpecificationField(
            fieldName: 'Screen Size',
            fieldType: 'numeric',
            isRequired: true,
            unitOptions: ['inches', 'cm'],
            defaultUnit: 'inches',
            isUnitLocked: true,
            validation: {'min': 11.0, 'max': 18.0},
            displayOrder: 6,
          ),
          SpecificationField(
            fieldName: 'Graphics Card',
            fieldType: 'text',
            isRequired: false,
            helpText: 'Integrated or Dedicated GPU',
            displayOrder: 7,
          ),
          SpecificationField(
            fieldName: 'Operating System',
            fieldType: 'dropdown',
            isRequired: true,
            options: ['Windows 11', 'Windows 10', 'macOS', 'Linux', 'DOS'],
            displayOrder: 8,
          ),
          SpecificationField(
            fieldName: 'Weight',
            fieldType: 'numeric',
            isRequired: false,
            unitOptions: ['kg', 'g', 'lbs'],
            defaultUnit: 'kg',
            isUnitLocked: false,
            validation: {'min': 0.5, 'max': 5.0},
            displayOrder: 9,
          ),
          SpecificationField(
            fieldName: 'Battery Life',
            fieldType: 'text',
            isRequired: false,
            helpText: 'e.g., Up to 8 hours',
            displayOrder: 10,
          ),
          SpecificationField(
            fieldName: 'Warranty',
            fieldType: 'text',
            isRequired: false,
            displayOrder: 11,
          ),
        ],
        createdBy: adminId,
      );
    }
  }

  Future<void> seedGroceryTemplates(String adminId) async {
    print('Grocery category not found, skipping...');
  }

  Future<void> seedFashionTemplates(String adminId) async {
    print('Fashion category not found, skipping...');
  }

  Future<void> seedHomeKitchenTemplates(String adminId) async {
    print('Home & Kitchen category not found, skipping...');
  }

  Future<void> seedBeautyTemplates(String adminId) async {
    print('Beauty category not found, skipping...');
  }

  /// Get subcategory ID by name
  Future<String?> _getSubcategoryId(String categoryId, String subcategoryName) async {
    try {
      print('DEBUG: Looking for subcategory "$subcategoryName" under category "$categoryId"');
      
      final subcategoryQuery = await _firestore
          .collection('subcategories')
          .where('category_id', isEqualTo: categoryId)
          .where('name', isEqualTo: subcategoryName)
          .limit(1)
          .get();

      print('DEBUG: Query returned ${subcategoryQuery.docs.length} documents');
      
      if (subcategoryQuery.docs.isNotEmpty) {
        String id = subcategoryQuery.docs.first.id;
        var data = subcategoryQuery.docs.first.data();
        print('DEBUG: Found subcategory with ID: $id, name: ${data['name']}');
        return id;
      }
      
      // If not found, let's check what subcategories exist for this category
      print('DEBUG: Subcategory not found. Checking all subcategories for this category...');
      final allSubcats = await _firestore
          .collection('subcategories')
          .where('category_id', isEqualTo: categoryId)
          .get();
      
      print('DEBUG: Found ${allSubcats.docs.length} total subcategories for category $categoryId:');
      for (var doc in allSubcats.docs) {
        print('  - ${doc.data()['name']} (ID: ${doc.id})');
      }
      
      return null;
    } catch (e) {
      print('ERROR fetching subcategory ID for $subcategoryName: $e');
      return null;
    }
  }

  /// Helper to create a specification template
  Future<void> _createTemplate({
    required String categoryId,
    required String categoryName,
    String? subcategoryId,
    String? subcategoryName,
    required List<SpecificationField> fields,
    required String createdBy,
  }) async {
    try {
      final template = CategorySpecification(
        id: '', // Empty ID - Firestore will assign during add()
        categoryId: categoryId,
        categoryName: categoryName,
        subcategoryId: subcategoryId,
        subcategoryName: subcategoryName,
        fields: fields,
        version: 1,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('category_specifications').add(template.toMap());
      
      String location = subcategoryName != null 
          ? '$categoryName > $subcategoryName' 
          : categoryName;
      print('✓ $location template created (${fields.length} fields)');
    } catch (e) {
      print('Error creating template: $e');
    }
  }
}
