import 'package:cloud_firestore/cloud_firestore.dart';

class RiderModel {
  final String id;
  final String vendorId;
  final String name;
  final String phone;
  final String email;
  final String status; // Active, Inactive
  final String dutyStatus; // online, busy, offline
  final String? vehicleType;
  final String? vehicleNumber;
  final String? licenseNumber;
  final String? photoUrl;
  final DateTime joinedDate;
  final int totalDeliveries;
  final double rating;
  final bool isOnline; // Legacy - switching to dutyStatus
  final DateTime? lastActive;

  RiderModel({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.phone,
    required this.email,
    required this.status,
    required this.dutyStatus,
    this.vehicleType,
    this.vehicleNumber,
    this.licenseNumber,
    this.photoUrl,
    required this.joinedDate,
    required this.totalDeliveries,
    required this.rating,
    required this.isOnline,
    this.lastActive,
  });

  factory RiderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RiderModel(
      id: doc.id,
      vendorId: data['vendor_id'] ?? '',
      name: data['name'] ?? 'Unknown',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      status: data['status'] ?? 'Active',
      dutyStatus: data['duty_status'] ?? 'offline',
      vehicleType: data['vehicle_type'],
      vehicleNumber: data['vehicle_number'],
      licenseNumber: data['license_number'],
      photoUrl: data['photo_url'],
      joinedDate: (data['joined_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalDeliveries: data['total_deliveries'] ?? 0,
      rating: (data['rating'] ?? 0).toDouble(),
      isOnline: data['is_online'] ?? false,
      lastActive: (data['last_active'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendor_id': vendorId,
      'name': name,
      'phone': phone,
      'email': email,
      'status': status,
      'duty_status': dutyStatus,
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'license_number': licenseNumber,
      'photo_url': photoUrl,
      'joined_date': Timestamp.fromDate(joinedDate),
      'total_deliveries': totalDeliveries,
      'rating': rating,
      'is_online': isOnline,
      'last_active': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
    };
  }

  // Helper getters
  bool get isActive => status == 'Active';
  bool get isBusy => dutyStatus == 'busy';
  bool get isAvailable => isActive && dutyStatus == 'online';
}
