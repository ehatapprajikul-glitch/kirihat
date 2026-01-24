import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String orderId;
  final String vendorId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final double totalAmount;
  final String status; // Pending, Processing, Packed, Shipped, Delivered, Cancelled
  final String paymentMethod; // COD, Online, Card, UPI
  final String paymentStatus; // Pending, Paid, Failed
  final String deliveryMode; // Standard, Express
  final DeliveryAddress deliveryAddress;
  final DateTime createdAt;
  final DateTime? shippedAt;
  final DateTime? outForDeliveryAt;
  final DateTime? deliveredAt;
  final DateTime? acceptedAt;
  final DateTime? packedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final String? deliveryPin;
  final String? notes;
  final String? cancellationReason;

  OrderModel({
    required this.id,
    required this.orderId,
    required this.vendorId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryMode,
    required this.deliveryAddress,
    required this.createdAt,
    this.shippedAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.acceptedAt,
    this.packedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.deliveryPin,
    this.notes,
    this.cancellationReason,
    // New fields for enhanced shipping label
    this.vendorName,
    this.vendorAddress,
    this.vendorPhone,
    this.vendorEmail,
    this.priority,
  });

  // Additional fields definition
  final String? vendorName;
  final String? vendorAddress;
  final String? vendorPhone;
  final String? vendorEmail;
  final String? priority; // "Standard", "Express", "Urgent"

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return OrderModel(
      id: doc.id,
      orderId: data['order_id'] ?? doc.id.substring(0, 8).toUpperCase(),
      vendorId: data['vendor_id'] ?? '',
      customerId: data['customer_id'] ?? '',
      customerName: data['customer_name'] ?? 
                    (data['delivery_address']?['name'] ?? 'Customer'),
      customerPhone: data['customer_phone'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item))
              .toList() ??
          [],
      totalAmount: (data['total_amount'] ?? 0).toDouble(),
      status: data['status'] ?? 'Pending',
      paymentMethod: data['payment_method'] ?? 'COD',
      paymentStatus: data['payment_status'] ?? 'Pending',
      deliveryMode: data['delivery_mode'] ?? 'Standard',
      deliveryAddress: DeliveryAddress.fromMap(data['delivery_address'] ?? {}),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shippedAt: (data['shipped_at'] as Timestamp?)?.toDate(),
      outForDeliveryAt: (data['out_for_delivery_at'] as Timestamp?)?.toDate(),
      deliveredAt: (data['delivered_at'] as Timestamp?)?.toDate(),
      acceptedAt: (data['accepted_at'] as Timestamp?)?.toDate(),
      packedAt: (data['packed_at'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelled_at'] as Timestamp?)?.toDate(),
      cancelledBy: data['cancelled_by'],
      riderId: data['rider_id'],
      riderName: data['rider_name'],
      riderPhone: data['rider_phone'],
      deliveryPin: data['delivery_pin'],
      notes: data['notes'],
      cancellationReason: data['cancellation_reason'],
      vendorName: data['vendorName'],
      vendorAddress: data['vendorAddress'],
      vendorPhone: data['vendorPhone'],
      vendorEmail: data['vendorEmail'],
      priority: data['priority'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'vendor_id': vendorId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'items': items.map((item) => item.toMap()).toList(),
      'total_amount': totalAmount,
      'status': status,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'delivery_mode': deliveryMode,
      'delivery_address': deliveryAddress.toMap(),
      'created_at': Timestamp.fromDate(createdAt),
      'shipped_at': shippedAt != null ? Timestamp.fromDate(shippedAt!) : null,
      'out_for_delivery_at': outForDeliveryAt != null ? Timestamp.fromDate(outForDeliveryAt!) : null,
      'delivered_at': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'accepted_at': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'packed_at': packedAt != null ? Timestamp.fromDate(packedAt!) : null,
      'cancelled_at': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancelled_by': cancelledBy,
      'rider_id': riderId,
      'rider_name': riderName,
      'rider_phone': riderPhone,
      'delivery_pin': deliveryPin,
      'notes': notes,
      'cancellation_reason': cancellationReason,
      'vendorName': vendorName,
      'vendorAddress': vendorAddress,
      'vendorPhone': vendorPhone,
      'vendorEmail': vendorEmail,
      'priority': priority,
    };
  }

  // Helper methods
  bool get isPending => status == 'Pending';
  bool get isProcessing => status == 'Processing';
  bool get isPacked => status == 'Packed';
  bool get isShipped => status == 'Shipped';
  bool get isDelivered => status == 'Delivered';
  bool get isCancelled => status == 'Cancelled';
  bool get isCompleted => status == 'Completed' || status == 'Delivered';
  
  bool get isCOD => paymentMethod == 'COD';
  bool get isExpress => deliveryMode == 'Express';
  
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  OrderModel copyWith({
    String? id,
    String? orderId,
    String? vendorId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    List<OrderItem>? items,
    double? totalAmount,
    String? status,
    String? paymentMethod,
    String? paymentStatus,
    String? deliveryMode,
    DeliveryAddress? deliveryAddress,
    DateTime? createdAt,
    DateTime? shippedAt,
    DateTime? outForDeliveryAt,
    DateTime? deliveredAt,
    DateTime? acceptedAt,
    DateTime? packedAt,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? riderId,
    String? riderName,
    String? riderPhone,
    String? deliveryPin,
    String? notes,
    String? cancellationReason,
    String? vendorName,
    String? vendorAddress,
    String? vendorPhone,
    String? vendorEmail,
    String? priority,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      vendorId: vendorId ?? this.vendorId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      createdAt: createdAt ?? this.createdAt,
      shippedAt: shippedAt ?? this.shippedAt,
      outForDeliveryAt: outForDeliveryAt ?? this.outForDeliveryAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      packedAt: packedAt ?? this.packedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      deliveryPin: deliveryPin ?? this.deliveryPin,
      notes: notes ?? this.notes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      vendorName: vendorName ?? this.vendorName,
      vendorAddress: vendorAddress ?? this.vendorAddress,
      vendorPhone: vendorPhone ?? this.vendorPhone,
      vendorEmail: vendorEmail ?? this.vendorEmail,
      priority: priority ?? this.priority,
    );
  }
}

