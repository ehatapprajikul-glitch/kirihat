import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentItem {
  final String productId;
  final String productName;
  final int quantity;
  final String productUnit;

  ShipmentItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.productUnit,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'product_unit': productUnit,
    };
  }

  factory ShipmentItem.fromMap(Map<String, dynamic> map) {
    return ShipmentItem(
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      quantity: map['quantity'] ?? 0,
      productUnit: map['product_unit'] ?? '',
    );
  }
}

class ShipmentModel {
  final String id;
  final String sellerId;
  final String warehouseId;
  final String warehouseName;
  final String status; // 'pending', 'shipped', 'received', 'cancelled'
  final List<ShipmentItem> items;
  final DateTime createdAt;
  final DateTime? shippedAt;
  final DateTime? receivedAt;

  ShipmentModel({
    required this.id,
    required this.sellerId,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.items,
    required this.createdAt,
    this.shippedAt,
    this.receivedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'seller_id': sellerId,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'status': status,
      'items': items.map((x) => x.toMap()).toList(),
      'created_at': Timestamp.fromDate(createdAt),
      'shipped_at': shippedAt != null ? Timestamp.fromDate(shippedAt!) : null,
      'received_at': receivedAt != null ? Timestamp.fromDate(receivedAt!) : null,
    };
  }

  factory ShipmentModel.fromMap(Map<String, dynamic> map, String id) {
    return ShipmentModel(
      id: id,
      sellerId: map['seller_id'] ?? '',
      warehouseId: map['warehouse_id'] ?? '',
      warehouseName: map['warehouse_name'] ?? '',
      status: map['status'] ?? 'pending',
      items: List<ShipmentItem>.from(
        (map['items'] as List<dynamic>? ?? []).map<ShipmentItem>(
          (x) => ShipmentItem.fromMap(x as Map<String, dynamic>),
        ),
      ),
      createdAt: (map['created_at'] as Timestamp).toDate(),
      shippedAt: map['shipped_at'] != null ? (map['shipped_at'] as Timestamp).toDate() : null,
      receivedAt: map['received_at'] != null ? (map['received_at'] as Timestamp).toDate() : null,
    );
  }
}
