import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class representing inventory filter and sort criteria
class InventoryFilter {
  final String? stockStatus; // 'all', 'in_stock', 'low_stock', 'out_of_stock'
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final DateTime? startDate;
  final DateTime? endDate;
  final String sortBy; // 'name', 'price', 'stock', 'date'
  final bool sortAscending;

  const InventoryFilter({
    this.stockStatus = 'all',
    this.category,
    this.minPrice,
    this.maxPrice,
    this.startDate,
    this.endDate,
    this.sortBy = 'date',
    this.sortAscending = false,
  });

  /// Default filter with no restrictions
  factory InventoryFilter.defaults() {
    return const InventoryFilter();
  }

  /// Create a copy with modified fields
  InventoryFilter copyWith({
    String? stockStatus,
    String? category,
    double? minPrice,
    double? maxPrice,
    DateTime? startDate,
    DateTime? endDate,
    String? sortBy,
    bool? sortAscending,
  }) {
    return InventoryFilter(
      stockStatus: stockStatus ?? this.stockStatus,
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// Apply filter to a list of documents (for client-side filtering)
  List<DocumentSnapshot> applyToList(List<DocumentSnapshot> docs) {
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Stock status filter
      if (stockStatus != null && stockStatus != 'all') {
        final stock = data['stock_quantity'] ?? 0;
        switch (stockStatus) {
          case 'in_stock':
            if (stock <= 0) return false;
            break;
          case 'low_stock':
            if (stock == 0 || stock >= 5) return false;
            break;
          case 'out_of_stock':
            if (stock > 0) return false;
            break;
        }
      }

      // Category filter
      if (category != null && category!.isNotEmpty) {
        final prodCategory = (data['category'] ?? '').toString().toLowerCase();
        if (prodCategory != category!.toLowerCase()) return false;
      }

      // Price range filter
      if (minPrice != null) {
        final price = (data['price'] ?? 0).toDouble();
        if (price < minPrice!) return false;
      }
      if (maxPrice != null) {
        final price = (data['price'] ?? 0).toDouble();
        if (price > maxPrice!) return false;
      }

      // Date range filter
      if (startDate != null && data['created_at'] != null) {
        final createdAt = (data['created_at'] as Timestamp).toDate();
        if (createdAt.isBefore(startDate!)) return false;
      }
      if (endDate != null && data['created_at'] != null) {
        final createdAt = (data['created_at'] as Timestamp).toDate();
        if (createdAt.isAfter(endDate!)) return false;
      }

      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      int comparison = 0;
      switch (sortBy) {
        case 'name':
          comparison = (aData['name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((bData['name'] ?? '').toString().toLowerCase());
          break;
        case 'price':
          comparison = ((aData['price'] ?? 0).toDouble())
              .compareTo((bData['price'] ?? 0).toDouble());
          break;
        case 'stock':
          comparison = (aData['stock_quantity'] ?? 0)
              .compareTo(bData['stock_quantity'] ?? 0);
          break;
        case 'date':
          if (aData['created_at'] != null && bData['created_at'] != null) {
            comparison = (aData['created_at'] as Timestamp)
                .toDate()
                .compareTo((bData['created_at'] as Timestamp).toDate());
          }
          break;
      }

      return sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  /// Check if any filters are active (not default)
  bool get hasActiveFilters {
    return stockStatus != 'all' ||
        category != null ||
        minPrice != null ||
        maxPrice != null ||
        startDate != null ||
        endDate != null;
  }

  /// Get a human-readable description of active filters
  String getFilterDescription() {
    final parts = <String>[];
    
    if (stockStatus != null && stockStatus != 'all') {
      parts.add(stockStatus!.replaceAll('_', ' ').toUpperCase());
    }
    if (category != null) {
      parts.add('Category: $category');
    }
    if (minPrice != null || maxPrice != null) {
      if (minPrice != null && maxPrice != null) {
        parts.add('₹$minPrice - ₹$maxPrice');
      } else if (minPrice != null) {
        parts.add('Min: ₹$minPrice');
      } else {
        parts.add('Max: ₹$maxPrice');
      }
    }
    
    return parts.isEmpty ? 'All Products' : parts.join(' • ');
  }
}
