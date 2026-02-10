import 'package:flutter/material.dart';

/// Widget for keyword selection with intelligent suggestions
class KeywordSuggestionWidget extends StatefulWidget {
  final String categoryName;
  final String productTitle;
  final List<String> initialKeywords;
  final Function(List<String>) onKeywordsChanged;
  final int maxKeywords;

  const KeywordSuggestionWidget({
    super.key,
    required this.categoryName,
    required this.productTitle,
    this.initialKeywords = const [],
    required this.onKeywordsChanged,
    this.maxKeywords = 15,
  });

  @override
  State<KeywordSuggestionWidget> createState() => _KeywordSuggestionWidgetState();
}

class _KeywordSuggestionWidgetState extends State<KeywordSuggestionWidget> {
  final TextEditingController _customKeywordController = TextEditingController();
  final List<String> _selectedKeywords = [];
  List<KeywordSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _selectedKeywords.addAll(widget.initialKeywords);
    _generateSuggestions();
  }

  @override
  void dispose() {
    _customKeywordController.dispose();
    super.dispose();
  }

  void _generateSuggestions() {
    // Extract keywords from product title
    List<String> titleWords = widget.productTitle
        .toLowerCase()
        .split(RegExp(r'[\s,\-_]+'))
        .where((word) => word.length > 2)
        .toList();

    // Generate suggestions based on category and title
    List<KeywordSuggestion> suggestions = [];

    // Add category-based keywords
    suggestions.add(KeywordSuggestion(
      keyword: widget.categoryName.toLowerCase(),
      volume: SearchVolume.high,
      reason: 'Category match',
    ));

    // Add title-based keywords
    for (var word in titleWords) {
      if (!suggestions.any((s) => s.keyword == word)) {
        suggestions.add(KeywordSuggestion(
          keyword: word,
          volume: SearchVolume.medium,
          reason: 'From product title',
        ));
      }
    }

    // Add common e-commerce keywords based on category
    List<String> commonKeywords = _getCommonKeywordsForCategory(widget.categoryName);
    for (var keyword in commonKeywords) {
      if (!suggestions.any((s) => s.keyword == keyword)) {
        suggestions.add(KeywordSuggestion(
          keyword: keyword,
          volume: SearchVolume.medium,
          reason: 'Popular in category',
        ));
      }
    }

    setState(() {
      _suggestions = suggestions.take(20).toList();
    });
  }

  List<String> _getCommonKeywordsForCategory(String category) {
    Map<String, List<String>> categoryKeywords = {
      'Electronics': ['smartphone', 'mobile', 'gadget', 'tech', 'wireless', 'smart', 'digital'],
      'Grocery': ['food', 'snack', 'healthy', 'organic', 'fresh', 'packaged', 'instant'],
      'Fashion': ['clothing', 'wear', 'style', 'fashion', 'trendy', 'casual', 'formal'],
      'Home & Kitchen': ['kitchen', 'home', 'utensil', 'cookware', 'appliance', 'dining'],
      'Beauty': ['beauty', 'skincare', 'cosmetic', 'care', 'natural', 'skin', 'face'],
    };

    return categoryKeywords[category] ?? [];
  }

  void _toggleKeyword(String keyword) {
    if (_selectedKeywords.contains(keyword)) {
      setState(() {
        _selectedKeywords.remove(keyword);
      });
    } else {
      if (_selectedKeywords.length >= widget.maxKeywords) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum ${widget.maxKeywords} keywords allowed')),
        );
        return;
      }
      setState(() {
        _selectedKeywords.add(keyword);
      });
    }
    widget.onKeywordsChanged(_selectedKeywords);
  }

  void _addCustomKeyword() {
    String keyword = _customKeywordController.text.toLowerCase().trim();
    
    if (keyword.isEmpty) {
      return;
    }

    if (_selectedKeywords.contains(keyword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyword already added')),
      );
      return;
    }

    if (_selectedKeywords.length >= widget.maxKeywords) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum ${widget.maxKeywords} keywords allowed')),
      );
      return;
    }

    if (keyword.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyword must be at least 3 characters')),
      );
      return;
    }

    setState(() {
      _selectedKeywords.add(keyword);
      _customKeywordController.clear();
    });
    widget.onKeywordsChanged(_selectedKeywords);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Keywords Count
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_offer, color: Color(0xFF34A853)),
              const SizedBox(width: 8),
              Text(
                'Selected: ${_selectedKeywords.length}/${widget.maxKeywords}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF34A853),
                ),
              ),
              const Spacer(),
              if (_selectedKeywords.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedKeywords.clear());
                    widget.onKeywordsChanged(_selectedKeywords);
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Selected Keywords
        if (_selectedKeywords.isNotEmpty) ...[
          const Text(
            'Selected Keywords',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedKeywords.map((keyword) {
              return Chip(
                label: Text(keyword),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _toggleKeyword(keyword),
                backgroundColor: const Color(0xFF34A853),
                labelStyle: const TextStyle(color: Colors.white),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Suggested Keywords
        const Text(
          'Suggested Keywords',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Based on your product title and category',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((suggestion) {
            bool isSelected = _selectedKeywords.contains(suggestion.keyword);
            return _SuggestionChip(
              suggestion: suggestion,
              isSelected: isSelected,
              onTap: () => _toggleKeyword(suggestion.keyword),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Custom Keyword Input
        const Text(
          'Add Custom Keyword',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customKeywordController,
                decoration: const InputDecoration(
                  hintText: 'Enter custom keyword',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add),
                ),
                onSubmitted: (_) => _addCustomKeyword(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addCustomKeyword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34A853),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }
}

class KeywordSuggestion {
  final String keyword;
  final SearchVolume volume;
  final String reason;

  KeywordSuggestion({
    required this.keyword,
    required this.volume,
    required this.reason,
  });
}

enum SearchVolume { high, medium, low }

class _SuggestionChip extends StatelessWidget {
  final KeywordSuggestion suggestion;
  final bool isSelected;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.suggestion,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color volumeColor = _getVolumeColor();

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '${suggestion.reason} • ${_getVolumeText()} search volume',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF34A853) : Colors.white,
            border: Border.all(
              color: isSelected ? const Color(0xFF34A853) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : volumeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                suggestion.keyword,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getVolumeColor() {
    switch (suggestion.volume) {
      case SearchVolume.high:
        return Colors.green;
      case SearchVolume.medium:
        return Colors.orange;
      case SearchVolume.low:
        return Colors.red;
    }
  }

  String _getVolumeText() {
    switch (suggestion.volume) {
      case SearchVolume.high:
        return 'High';
      case SearchVolume.medium:
        return 'Medium';
      case SearchVolume.low:
        return 'Low';
    }
  }
}
