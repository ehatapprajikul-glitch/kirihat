class CollectionModel {
  final String id;
  final String name;
  final List<String> productIds; // Master Product IDs
  final String? icon;
  final bool isActive;
  final int sortOrder;

  CollectionModel({
    required this.id,
    required this.name,
    required this.productIds,
    this.icon,
    this.isActive = true,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'product_ids': productIds,
      'icon': icon,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  factory CollectionModel.fromMap(Map<String, dynamic> map, String docId) {
    return CollectionModel(
      id: docId,
      name: map['name'] ?? '',
      productIds: List<String>.from(map['product_ids'] ?? []),
      icon: map['icon'],
      isActive: map['is_active'] ?? true,
      sortOrder: map['sort_order'] ?? 0,
    );
  }
}
