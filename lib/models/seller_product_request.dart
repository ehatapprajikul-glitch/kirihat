import 'package:cloud_firestore/cloud_firestore.dart';

class SellerProductRequest {
  final String id;
  final String sellerId;
  final Map<String, dynamic> productData;
  final String status; // pending, approved, rejected, revision_needed
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? adminNotes;
  final int revisionCount;

  SellerProductRequest({
    required this.id,
    required this.sellerId,
    required this.productData,
    this.status = 'pending',
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.adminNotes,
    this.revisionCount = 0,
  });

  factory SellerProductRequest.fromMap(Map<String, dynamic> map, String id) {
    return SellerProductRequest(
      id: id,
      sellerId: map['seller_id'] ?? '',
      productData: Map<String, dynamic>.from(map['product_data'] ?? {}),
      status: map['status'] ?? 'pending',
      submittedAt: (map['submitted_at'] as Timestamp).toDate(),
      reviewedAt: map['reviewed_at'] != null
          ? (map['reviewed_at'] as Timestamp).toDate()
          : null,
      reviewedBy: map['reviewed_by'],
      adminNotes: map['admin_notes'],
      revisionCount: map['revision_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seller_id': sellerId,
      'product_data': productData,
      'status': status,
      'submitted_at': Timestamp.fromDate(submittedAt),
      'reviewed_at': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewed_by': reviewedBy,
      'admin_notes': adminNotes,
      'revision_count': revisionCount,
    };
  }
}
