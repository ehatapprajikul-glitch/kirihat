import 'package:cloud_firestore/cloud_firestore.dart';

class ProductDraft {
  final String id;
  final String sellerId;
  final String draftTitle; // Auto-generated from product name or "Untitled Draft"
  final Map<String, dynamic> draftData;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductDraft({
    required this.id,
    required this.sellerId,
    required this.draftTitle,
    required this.draftData,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductDraft.fromMap(Map<String, dynamic> map, String id) {
    return ProductDraft(
      id: id,
      sellerId: map['seller_id'] ?? '',
      draftTitle: map['draft_title'] ?? 'Untitled Draft',
      draftData: Map<String, dynamic>.from(map['draft_data'] ?? {}),
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seller_id': sellerId,
      'draft_title': draftTitle,
      'draft_data': draftData,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
}
