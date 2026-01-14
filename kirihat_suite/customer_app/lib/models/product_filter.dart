/// Product filter model for filtering and sorting products
class ProductFilter {
  final double? minPrice;
  final double? maxPrice;
  final List<String> brands;
  final List<String> categories;
  final String sortBy; // 'price_low', 'price_high', 'popularity', 'newest'

  const ProductFilter({
    this.minPrice,
    this.maxPrice,
    this.brands = const [],
    this.categories = const [],
    this.sortBy = 'popularity',
  });

  ProductFilter copyWith({
    double? minPrice,
    double? maxPrice,
    List<String>? brands,
    List<String>? categories,
    String? sortBy,
  }) {
    return ProductFilter(
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      brands: brands ?? this.brands,
      categories: categories ?? this.categories,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Check if any filters are active
  bool get hasActiveFilters =>
      minPrice != null ||
      maxPrice != null ||
      brands.isNotEmpty ||
      categories.isNotEmpty;

  /// Get count of active filters
  int get activeFilterCount {
    int count = 0;
    if (minPrice != null || maxPrice != null) count++;
    count += brands.length;
    count += categories.length;
    return count;
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() => {
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'brands': brands,
        'categories': categories,
        'sortBy': sortBy,
      };

  /// Create from JSON
  factory ProductFilter.fromJson(Map<String, dynamic> json) {
    return ProductFilter(
      minPrice: json['minPrice']?.toDouble(),
      maxPrice: json['maxPrice']?.toDouble(),
      brands: List<String>.from(json['brands'] ?? []),
      categories: List<String>.from(json['categories'] ?? []),
      sortBy: json['sortBy'] ?? 'popularity',
    );
  }

  /// Apply filter to a list of products
  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> products) {
    var filtered = products.where((product) {
      // Price filter
      if (minPrice != null || maxPrice != null) {
        final price = (product['price'] ?? 0).toDouble();
        if (minPrice != null && price < minPrice!) return false;
        if (maxPrice != null && price > maxPrice!) return false;
      }

      // Brand filter
      if (brands.isNotEmpty) {
        final productBrand = product['brand'] as String?;
        if (productBrand == null || !brands.contains(productBrand)) {
          return false;
        }
      }

      // Category filter
      if (categories.isNotEmpty) {
        final productCategory = product['category'] as String?;
        if (productCategory == null || !categories.contains(productCategory)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      switch (sortBy) {
        case 'price_low':
          return ((a['price'] ?? 0).toDouble())
              .compareTo((b['price'] ?? 0).toDouble());
        case 'price_high':
          return ((b['price'] ?? 0).toDouble())
              .compareTo((a['price'] ?? 0).toDouble());
        case 'newest':
          final aTime = a['created_at'] as DateTime?;
          final bTime = b['created_at'] as DateTime?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        case 'popularity':
        default:
          // Assume products are already sorted by popularity from Firestore
          return 0;
      }
    });

    return filtered;
  }

  @override
  String toString() {
    return 'ProductFilter(minPrice: $minPrice, maxPrice: $maxPrice, '
        'brands: $brands, categories: $categories, sortBy: $sortBy)';
  }
}
