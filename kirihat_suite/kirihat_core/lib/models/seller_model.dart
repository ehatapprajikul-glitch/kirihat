import 'package:cloud_firestore/cloud_firestore.dart';

class SellerModel {
  final String id;
  final String userId;
  final String businessName;
  final String ownerName;
  final String email;
  final String phone;

  // Location
  final String pincode;
  final String address;
  final String city;
  final String state;
  final List<String> serviceablePincodes;

  // Business Info
  final String? gstNumber;
  final String? panNumber;
  final String? aadharNumber;
  final String? udhyamNumber;
  final String? fssaiLicense;
  final BankAccount? bankAccount;
  final Map<String, String>? documents; // {'aadhar': 'url', 'pan': 'url', 'udhyam': 'url'}

  // Status
  final String status; // pending, active, suspended, rejected
  final bool verified;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  // Stats
  final int totalProducts;
  final int activeProducts;
  final double totalSales;
  final double rating;

  SellerModel({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.pincode,
    required this.address,
    required this.city,
    required this.state,
    this.serviceablePincodes = const [],
    this.gstNumber,
    this.panNumber,
    this.aadharNumber,
    this.udhyamNumber,
    this.fssaiLicense,
    this.bankAccount,
    this.documents,
    this.status = 'pending',
    this.verified = false,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.totalProducts = 0,
    this.activeProducts = 0,
    this.totalSales = 0.0,
    this.rating = 0.0,
  });

  factory SellerModel.fromMap(Map<String, dynamic> map, String id) {
    return SellerModel(
      id: id,
      userId: map['user_id'] ?? '',
      businessName: map['business_name'] ?? '',
      ownerName: map['owner_name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      pincode: map['pincode'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      serviceablePincodes: List<String>.from(map['serviceable_pincodes'] ?? []),
      gstNumber: map['gst_number'],
      panNumber: map['pan_number'],
      aadharNumber: map['aadhar_number'],
      udhyamNumber: map['udhyam_number'],
      fssaiLicense: map['fssai_license'],
      bankAccount: map['bank_account'] != null
          ? BankAccount.fromMap(map['bank_account'])
          : null,
      documents: map['documents'] != null ? Map<String, String>.from(map['documents']) : {},
      status: map['status'] ?? 'pending',
      verified: map['verified'] ?? false,
      createdAt: (map['created_at'] as Timestamp).toDate(),
      approvedAt: map['approved_at'] != null
          ? (map['approved_at'] as Timestamp).toDate()
          : null,
      approvedBy: map['approved_by'],
      totalProducts: map['total_products'] ?? 0,
      activeProducts: map['active_products'] ?? 0,
      totalSales: (map['total_sales'] ?? 0).toDouble(),
      rating: (map['rating'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'business_name': businessName,
      'owner_name': ownerName,
      'email': email,
      'phone': phone,
      'pincode': pincode,
      'address': address,
      'city': city,
      'state': state,
      'serviceable_pincodes': serviceablePincodes,
      'gst_number': gstNumber,
      'pan_number': panNumber,
      'aadhar_number': aadharNumber,
      'udhyam_number': udhyamNumber,
      'fssai_license': fssaiLicense,
       'bank_account': bankAccount?.toMap(),
      'documents': documents,
      'status': status,
      'verified': verified,
      'created_at': Timestamp.fromDate(createdAt),
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approved_by': approvedBy,
      'total_products': totalProducts,
      'active_products': activeProducts,
      'total_sales': totalSales,
      'rating': rating,
    };
  }

  SellerModel copyWith({
    String? businessName,
    String? ownerName,
    String? email,
    String? phone,
    String? pincode,
    String? address,
    String? city,
    String? state,
    List<String>? serviceablePincodes,
    String? gstNumber,
    String? panNumber,
    String? aadharNumber,
    String? udhyamNumber,
    String? fssaiLicense,
    BankAccount? bankAccount,
    Map<String, String>? documents,
    String? status,
    bool? verified,
    DateTime? approvedAt,
    String? approvedBy,
    int? totalProducts,
    int? activeProducts,
    double? totalSales,
    double? rating,
  }) {
    return SellerModel(
      id: id,
      userId: userId,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      pincode: pincode ?? this.pincode,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      serviceablePincodes: serviceablePincodes ?? this.serviceablePincodes,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      aadharNumber: aadharNumber ?? this.aadharNumber,
      udhyamNumber: udhyamNumber ?? this.udhyamNumber,
      fssaiLicense: fssaiLicense ?? this.fssaiLicense,
      bankAccount: bankAccount ?? this.bankAccount,
      documents: documents ?? this.documents,
      status: status ?? this.status,
      verified: verified ?? this.verified,
      createdAt: createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      totalProducts: totalProducts ?? this.totalProducts,
      activeProducts: activeProducts ?? this.activeProducts,
      totalSales: totalSales ?? this.totalSales,
      rating: rating ?? this.rating,
    );
  }
}

class BankAccount {
  final String accountNumber;
  final String ifsc;
  final String accountHolder;

  BankAccount({
    required this.accountNumber,
    required this.ifsc,
    required this.accountHolder,
  });

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      accountNumber: map['account_number'] ?? '',
      ifsc: map['ifsc'] ?? '',
      accountHolder: map['account_holder'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'account_number': accountNumber,
      'ifsc': ifsc,
      'account_holder': accountHolder,
    };
  }
}
