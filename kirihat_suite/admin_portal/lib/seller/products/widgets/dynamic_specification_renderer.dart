import 'package:flutter/material.dart';
import 'package:kirihat_core/models/category_specification_model.dart';

/// Dynamically renders specification fields based on category template
class DynamicSpecificationRenderer extends StatefulWidget {
  final List<SpecificationField> fields;
  final Map<String, dynamic> initialValues;
  final Function(Map<String, dynamic>) onValuesChanged;

  const DynamicSpecificationRenderer({
    super.key,
    required this.fields,
    required this.initialValues,
    required this.onValuesChanged,
  });

  @override
  State<DynamicSpecificationRenderer> createState() => _DynamicSpecificationRendererState();
}

class _DynamicSpecificationRendererState extends State<DynamicSpecificationRenderer> {
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _values.addAll(widget.initialValues);
    
    // Initialize controllers for text fields and default units
    for (var field in widget.fields) {
      if (['text', 'numeric', 'textarea'].contains(field.fieldType)) {
        _controllers[field.fieldName] = TextEditingController(
          text: _values[field.fieldName]?.toString() ?? '',
        );
      }
      
      // Initialize default unit if missing
      if (field.fieldType == 'numeric' && field.unitOptions != null && field.unitOptions!.isNotEmpty) {
         String unitKey = '${field.fieldName}_unit';
         if (!_values.containsKey(unitKey)) {
           _values[unitKey] = field.defaultUnit ?? field.unitOptions!.first;
         }
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateValue(String fieldName, dynamic value) {
    _values[fieldName] = value;
    // Debounce the parent callback to prevent excessive rebuilds
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        widget.onValuesChanged(_values);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fields.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No specifications required for this category',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Group fields by section
    Map<String, List<SpecificationField>> sections = {};
    for (var field in widget.fields) {
      if (!sections.containsKey(field.section)) {
        sections[field.section] = [];
      }
      sections[field.section]!.add(field);
    }
    
    // Sort sections by sectionOrder (or first field's displayOrder if sectionOrder is 0)
    final sortedSectionNames = sections.keys.toList()..sort((a, b) {
      final aOrder = sections[a]!.first.sectionOrder;
      final bOrder = sections[b]!.first.sectionOrder;
      
      if (aOrder == 0 && bOrder == 0) {
        // Both sections have no explicit order, fall back to field display order
        return sections[a]!.first.displayOrder
            .compareTo(sections[b]!.first.displayOrder);
      }
      
      if (aOrder == 0) return 1; // Sections with no explicit order go last
      if (bOrder == 0) return -1;
      
      return aOrder.compareTo(bOrder);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedSectionNames.map((sectionName) {
          List<SpecificationField> sectionFields = sections[sectionName]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  sectionName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              
              // Fields in this section
              ...sectionFields.map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildFieldWidget(field),
              )),
              
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFieldWidget(SpecificationField field) {
    switch (field.fieldType) {
      case 'text':
        return _buildTextField(field);
      case 'numeric':
        return _buildNumericField(field);
      case 'dropdown':
        return _buildDropdownField(field);
      case 'multiSelect':
        return _buildMultiSelectField(field);
      case 'date':
        return _buildDateField(field);
      case 'textarea':
        return _buildTextAreaField(field);
      default:
        return _buildTextField(field);
    }
  }

  Widget _buildTextField(SpecificationField field) {
    return TextFormField(
      controller: _controllers[field.fieldName],
      decoration: _buildDecoration(field),
      onChanged: (value) => _updateValue(field.fieldName, value),
      validator: (val) {
        if (field.isRequired && (val == null || val.isEmpty)) {
          return '${field.fieldName} is required';
        }
        return null;
      },
    );
  }

  Widget _buildNumericField(SpecificationField field) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _controllers[field.fieldName],
            decoration: _buildDecoration(field),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              double? numValue = double.tryParse(value);
              _updateValue(field.fieldName, numValue);
            },
            validator: (val) {
              if (field.isRequired && (val == null || val.isEmpty)) {
                return '${field.fieldName} is required';
              }
              if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                return 'Must be a valid number';
              }
              
              // Validation rules
              if (field.validation != null && val != null && val.isNotEmpty) {
                double? numVal = double.tryParse(val);
                if (numVal != null) {
                  if (field.validation!['min'] != null && numVal < field.validation!['min']) {
                    return 'Must be at least ${field.validation!['min']}';
                  }
                  if (field.validation!['max'] != null && numVal > field.validation!['max']) {
                    return 'Must not exceed ${field.validation!['max']}';
                  }
                }
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        if (field.unitOptions != null && field.unitOptions!.isNotEmpty)
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              value: _values['${field.fieldName}_unit']?.toString() ?? field.defaultUnit ?? field.unitOptions!.first,
              decoration: InputDecoration(
                labelText: 'Unit',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                enabled: !field.isUnitLocked, // Disable if locked
              ),
              items: field.unitOptions!.map((unit) {
                return DropdownMenuItem(value: unit, child: Text(unit));
              }).toList(),
              onChanged: field.isUnitLocked 
                  ? null 
                  : (value) => _updateValue('${field.fieldName}_unit', value),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdownField(SpecificationField field) {
    return DropdownButtonFormField<String>(
      value: _values[field.fieldName]?.toString(),
      decoration: _buildDecoration(field),
      items: field.options?.map((option) {
        return DropdownMenuItem(value: option, child: Text(option));
      }).toList() ?? [],
      onChanged: (value) => _updateValue(field.fieldName, value),
      validator: (val) {
        if (field.isRequired && val == null) {
          return '${field.fieldName} is required';
        }
        return null;
      },
    );
  }

  Widget _buildMultiSelectField(SpecificationField field) {
    List<String> selectedValues = [];
    if (_values[field.fieldName] is List) {
      selectedValues = List<String>.from(_values[field.fieldName]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${field.fieldName}${field.isRequired ? " *" : ""}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            if (field.helpText.isNotEmpty)
              Tooltip(
                message: field.helpText,
                child: Icon(Icons.info_outline, size: 20, color: Colors.grey[600]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: field.options?.map((option) {
            bool isSelected = selectedValues.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  selectedValues.add(option);
                } else {
                  selectedValues.remove(option);
                }
                _updateValue(field.fieldName, List.from(selectedValues));
              },
              selectedColor: const Color(0xFF34A853).withOpacity(0.2),
              checkmarkColor: const Color(0xFF34A853),
            );
          }).toList() ?? [],
        ),
        if (field.isRequired && selectedValues.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select at least one option',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDateField(SpecificationField field) {
    DateTime? selectedDate = _values[field.fieldName];
    
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          _updateValue(field.fieldName, picked);
        }
      },
      child: InputDecorator(
        decoration: _buildDecoration(field),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedDate != null
                  ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                  : 'Select date',
              style: TextStyle(
                color: selectedDate != null ? Colors.black : Colors.grey[600],
              ),
            ),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextAreaField(SpecificationField field) {
    return TextFormField(
      controller: _controllers[field.fieldName],
      decoration: _buildDecoration(field),
      maxLines: 4,
      onChanged: (value) => _updateValue(field.fieldName, value),
      validator: (val) {
        if (field.isRequired && (val == null || val.isEmpty)) {
          return '${field.fieldName} is required';
        }
        return null;
      },
    );
  }

  InputDecoration _buildDecoration(SpecificationField field) {
    return InputDecoration(
      labelText: '${field.fieldName}${field.isRequired ? " *" : ""}',
      hintText: field.helpText,
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF34A853), width: 2),
      ),
      suffixIcon: field.helpText.isNotEmpty
          ? Tooltip(
              message: field.helpText,
              child: Icon(Icons.info_outline, size: 20, color: Colors.grey[600]),
            )
          : null,
    );
  }
}
