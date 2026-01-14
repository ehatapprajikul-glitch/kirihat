import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/models/category_specification_model.dart';
import 'package:kirihat_core/services/category_specification_service.dart';
import '../../widgets/hierarchical_category_selector_for_specs.dart';

class CategorySpecificationManager extends StatefulWidget {
  const CategorySpecificationManager({super.key});

  @override
  State<CategorySpecificationManager> createState() => _CategorySpecificationManagerState();
}

class _CategorySpecificationManagerState extends State<CategorySpecificationManager> {
  final CategorySpecificationService _specService = CategorySpecificationService();
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  List<String> _selectedCategoryPath = [];
  List<String> _selectedCategoryPathNames = [];
  int _selectedCategoryLevel = 0;
  CategorySpecification? _currentTemplate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel: Category Tree
        Expanded(
          flex: 1,
          child: _buildCategoryTree(),
        ),
        const VerticalDivider(width: 1),
        
        // Right Panel: Specification Fields
        Expanded(
          flex: 2,
          child: _buildSpecificationPanel(),
        ),
      ],
    );
  }

  Widget _buildCategoryTree() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Category Hierarchy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: HierarchicalCategorySelectorForSpecs(
              selectedCategoryId: _selectedCategoryId,
              onCategorySelected: (categoryId, categoryName, path, pathNames, level) {
                setState(() {
                  _selectedCategoryId = categoryId;
                  _selectedCategoryName = categoryName;
                  _selectedCategoryPath = path;
                  _selectedCategoryPathNames = pathNames;
                  _selectedCategoryLevel = level;
                });
                _loadTemplate();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificationPanel() {
    if (_selectedCategoryId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Select a category to manage specifications',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE8F5E9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display full category path as breadcrumb
                    if (_selectedCategoryPathNames.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (int i = 0; i < _selectedCategoryPathNames.length; i++) ...[
                            if (i > 0) Icon(Icons.chevron_right, size: 14, color: Colors.grey[600]),
                            Text(
                              _selectedCategoryPathNames[i],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          if (_selectedCategoryPathNames.isNotEmpty)
                            Icon(Icons.chevron_right, size: 14, color: Colors.grey[600]),
                        ],
                      ),
                    Text(
                      _selectedCategoryName ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF34A853),
                      ),
                    ),
                    Text(
                      'Level $_selectedCategoryLevel',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.visibility, color: Color(0xFF34A853)),
                tooltip: 'Preview Form',
                onPressed: _previewForm,
              ),
            ],
          ),
        ),

        // Section Management Panel
        if (_currentTemplate != null && _currentTemplate!.fields.isNotEmpty)
          _buildSectionManagementPanel(),

        // Specification Fields List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentTemplate == null || _currentTemplate!.fields.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No specification fields defined',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _addField,
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Field'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34A853),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildHierarchicalFieldList(),
        ),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _addField,
                icon: const Icon(Icons.add),
                label: const Text('Add Field'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34A853),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _saveTemplate,
                icon: const Icon(Icons.save),
                label: const Text('Save Template'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF34A853),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadTemplate() async {
    setState(() => _isLoading = true);
    
    var template = await _specService.getSpecificationTemplate(
      _selectedCategoryId!,
      _selectedCategoryName!,
    );

    setState(() {
      _currentTemplate = template ?? CategorySpecification(
          id: '',
          categoryId: _selectedCategoryId!,
          categoryName: _selectedCategoryName!,
          categoryPath: _selectedCategoryPath,
          categoryPathNames: _selectedCategoryPathNames,
          level: _selectedCategoryLevel,
          fields: [],
          version: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      _isLoading = false;
    });

    // Offer to seed default sections if template is empty
    if (_currentTemplate!.fields.isEmpty && mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showSeedDefaultSectionsDialog();
      });
    }
  }

  void _showSeedDefaultSectionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber[700], size: 28),
            const SizedBox(width: 12),
            const Text('Seed Default Sections?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This category has no specification template yet. Would you like to create a template with default sections?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Default sections to be created:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSectionPreviewItem('1', 'General', 'Brand, Model Number, Manufacturer'),
                  _buildSectionPreviewItem('2', 'Technical Specifications', 'Material, Color, Finish'),
                  _buildSectionPreviewItem('3', 'Warranty & Support', 'Warranty Period, Support Contact'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _seedDefaultSections();
            },
            icon: const Icon(Icons.check),
            label: const Text('Seed Default Sections'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34A853),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPreviewItem(String order, String title, String fields) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                order,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  fields,
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
    );
  }

  void _seedDefaultSections() {
    final defaultFields = <SpecificationField>[
      // General Section (order: 1)
      SpecificationField(
        fieldName: 'Brand',
        fieldType: 'text',
        section: 'General',
        sectionOrder: 1,
        isRequired: true,
        helpText: 'Product brand or manufacturer name',
        displayOrder: 0,
      ),
      SpecificationField(
        fieldName: 'Model Number',
        fieldType: 'text',
        section: 'General',
        sectionOrder: 1,
        isRequired: false,
        helpText: 'Unique model identifier',
        displayOrder: 1,
      ),
      SpecificationField(
        fieldName: 'Manufacturer',
        fieldType: 'text',
        section: 'General',
        sectionOrder: 1,
        isRequired: false,
        helpText: 'Manufacturing company name',
        displayOrder: 2,
      ),
      // Technical Specifications Section (order: 2)
      SpecificationField(
        fieldName: 'Material',
        fieldType: 'text',
        section: 'Technical Specifications',
        sectionOrder: 2,
        isRequired: false,
        helpText: 'Primary material composition',
        displayOrder: 3,
      ),
      SpecificationField(
        fieldName: 'Color',
        fieldType: 'text',
        section: 'Technical Specifications',
        sectionOrder: 2,
        isRequired: false,
        helpText: 'Available colors',
        displayOrder: 4,
      ),
      SpecificationField(
        fieldName: 'Finish',
        fieldType: 'dropdown',
        section: 'Technical Specifications',
        sectionOrder: 2,
        isRequired: false,
        helpText: 'Surface finish type',
        options: ['Matte', 'Glossy', 'Textured', 'Metallic'],
        displayOrder: 5,
      ),
      // Warranty & Support Section (order: 3)
      SpecificationField(
        fieldName: 'Warranty Period',
        fieldType: 'text',
        section: 'Warranty & Support',
        sectionOrder: 3,
        isRequired: false,
        helpText: 'Duration of warranty coverage (e.g., "1 Year", "2 Years")',
        displayOrder: 6,
      ),
      SpecificationField(
        fieldName: 'Support Contact',
        fieldType: 'text',
        section: 'Warranty & Support',
        sectionOrder: 3,
        isRequired: false,
        helpText: 'Customer support email or phone',
        displayOrder: 7,
      ),
    ];

    setState(() {
      _currentTemplate = CategorySpecification(
        id: _currentTemplate!.id,
        categoryId: _currentTemplate!.categoryId,
        categoryName: _currentTemplate!.categoryName,
        categoryPath: _currentTemplate!.categoryPath,
        categoryPathNames: _currentTemplate!.categoryPathNames,
        level: _currentTemplate!.level,
        fields: defaultFields,
        version: _currentTemplate!.version,
        createdAt: _currentTemplate!.createdAt,
        updatedAt: DateTime.now(),
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default sections created! Don\'t forget to save the template.'),
          backgroundColor: Color(0xFF34A853),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildSectionManagementPanel() {
    // Get unique sections with their field counts and current order
    final sectionInfo = <String, Map<String, dynamic>>{};
    for (var field in _currentTemplate!.fields) {
      if (!sectionInfo.containsKey(field.section)) {
        sectionInfo[field.section] = {
          'fieldCount': 0,
          'sectionOrder': field.sectionOrder,
        };
      }
      sectionInfo[field.section]!['fieldCount'] = (sectionInfo[field.section]!['fieldCount'] as int) + 1;
    }

    // Sort sections by sectionOrder
    final sortedSections = sectionInfo.keys.toList()..sort((a, b) {
      final aOrder = sectionInfo[a]!['sectionOrder'] as int;
      final bOrder = sectionInfo[b]!['sectionOrder'] as int;
      
      if (aOrder == 0 && bOrder == 0) return 0;
      if (aOrder == 0) return 1;
      if (bOrder == 0) return -1;
      return aOrder.compareTo(bOrder);
    });

    if (sortedSections.length <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.reorder, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Section Order Management',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              Tooltip(
                message: 'Add new section',
                child: OutlinedButton.icon(
                  onPressed: _showAddSectionDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Section'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade700),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final sectionName = sortedSections[oldIndex];
              final targetOrder = newIndex + 1;
              _reorderSection(sectionName, targetOrder);
            },
            children: sortedSections.asMap().entries.map((entry) {
              int visualOrder = entry.key + 1;
              String sectionName = entry.value;
              int fieldCount = sectionInfo[sectionName]!['fieldCount'] as int;

              return Container(
                key: ValueKey(sectionName),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.drag_indicator, color: Colors.grey.shade400, size: 24),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade800],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade300.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$visualOrder',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sectionName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.description, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                '$fieldCount field${fieldCount > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (fieldCount == 0)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _deleteSection(sectionName),
                        tooltip: 'Delete empty section',
                        color: Colors.red.shade400,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAddSectionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_box, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Add New Section'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Section Name',
                hintText: 'e.g., Packaging Information',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (controller.text.trim().isNotEmpty) {
                  _addNewSection(controller.text.trim());
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addNewSection(controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34A853),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addNewSection(String sectionName) {
    // Check for duplicate names
    final existingSections = _currentTemplate!.fields.map((f) => f.section.toLowerCase()).toSet();
    if (existingSections.contains(sectionName.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Section "$sectionName" already exists!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Find the next section order
    final maxOrder = _currentTemplate!.fields.isEmpty 
        ? 0 
        : _currentTemplate!.fields.map((f) => f.sectionOrder).reduce((a, b) => a > b ? a : b);
    final nextOrder = maxOrder + 1;

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Section "$sectionName" created! Now add a field to it.'),
        backgroundColor: const Color(0xFF34A853),
        duration: const Duration(seconds: 2),
      ),
    );

    // Immediately open the field dialog with this section pre-selected
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _addField(defaultSection: sectionName, defaultSectionOrder: nextOrder);
      }
    });
  }

  void _deleteSection(String sectionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text('Are you sure you want to delete the "$sectionName" section?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Remove all fields in this section (should be 0 anyway)
                final fields = _currentTemplate!.fields.where((f) => f.section != sectionName).toList();
                _currentTemplate = CategorySpecification(
                  id: _currentTemplate!.id,
                  categoryId: _currentTemplate!.categoryId,
                  subcategoryId: _currentTemplate!.subcategoryId,
                  categoryName: _currentTemplate!.categoryName,
                  subcategoryName: _currentTemplate!.subcategoryName,
                  fields: fields,
                  version: _currentTemplate!.version,
                  createdAt: _currentTemplate!.createdAt,
                  updatedAt: DateTime.now(),
                );
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Section "$sectionName" deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _reorderSection(String sectionName, int newPosition) {
    setState(() {
      List<SpecificationField> fields = List.from(_currentTemplate!.fields);
      
      for (int i = 0; i < fields.length; i++) {
        if (fields[i].section == sectionName) {
          fields[i] = SpecificationField(
            fieldName: fields[i].fieldName,
            fieldType: fields[i].fieldType,
            section: fields[i].section,
            sectionOrder: newPosition,
            isRequired: fields[i].isRequired,
            helpText: fields[i].helpText,
            options: fields[i].options,
            unitOptions: fields[i].unitOptions,
            isUnitLocked: fields[i].isUnitLocked,
            defaultUnit: fields[i].defaultUnit,
            validation: fields[i].validation,
            displayOrder: fields[i].displayOrder,
          );
        }
      }

      _currentTemplate = CategorySpecification(
        id: _currentTemplate!.id,
        categoryId: _currentTemplate!.categoryId,
        subcategoryId: _currentTemplate!.subcategoryId,
        categoryName: _currentTemplate!.categoryName,
        subcategoryName: _currentTemplate!.subcategoryName,
        fields: fields,
        version: _currentTemplate!.version,
        createdAt: _currentTemplate!.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  Widget _buildHierarchicalFieldList() {
    // Group fields by section
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (int i = 0; i < _currentTemplate!.fields.length; i++) {
      final field = _currentTemplate!.fields[i];
      if (!grouped.containsKey(field.section)) {
        grouped[field.section] = [];
      }
      grouped[field.section]!.add({'field': field, 'index': i});
    }

    // Sort sections by sectionOrder
    final sortedSections = grouped.keys.toList()..sort((a, b) {
      final aOrder = grouped[a]!.first['field'].sectionOrder;
      final bOrder = grouped[b]!.first['field'].sectionOrder;
      if (aOrder == 0 && bOrder == 0) return 0;
      if (aOrder == 0) return 1;
      if (bOrder == 0) return -1;
      return aOrder.compareTo(bOrder);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedSections.length,
      itemBuilder: (context, sectionIndex) {
        final sectionName = sortedSections[sectionIndex];
        final fieldsInSection = grouped[sectionName]!;
        
        return _SectionGroupCard(
          sectionName: sectionName,
          fieldsInSection: fieldsInSection,
          onEditField: (globalIndex) => _editField(globalIndex),
          onDeleteField: (globalIndex) => _deleteField(globalIndex),
          onRenameSection: (newName) => _renameSection(sectionName, newName),
          onReorderFields: (oldIndex, newIndex) => _reorderFieldsGlobally(oldIndex, newIndex),
          onAddField: () => _addField(defaultSection: sectionName),
        );
      },
    );
  }

  void _renameSection(String oldName, String newName) {
    if (oldName == newName || newName.trim().isEmpty) return;
    
    setState(() {
      List<SpecificationField> fields = List.from(_currentTemplate!.fields);
      
      for (int i = 0; i < fields.length; i++) {
        if (fields[i].section == oldName) {
          fields[i] = SpecificationField(
            fieldName: fields[i].fieldName,
            fieldType: fields[i].fieldType,
            section: newName,
            sectionOrder: fields[i].sectionOrder,
            isRequired: fields[i].isRequired,
            helpText: fields[i].helpText,
            options: fields[i].options,
            unitOptions: fields[i].unitOptions,
            isUnitLocked: fields[i].isUnitLocked,
            defaultUnit: fields[i].defaultUnit,
            validation: fields[i].validation,
            displayOrder: fields[i].displayOrder,
          );
        }
      }

      _currentTemplate = CategorySpecification(
        id: _currentTemplate!.id,
        categoryId: _currentTemplate!.categoryId,
        subcategoryId: _currentTemplate!.subcategoryId,
        categoryName: _currentTemplate!.categoryName,
        subcategoryName: _currentTemplate!.subcategoryName,
        fields: fields,
        version: _currentTemplate!.version,
        createdAt: _currentTemplate!.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _reorderFieldsGlobally(int oldIndex, int newIndex) {
    setState(() {
      List<SpecificationField> fields = List.from(_currentTemplate!.fields);
      
      // Remove field from old position
      final field = fields.removeAt(oldIndex);
      
      // Insert at new position
      fields.insert(newIndex, field);
      
      // Update display orders
      for (int i = 0; i < fields.length; i++) {
        fields[i] = SpecificationField(
          fieldName: fields[i].fieldName,
          fieldType: fields[i].fieldType,
          section: fields[i].section,
          sectionOrder: fields[i].sectionOrder,
          isRequired: fields[i].isRequired,
          helpText: fields[i].helpText,
          options: fields[i].options,
          unitOptions: fields[i].unitOptions,
          isUnitLocked: fields[i].isUnitLocked,
          defaultUnit: fields[i].defaultUnit,
          validation: fields[i].validation,
          displayOrder: i,
        );
      }

      _currentTemplate = CategorySpecification(
        id: _currentTemplate!.id,
        categoryId: _currentTemplate!.categoryId,
        subcategoryId: _currentTemplate!.subcategoryId,
        categoryName: _currentTemplate!.categoryName,
        subcategoryName: _currentTemplate!.subcategoryName,
        fields: fields,
        version: _currentTemplate!.version,
        createdAt: _currentTemplate!.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _addField({String? defaultSection, int? defaultSectionOrder}) {
    _showFieldDialog(defaultSection: defaultSection, defaultSectionOrder: defaultSectionOrder);
  }

  void _editField(int index) {
    _showFieldDialog(existingField: _currentTemplate!.fields[index], index: index);
  }

  void _deleteField(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text('Are you sure you want to delete "${_currentTemplate!.fields[index].fieldName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                var fields = List<SpecificationField>.from(_currentTemplate!.fields);
                fields.removeAt(index);
                _currentTemplate = CategorySpecification(
                  id: _currentTemplate!.id,
                  categoryId: _currentTemplate!.categoryId,
                  subcategoryId: _currentTemplate!.subcategoryId,
                  categoryName: _currentTemplate!.categoryName,
                  subcategoryName: _currentTemplate!.subcategoryName,
                  fields: fields,
                  version: _currentTemplate!.version,
                  createdAt: _currentTemplate!.createdAt,
                  updatedAt: DateTime.now(),
                );
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      var fields = List<SpecificationField>.from(_currentTemplate!.fields);
      var field = fields.removeAt(oldIndex);
      fields.insert(newIndex, field);
      
      // Update display order
      for (int i = 0; i < fields.length; i++) {
        fields[i] = SpecificationField(
          fieldName: fields[i].fieldName,
          fieldType: fields[i].fieldType,
          section: fields[i].section,
          isRequired: fields[i].isRequired,
          helpText: fields[i].helpText,
          options: fields[i].options,
          unitOptions: fields[i].unitOptions,
          isUnitLocked: fields[i].isUnitLocked,
          defaultUnit: fields[i].defaultUnit,
          validation: fields[i].validation,
          displayOrder: i,
        );
      }
      
      _currentTemplate = CategorySpecification(
        id: _currentTemplate!.id,
        categoryId: _currentTemplate!.categoryId,
        subcategoryId: _currentTemplate!.subcategoryId,
        categoryName: _currentTemplate!.categoryName,
        subcategoryName: _currentTemplate!.subcategoryName,
        fields: fields,
        version: _currentTemplate!.version,
        createdAt: _currentTemplate!.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _showFieldDialog({SpecificationField? existingField, int? index, String? defaultSection, int? defaultSectionOrder}) {
    showDialog(
      context: context,
      builder: (context) => _FieldEditorDialog(
        existingField: existingField,
        template: _currentTemplate,
        defaultSection: defaultSection,
        defaultSectionOrder: defaultSectionOrder,
        onSave: (field) {
          setState(() {
            var fields = List<SpecificationField>.from(_currentTemplate!.fields);
            if (index != null) {
              fields[index] = field;
            } else {
              fields.add(field);
            }
            _currentTemplate = CategorySpecification(
              id: _currentTemplate!.id,
              categoryId: _currentTemplate!.categoryId,
              subcategoryId: _currentTemplate!.subcategoryId,
              categoryName: _currentTemplate!.categoryName,
              subcategoryName: _currentTemplate!.subcategoryName,
              fields: fields,
              version: _currentTemplate!.version,
              createdAt: _currentTemplate!.createdAt,
              updatedAt: DateTime.now(),
            );
          });
        },
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (_currentTemplate == null) return;

    setState(() => _isLoading = true);
    
    String? result = await _specService.saveSpecificationTemplate(
      _currentTemplate!,
      FirebaseAuth.instance.currentUser!.uid,
    );

    setState(() => _isLoading = false);

    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template saved successfully!'),
          backgroundColor: Color(0xFF34A853),
        ),
      );
    }
  }

  void _previewForm() {
    if (_currentTemplate == null || _currentTemplate!.fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fields to preview')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Form Preview',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: _currentTemplate!.fields.map((field) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: '${field.fieldName}${field.isRequired ? " *" : ""}',
                            hintText: field.helpText,
                            border: const OutlineInputBorder(),
                            suffixIcon: field.helpText.isNotEmpty
                                ? Tooltip(
                                    message: field.helpText,
                                    child: const Icon(Icons.info_outline, size: 20),
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Category Tile Widget
class _CategoryTile extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final bool isSelected;
  final VoidCallback onCategoryTap;
  final Function(String, String) onSubcategoryTap;
  final String? selectedSubcategoryId;

  const _CategoryTile({
    required this.categoryId,
    required this.categoryName,
    required this.isSelected,
    required this.onCategoryTap,
    required this.onSubcategoryTap,
    this.selectedSubcategoryId,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            _isExpanded ? Icons.folder_open : Icons.folder,
            color: widget.isSelected ? const Color(0xFF34A853) : Colors.grey[600],
          ),
          title: Text(
            widget.categoryName,
            style: TextStyle(
              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
              color: widget.isSelected ? const Color(0xFF34A853) : Colors.black,
            ),
          ),
          trailing: IconButton(
            icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
          ),
          selected: widget.isSelected,
          selectedTileColor: const Color(0xFFE8F5E9),
          onTap: widget.onCategoryTap,
        ),
        if (_isExpanded)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('subcategories')
                .where('category_id', isEqualTo: widget.categoryId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 8),
                  child: Text(
                    'No subcategories',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  bool isSelected = widget.selectedSubcategoryId == doc.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.only(left: 48, right: 16),
                    leading: Icon(
                      Icons.subdirectory_arrow_right,
                      color: isSelected ? const Color(0xFF34A853) : Colors.grey[400],
                      size: 20,
                    ),
                    title: Text(
                      data['name'] ?? 'Unnamed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF34A853) : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: const Color(0xFFE8F5E9),
                    onTap: () => widget.onSubcategoryTap(doc.id, data['name']),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

// Field Card Widget
class _FieldCard extends StatelessWidget {
  final SpecificationField field;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FieldCard({
    super.key,
    required this.field,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF34A853), Color(0xFF2E8B47)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34A853).withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  field.fieldName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (field.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.category, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Type: ${field.fieldType}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
              if (field.helpText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  field.helpText,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
                color: Colors.blue.shade700,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete',
                color: Colors.red.shade400,
              ),
              Icon(Icons.drag_indicator, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// Field Editor Dialog
class _FieldEditorDialog extends StatefulWidget {
  final SpecificationField? existingField;
  final Function(SpecificationField) onSave;
  final CategorySpecification? template;
  final String? defaultSection;
  final int? defaultSectionOrder;

  const _FieldEditorDialog({
    this.existingField,
    required this.onSave,
    this.template,
    this.defaultSection,
    this.defaultSectionOrder,
  });

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _sectionController; // NEW
  late TextEditingController _helpTextController;
  late TextEditingController _unitController;
  late TextEditingController _optionsController;
  String _selectedType = 'text';
  bool _isRequired = false;
  bool _isUnitLocked = false; // NEW

  late List<String> _availableSections;

  final List<String> _fieldTypes = [
    'text',
    'numeric',
    'dropdown',
    'multiSelect',
    'date',
    'textarea',
  ];

  @override
  void initState() {
    super.initState();
    
    // Get all unique sections from template
    final sections = widget.template?.fields.map((f) => f.section).toSet().toList() ?? ['General'];
    if (!sections.contains('General')) sections.insert(0, 'General');
    
    // Add default section if provided and not already in the list
    if (widget.defaultSection != null && !sections.contains(widget.defaultSection)) {
      sections.add(widget.defaultSection!);
    }
    _availableSections = sections;
    
    _nameController = TextEditingController(text: widget.existingField?.fieldName ?? '');
    // Use defaultSection if provided, otherwise use existing field's section or 'General'
    _sectionController = TextEditingController(
      text: widget.existingField?.section ?? widget.defaultSection ?? 'General'
    );
    _helpTextController = TextEditingController(text: widget.existingField?.helpText ?? '');
    // Join units with comma for display
    _unitController = TextEditingController(text: widget.existingField?.unitOptions?.join(', ') ?? '');
    _optionsController = TextEditingController(
      text: widget.existingField?.options?.join(', ') ?? '',
    );
    _selectedType = widget.existingField?.fieldType ?? 'text';
    _isRequired = widget.existingField?.isRequired ?? false;
    _isUnitLocked = widget.existingField?.isUnitLocked ?? false; // NEW
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sectionController.dispose(); // NEW
    _helpTextController.dispose();
    _unitController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingField == null ? 'Add Field' : 'Edit Field',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sectionController,
                      decoration: const InputDecoration(
                        labelText: 'Section Header',
                        hintText: 'e.g. General, Warranty',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Field Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Section Selection Dropdown
              DropdownButtonFormField<String>(
                value: _sectionController.text.isEmpty ? 'General' : _sectionController.text,
                decoration: const InputDecoration(
                  labelText: 'Section *',
                  border: OutlineInputBorder(),
                  helperText: 'Group this field under a section header',
                ),
                items: _availableSections.map((section) {
                  return DropdownMenuItem(value: section, child: Text(section));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _sectionController.text = val ?? 'General';
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Field Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Field Type *',
                  border: OutlineInputBorder(),
                ),
                items: _fieldTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _helpTextController,
                decoration: const InputDecoration(
                  labelText: 'Help Text',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              if (_selectedType == 'numeric') ...[
                TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Units (comma-separated)',
                    hintText: 'e.g. kg, g, lb OR inches, cm',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  value: _isUnitLocked,
                  onChanged: (val) => setState(() => _isUnitLocked = val!),
                  title: const Text('Lock Unit Selection'),
                  subtitle: const Text('If checked, seller cannot change the first unit'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              
              if (['dropdown', 'multiSelect'].contains(_selectedType)) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Options (comma-separated) *',
                    border: OutlineInputBorder(),
                    hintText: 'Red, Blue, Green',
                  ),
                  validator: (val) => val!.isEmpty ? 'Required for dropdown' : null,
                ),
              ],
              
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _isRequired,
                onChanged: (val) => setState(() => _isRequired = val!),
                title: const Text('Required Field'),
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34A853),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    List<String> options = [];
    if (_optionsController.text.isNotEmpty) {
      options = _optionsController.text.split(',').map((e) => e.trim()).toList();
    }
    
    // Parse units
    List<String> unitOptions = [];
    if (_unitController.text.isNotEmpty) {
      unitOptions = _unitController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    var field = SpecificationField(
      fieldName: _nameController.text.trim(),
      fieldType: _selectedType,
      section: _sectionController.text.trim().isEmpty ? 'General' : _sectionController.text.trim(),
      sectionOrder: widget.existingField?.sectionOrder ?? widget.defaultSectionOrder ?? 0,
      isRequired: _isRequired,
      helpText: _helpTextController.text.trim(),
      options: options.isNotEmpty ? options : null,
      unitOptions: unitOptions.isNotEmpty ? unitOptions : null,
      isUnitLocked: _isUnitLocked,
      defaultUnit: unitOptions.isNotEmpty ? unitOptions.first : null,
      validation: widget.existingField?.validation,
      displayOrder: widget.existingField?.displayOrder ?? 0,
    );

    widget.onSave(field);
    Navigator.pop(context);
  }
}

// Collapsible Section Group Card
class _SectionGroupCard extends StatefulWidget {
  final String sectionName;
  final List<Map<String, dynamic>> fieldsInSection;
  final Function(int) onEditField;
  final Function(int) onDeleteField;
  final Function(String) onRenameSection;
  final Function(int, int) onReorderFields;
  final VoidCallback onAddField;

  const _SectionGroupCard({
    required this.sectionName,
    required this.fieldsInSection,
    required this.onEditField,
    required this.onDeleteField,
    required this.onRenameSection,
    required this.onReorderFields,
    required this.onAddField,
  });

  @override
  State<_SectionGroupCard> createState() => _SectionGroupCardState();
}

class _SectionGroupCardState extends State<_SectionGroupCard> {
  bool _isExpanded = true;
  bool _isRenaming = false;
  late TextEditingController _renameController;

  late List<String> _availableSections;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController(text: widget.sectionName);
    
    // Get all unique sections from existing template
    // Note: widget.template and widget.existingField are not part of _SectionGroupCard's properties.
    // This logic might be intended for a different widget (e.g., _AddFieldDialogState).
    // Assuming this is a placeholder or needs context from the parent widget.
    // For _SectionGroupCard, _availableSections would typically be passed in or derived differently.
    // As per instruction, adding it directly.
    final sections = ['General']; // Placeholder, as widget.template is not available here.
    _availableSections = sections;
  }

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF34A853).withOpacity(0.15),
                    const Color(0xFF34A853).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: _isExpanded ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, color: Color(0xFF34A853)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isRenaming
                        ? TextField(
                            controller: _renameController,
                            autofocus: true,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            onSubmitted: (_) {
                              widget.onRenameSection(_renameController.text.trim());
                              setState(() => _isRenaming = false);
                            },
                          )
                        : Text(
                            widget.sectionName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF34A853),
                            ),
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34A853), Color(0xFF2E8B47)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF34A853).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${widget.fieldsInSection.length} field${widget.fieldsInSection.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!_isRenaming) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Add field to this section',
                      child: OutlinedButton.icon(
                        onPressed: widget.onAddField,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Field', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF34A853),
                          side: const BorderSide(color: Color(0xFF34A853)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => setState(() => _isRenaming = true),
                      tooltip: 'Rename section',
                      color: const Color(0xFF34A853),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.check, size: 18),
                      onPressed: () {
                        widget.onRenameSection(_renameController.text.trim());
                        setState(() => _isRenaming = false);
                      },
                      color: Colors.green,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _renameController.text = widget.sectionName;
                        setState(() => _isRenaming = false);
                      },
                      color: Colors.red,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  // Handle field reordering within this section
                  final List<int> globalIndexes = widget.fieldsInSection.map((fd) => fd['index'] as int).toList();
                  
                  // Adjust newIndex if moving down
                  if (newIndex > oldIndex) newIndex--;
                  
                  // Call parent's reorder method with global indexes
                  widget.onReorderFields(globalIndexes[oldIndex], globalIndexes[newIndex]);
                },
                children: widget.fieldsInSection.map((fieldData) {
                  final field = fieldData['field'] as SpecificationField;
                  final globalIndex = fieldData['index'] as int;
                  
                  return _FieldCard(
                    key: ValueKey(field.fieldName + globalIndex.toString()),
                    field: field,
                    index: globalIndex,
                    onEdit: () => widget.onEditField(globalIndex),
                    onDelete: () => widget.onDeleteField(globalIndex),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
