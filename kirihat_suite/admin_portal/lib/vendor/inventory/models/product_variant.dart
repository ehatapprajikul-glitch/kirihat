/// Model class representing a product variant
class ProductVariant {
  final String variantId;
  final Map<String, String> attributes; // e.g., {'size': '500ml', 'color': 'red'}
  final double price;
  final int stockQuantity;
  final String sku;
  final String? imageUrl;

  const ProductVariant({
    required this.variantId,
    required this.attributes,
    required this.price,
    required this.stockQuantity,
    required this.sku,
    this.imageUrl,
  });

  /// Convert variant to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'variant_id': variantId,
      'attributes': attributes,
      'price': price,
      'stock_quantity': stockQuantity,
      'sku': sku,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  /// Create variant from Firestore map
  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      variantId: map['variant_id'] ?? '',
      attributes: Map<String, String>.from(map['attributes'] ?? {}),
      price: (map['price'] ?? 0).toDouble(),
      stockQuantity: map['stock_quantity'] ?? 0,
      sku: map['sku'] ?? '',
      imageUrl: map['image_url'],
    );
  }

  /// Create a copy with modified fields
  ProductVariant copyWith({
    String? variantId,
    Map<String, String>? attributes,
    double? price,
    int? stockQuantity,
    String? sku,
    String? imageUrl,
  }) {
    return ProductVariant(
      variantId: variantId ?? this.variantId,
      attributes: attributes ?? this.attributes,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Get a human-readable variant name
  String get displayName {
    return attributes.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
  }

  /// Check if variant is in stock
  bool get isInStock => stockQuantity > 0;

  /// Check if variant is low on stock
  bool get isLowStock => stockQuantity > 0 && stockQuantity < 5;

  /// Check if variant is out of stock
  bool get isOutOfStock => stockQuantity == 0;
}
