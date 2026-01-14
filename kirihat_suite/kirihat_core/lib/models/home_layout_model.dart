import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum representing different types of home screen layouts
enum LayoutType {
  banner,
  categoryGrid,
  productRow,
  heroSection,
  searchSection,
  custom,
}

/// Model representing a home screen layout configuration
class LayoutModel {
  final String id;
  final LayoutType type;
  final int position;
  final String title;
  final bool active;
  final String? vendorId; // null = admin global, non-null = vendor-specific
  final Map<String, dynamic> data;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LayoutModel({
    required this.id,
    required this.type,
    required this.position,
    this.title = '',
    this.active = true,
    this.vendorId,
    required this.data,
    this.createdAt,
    this.updatedAt,
  });

  /// Create LayoutModel from Firestore document
  factory LayoutModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LayoutModel(
      id: doc.id,
      type: _parseLayoutType(data['type']),
      position: data['position'] ?? 0,
      title: data['title'] ?? '',
      active: data['active'] ?? true,
      vendorId: data['vendor_id'],
      data: data['data'] ?? {},
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert LayoutModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'position': position,
      'title': title,
      'active': active,
      'vendor_id': vendorId,
      'data': data,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy of this model with updated fields
  LayoutModel copyWith({
    String? id,
    LayoutType? type,
    int? position,
    String? title,
    bool? active,
    String? vendorId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LayoutModel(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      title: title ?? this.title,
      active: active ?? this.active,
      vendorId: vendorId ?? this.vendorId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Parse string to LayoutType enum
  static LayoutType _parseLayoutType(String? type) {
    switch (type) {
      case 'banner':
        return LayoutType.banner;
      case 'categoryGrid':
        return LayoutType.categoryGrid;
      case 'productRow':
        return LayoutType.productRow;
      case 'heroSection':
        return LayoutType.heroSection;
      case 'searchSection':
        return LayoutType.searchSection;
      default:
        return LayoutType.custom;
    }
  }

  @override
  String toString() {
    return 'LayoutModel(id: $id, type: ${type.name}, position: $position, title: $title, active: $active)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LayoutModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
