import 'package:flutter/material.dart';

class SectionConfigDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSave;

  const SectionConfigDialog({
    super.key,
    this.initialData,
    required this.onSave,
  });

  @override
  State<SectionConfigDialog> createState() => _SectionConfigDialogState();
}

class _SectionConfigDialogState extends State<SectionConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  String _selectedType = 'banner';
  String _categoryFilter = 'All';
  
  final List<String> _sectionTypes = [
    'banner',
    'category_grid',
    'product_row',
    'product_grid',
    'ads',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _titleController.text = widget.initialData!['title'] ?? '';
      _selectedType = widget.initialData!['type'] ?? 'banner';
      _categoryFilter = widget.initialData!['category_filter'] ?? 'All';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings, color: Color(0xFF0D9759)),
                  const SizedBox(width: 12),
                  Text(
                    widget.initialData == null ? 'Add Section' : 'Edit Section',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Section Type *',
                  border: OutlineInputBorder(),
                ),
                items: _sectionTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_formatTypeName(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedType = value!);
                },
              ),

              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Section Title *',
                  hintText: 'e.g., Featured Products, Top Categories',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Category Filter (for product sections)
              if (_selectedType.contains('product')) ...[
                DropdownButtonFormField<String>(
                  value: _categoryFilter,
                  decoration: const InputDecoration(
                    labelText: 'Category Filter',
                    border: OutlineInputBorder(),
                    helperText: 'Filter products by category',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Categories')),
                    DropdownMenuItem(value: 'Groceries', child: Text('Groceries')),
                    DropdownMenuItem(value: 'Dairy', child: Text('Dairy')),
                    DropdownMenuItem(value: 'Fruits', child: Text('Fruits')),
                    DropdownMenuItem(value: 'Vegetables', child: Text('Vegetables')),
                    DropdownMenuItem(value: 'Snacks', child: Text('Snacks')),
                  ],
                  onChanged: (value) {
                    setState(() => _categoryFilter = value!);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getSectionDescription(_selectedType),
                        style: const TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text('SAVE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTypeName(String type) {
    switch (type) {
      case 'banner':
        return '📸 Banner Carousel';
      case 'category_grid':
        return '📁 Category Grid';
      case 'product_row':
        return '➡️ Product Row';
      case 'product_grid':
        return '⊞ Product Grid';
      case 'ads':
        return '📢 Advertisement';
      default:
        return type;
    }
  }

  String _getSectionDescription(String type) {
    switch (type) {
      case 'banner':
        return 'Displays a carousel of clickable banner images from the banners collection';
      case 'category_grid':
        return 'Shows a grid of categories with icons for easy navigation';
      case 'product_row':
        return 'Horizontal scrollable row of product cards';
      case 'product_grid':
        return 'Grid layout displaying multiple products in rows and columns';
      case 'ads':
        return 'Advertisement banner or promotional section';
      default:
        return 'Custom section';
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> sectionData = {
      'type': _selectedType,
      'title': _titleController.text.trim(),
      'category_filter': _selectedType.contains('product') ? _categoryFilter : null,
    };

    widget.onSave(sectionData);
    Navigator.pop(context);
  }
}