class OrderItem {
  final String productId;
  final String name;
  final String imageUrl;
  final int quantity;
  final double price;
  final double total;
  final String? unit;
  final String? variant;
  final String? barcode;
  final String? sku;

  OrderItem({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.quantity,
    required this.price,
    required this.total,
    this.unit,
    this.variant,
    this.barcode,
    this.sku,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? 'Unknown',
      imageUrl: map['imageUrl'] ?? '',
      quantity: map['quantity'] ?? 1,
      price: (map['price'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      unit: map['unit'],
      variant: map['variant'],
      barcode: map['barcode'],
      sku: map['sku'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'price': price,
      'total': total,
      'unit': unit,
      'variant': variant,
      'barcode': barcode,
      'sku': sku,
    };
  }
}

class DeliveryAddress {
  final String name;
  final String phone;
  final String houseNo;
  final String street;
  final String city;
  final String state;
  final String pincode;
  final String? landmark;
  final String? district;
  final String? serviceArea;
  final String? nearbyMarket;
  final double? latitude;
  final double? longitude;

  DeliveryAddress({
    required this.name,
    required this.phone,
    required this.houseNo,
    required this.street,
    required this.city,
    required this.state,
    required this.pincode,
    this.landmark,
    this.district,
    this.serviceArea,
    this.nearbyMarket,
    this.latitude,
    this.longitude,
  });

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) {
    return DeliveryAddress(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      houseNo: map['house_no'] ?? '',
      street: map['street'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      landmark: map['landmark'],
      district: map['district'],
      serviceArea: map['service_area'],
      nearbyMarket: map['nearby_market'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'house_no': houseNo,
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      'landmark': landmark,
      'district': district,
      'service_area': serviceArea,
      'nearby_market': nearbyMarket,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  String get fullAddress {
    final parts = [
      if (houseNo.isNotEmpty) 'No. $houseNo',
      if (landmark != null && landmark!.isNotEmpty) 'Landmark: $landmark',
      if (nearbyMarket != null && nearbyMarket!.isNotEmpty) 'Market: $nearbyMarket',
      if (serviceArea != null && serviceArea!.isNotEmpty) serviceArea,
      if (street.isNotEmpty) street,
      if (city.isNotEmpty) city,
      if (district != null && district!.isNotEmpty) district,
      state,
      pincode,
    ];
    return parts.where((s) => s != null && s.isNotEmpty).join(', ');
  }
}
