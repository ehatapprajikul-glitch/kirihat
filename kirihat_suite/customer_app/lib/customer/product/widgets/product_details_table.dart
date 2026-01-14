import 'package:flutter/material.dart';

/// A table widget that displays product details in a Blinkit-style key-value format
/// Compatible with standard Flutter usage, designed for clean data presentation
class ProductDetailsTable extends StatefulWidget {
  final Map<String, dynamic> productData;
  final Map<String, dynamic> specifications;
  final List<String> excludedFields;
  final bool defaultExpanded;

  const ProductDetailsTable({
    super.key,
    required this.productData,
    this.specifications = const {},
    this.excludedFields = const [],
    this.defaultExpanded = true,
  });

  @override
  State<ProductDetailsTable> createState() => _ProductDetailsTableState();
}

class _ProductDetailsTableState extends State<ProductDetailsTable> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.defaultExpanded;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Merge and Filter Data
    final Map<String, String> displayData = {};

    // Standard fields to always exclude from the details table
    // Defined in lowercase for case-insensitive matching
    final Set<String> defaultExcluded = {
      'name', 'price', 'mrp', 'description', 'images', 'imageurl', 'thumbnail',
      'id', 'vendor_id', 'vendorid', 'category_id', 'subcategory_id', 'sku', 'barcode',
      'created_at', 'updated_at', 'is_active', 'isactive', 'tags',
      'search_keywords', 'specifications', 'reviews', 'ratings',
      'stock_quantity', 'stockquantity', 'isavailable', 'isavailableincurrentvendor',
      'unit', 'category', 'subcategory', 'brand', 'choose', // Added 'choose' as per screenshot, likely garbage data
      'color options' // Explicitly exclude complex keys if they leak through
    };

    // Process top-level product data
    widget.productData.forEach((key, value) {
      final lowerKey = key.toLowerCase();

      // 1. Check exclusion lists (Case Insensitive)
      if (widget.excludedFields.any((k) => k.toLowerCase() == lowerKey)) return;
      if (defaultExcluded.contains(lowerKey)) return;
      
      // 2. Check for internal keys (ending in _id or Id)
      if (lowerKey.endsWith('_id') || lowerKey.endsWith('id')) return;

      // 3. Check value validity
      if (value == null) return;
      
      // 4. Skip complex types (Maps and Lists) to avoid "{}" or "[]"
      if (value is Map || value is List) return;

      String stringValue = value.toString();
      
      // 5. Skip empty strings or "null" string
      if (stringValue.isEmpty || stringValue.toLowerCase() == 'null') return;
      
      // 6. Format Key
      String formattedKey = _formatKey(key);
      displayData[formattedKey] = stringValue;
    });

    // Process specifications (usually already formatted keys)
    widget.specifications.forEach((key, value) {
      if (value != null) {
        String stringValue = value.toString();
        if (stringValue.isNotEmpty) {
          displayData[key] = stringValue;
        }
      }
    });
    
    if (displayData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row with Expand/Collapse
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Product Details',
                  style: TextStyle(
                    fontSize: 17, // Slightly smaller, cleaner
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1C),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        
        // Content - No border box, just content
        AnimatedCrossFade(
          firstChild: Container(),
          secondChild: Column( // Removed Container decoration
            children: displayData.entries.toList().asMap().entries.map((entry) {
              int idx = entry.key;
              MapEntry<String, String> data = entry.value;
              bool isLast = idx == displayData.length - 1;

              return _buildRow(data.key, data.value, isLast);
            }).toList(),
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  Widget _buildRow(String key, String value, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14), // Increased vertical padding, removed horizontal
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100)), // Subtle divider
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4, // 40% width for key
            child: Text(
              key,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w400, // Regular weight for keys
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6, // 60% width for value
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1C1C1C), // Darker black
                fontSize: 13,
                fontWeight: FontWeight.w500, // Medium weight for values
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    // 1. Replace underscores with spaces
    String formatted = key.replaceAll('_', ' ');
    
    // 2. Capitalize first letter of each word
    return formatted.split(' ').map((str) {
      if (str.isEmpty) return '';
      return str[0].toUpperCase() + str.substring(1).toLowerCase();
    }).join(' ');
  }
}
