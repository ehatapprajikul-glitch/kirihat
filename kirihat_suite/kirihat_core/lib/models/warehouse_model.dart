import 'package:cloud_firestore/cloud_firestore.dart';

class WarehouseModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final int capacity;
  final bool active;

  WarehouseModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.capacity,
    required this.active,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'capacity': capacity,
      'active': active,
    };
  }

  factory WarehouseModel.fromMap(Map<String, dynamic> map, String id) {
    return WarehouseModel(
      id: id,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      capacity: map['capacity'] ?? 0,
      active: map['active'] ?? false,
    );
  }
}

class WarehouseStockModel {
  final String productId;
  final String productName;
  final int quantity;
  final int minStockLevel; // Alert threshold
  final int maxStockLevel; // Max capacity
  final DateTime lastUpdated;
  final String? lastShipmentId;

  WarehouseStockModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.minStockLevel = 10,
    this.maxStockLevel = 1000,
    required this.lastUpdated,
    this.lastShipmentId,
  });

  factory WarehouseStockModel.fromMap(Map<String, dynamic> data) {
    return WarehouseStockModel(
      productId: data['product_id'] ?? '',
      productName: data['product_name'] ?? '',
      quantity: data['quantity'] ?? 0,
      minStockLevel: data['min_stock_level'] ?? 10,
      maxStockLevel: data['max_stock_level'] ?? 1000,
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastShipmentId: data['last_shipment_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'min_stock_level': minStockLevel,
      'max_stock_level': maxStockLevel,
      'last_updated': Timestamp.fromDate(lastUpdated),
      'last_shipment_id': lastShipmentId,
    };
  }

  bool get isLowStock => quantity <= minStockLevel;
  bool get isOverStock => quantity >= maxStockLevel;
}

class VendorStockRequest {
  final String id;
  final String vendorId;
  final String vendorName;
  final String productId;
  final String productName;
  final int requestedQuantity;
  final int approvedQuantity;
  final String status; // pending, approved, preparing, shipped, received, rejected
  final String? notes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? shippedAt;
  final DateTime? receivedAt;

  VendorStockRequest({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    this.approvedQuantity = 0,
    required this.status,
    this.notes,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.shippedAt,
    this.receivedAt,
  });

  factory VendorStockRequest.fromMap(Map<String, dynamic> data, String documentId) {
    return VendorStockRequest(
      id: documentId,
      vendorId: data['vendor_id'] ?? '',
      vendorName: data['vendor_name'] ?? '',
      productId: data['product_id'] ?? '',
      productName: data['product_name'] ?? '',
      requestedQuantity: data['requested_quantity'] ?? 0,
      approvedQuantity: data['approved_quantity'] ?? 0,
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      rejectionReason: data['rejection_reason'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedBy: data['approved_by'],
      approvedAt: (data['approved_at'] as Timestamp?)?.toDate(),
      shippedAt: (data['shipped_at'] as Timestamp?)?.toDate(),
      receivedAt: (data['received_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'product_id': productId,
      'product_name': productName,
      'requested_quantity': requestedQuantity,
      'approved_quantity': approvedQuantity,
      'status': status,
      'notes': notes,
      'rejection_reason': rejectionReason,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'approved_by': approvedBy,
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'shipped_at': shippedAt != null ? Timestamp.fromDate(shippedAt!) : null,
      'received_at': receivedAt != null ? Timestamp.fromDate(receivedAt!) : null,
    };
  }
}
