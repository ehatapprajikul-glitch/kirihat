import 'package:flutter/material.dart';
import '../../models/product_filter.dart';
import '../../utils/app_constants.dart';

/// Bottom sheet for filtering and sorting products
class FilterBottomSheet extends StatefulWidget {
  final ProductFilter currentFilter;
  final List<String> availableBrands;
  final List<String> availableCategories;
  final double maxPrice;

  const FilterBottomSheet({
    super.key,
    required this.currentFilter,
    this.availableBrands = const [],
    this.availableCategories = const [],
    this.maxPrice = 10000,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late ProductFilter _filter;
  late RangeValues _priceRange;

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter;
    _priceRange = RangeValues(
      _filter.minPrice ?? 0,
      _filter.maxPrice ?? widget.maxPrice,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          const Divider(height: 1),
          
          // Filter Options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              children: [
                _buildPriceFilter(),
                const SizedBox(height: AppConstants.paddingLarge),
                if (widget.availableBrands.isNotEmpty) ...[
                  _buildBrandFilter(),
                  const SizedBox(height: AppConstants.paddingLarge),
                ],
                if (widget.availableCategories.isNotEmpty) ...[
                  _buildCategoryFilter(),
                  const SizedBox(height: AppConstants.paddingLarge),
                ],
                _buildSortOptions(),
              ],
            ),
          ),
          
          // Apply Button
          _buildApplyButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Filters & Sort',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              if (_filter.hasActiveFilters)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filter.activeFilterCount} active',
                    style: const TextStyle(
                      color: AppConstants.primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filter = const ProductFilter();
                    _priceRange = RangeValues(0, widget.maxPrice);
                  });
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price Range',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: widget.maxPrice,
          divisions: 100,
          activeColor: AppConstants.primaryGreen,
          labels: RangeLabels(
            '₹${_priceRange.start.round()}',
            '₹${_priceRange.end.round()}',
          ),
          onChanged: (values) {
            setState(() => _priceRange = values);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₹${_priceRange.start.round()}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '₹${_priceRange.end.round()}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrandFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Brands',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableBrands.map((brand) {
            final isSelected = _filter.brands.contains(brand);
            return FilterChip(
              label: Text(brand),
              selected: isSelected,
              selectedColor: AppConstants.primaryGreen.withOpacity(0.2),
              checkmarkColor: AppConstants.primaryGreen,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _filter = _filter.copyWith(
                      brands: [..._filter.brands, brand],
                    );
                  } else {
                    _filter = _filter.copyWith(
                      brands: _filter.brands.where((b) => b != brand).toList(),
                    );
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableCategories.map((category) {
            final isSelected = _filter.categories.contains(category);
            return FilterChip(
              label: Text(category),
              selected: isSelected,
              selectedColor: AppConstants.primaryGreen.withOpacity(0.2),
              checkmarkColor: AppConstants.primaryGreen,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _filter = _filter.copyWith(
                      categories: [..._filter.categories, category],
                    );
                  } else {
                    _filter = _filter.copyWith(
                      categories: _filter.categories.where((c) => c != category).toList(),
                    );
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSortOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sort By',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildSortOption('Price: Low to High', 'price_low', Icons.arrow_upward),
        _buildSortOption('Price: High to Low', 'price_high', Icons.arrow_downward),
        _buildSortOption('Popularity', 'popularity', Icons.trending_up),
        _buildSortOption('Newest First', 'newest', Icons.fiber_new),
      ],
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    final isSelected = _filter.sortBy == value;
    return InkWell(
      onTap: () {
        setState(() {
          _filter = _filter.copyWith(sortBy: value);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppConstants.primaryGreen.withOpacity(0.1) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? AppConstants.primaryGreen 
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppConstants.primaryGreen : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppConstants.primaryGreen : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppConstants.primaryGreen,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              final updatedFilter = _filter.copyWith(
                minPrice: _priceRange.start,
                maxPrice: _priceRange.end,
              );
              Navigator.pop(context, updatedFilter);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
              ),
            ),
            child: Text(
              _filter.hasActiveFilters 
                  ? 'Apply ${_filter.activeFilterCount} Filter${_filter.activeFilterCount > 1 ? 's' : ''}'
                  : 'Apply Filters',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
