class BannerModel {
  final String id;
  final String imageUrl;
  final String hyperlinkType; // 'category', 'product', 'external', 'none'
  final String hyperlinkValue; // category_id, product_id, or URL
  final int position;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BannerModel({
    required this.id,
    required this.imageUrl,
    required this.hyperlinkType,
    required this.hyperlinkValue,
    required this.position,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory BannerModel.fromFirestore(String id, Map<String, dynamic> data) {
    return BannerModel(
      id: id,
      imageUrl: data['image_url'] ?? '',
      hyperlinkType: data['hyperlink_type'] ?? 'none',
      hyperlinkValue: data['hyperlink_value'] ?? '',
      position: data['position'] ?? 0,
      isActive: data['is_active'] ?? true,
      createdAt: data['created_at']?.toDate(),
      updatedAt: data['updated_at']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'image_url': imageUrl,
      'hyperlink_type': hyperlinkType,
      'hyperlink_value': hyperlinkValue,
      'position': position,
      'is_active': isActive,
      'updated_at': DateTime.now(),
    };
  }
}
