import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing all platform fee configurations
/// Allows admin to customize fees dynamically instead of hardcoded values
class FeeConfigurationModel {
  final String id;
  
  // Commission & Platform Fees
  final double platformFeePercentage; // Seller commission (e.g., 10%)
  
  // Delivery Fees
  final double deliveryFeeDefault; // Standard delivery
  final double rushDeliveryFee; // Express/Rush delivery
  final double freeDeliveryThreshold; // Minimum order value for free delivery
  
  // Return & Refund Fees
  final double returnProcessingFee; // Fee for processing returns
  final double restockingFeePercentage; // % charged on returned items
  
  // Payment Gateway Fees
  final double paymentGatewayFeePercentage; // Payment processor %
  final double paymentGatewayFixedFee; // Fixed fee per transaction
  
  // Other Fees
  final double cancellationFee; // Fee for order cancellation
  final double packagingFee; // Additional packaging fee
  
  // Metadata
  final DateTime lastUpdatedAt;
  final String? lastUpdatedBy;
  final bool isActive;

  FeeConfigurationModel({
    required this.id,
    this.platformFeePercentage = 10.0,
    this.deliveryFeeDefault = 40.0,
    this.rushDeliveryFee = 80.0,
    this.freeDeliveryThreshold = 500.0,
    this.returnProcessingFee = 50.0,
    this.restockingFeePercentage = 5.0,
    this.paymentGatewayFeePercentage = 2.0,
    this.paymentGatewayFixedFee = 2.0,
    this.cancellationFee = 0.0,
    this.packagingFee = 0.0,
    required this.lastUpdatedAt,
    this.lastUpdatedBy,
    this.isActive = true,
  });

  /// Create from Firestore document
  factory FeeConfigurationModel.fromMap(Map<String, dynamic> map, String id) {
    return FeeConfigurationModel(
      id: id,
      platformFeePercentage: ((map['platform_fee_percentage'] ?? 10.0) as num).toDouble(),
      deliveryFeeDefault: ((map['delivery_fee_default'] ?? 40.0) as num).toDouble(),
      rushDeliveryFee: ((map['rush_delivery_fee'] ?? 80.0) as num).toDouble(),
      freeDeliveryThreshold: ((map['free_delivery_threshold'] ?? 500.0) as num).toDouble(),
      returnProcessingFee: ((map['return_processing_fee'] ?? 50.0) as num).toDouble(),
      restockingFeePercentage: ((map['restocking_fee_percentage'] ?? 5.0) as num).toDouble(),
      paymentGatewayFeePercentage: ((map['payment_gateway_fee_percentage'] ?? 2.0) as num).toDouble(),
      paymentGatewayFixedFee: ((map['payment_gateway_fixed_fee'] ?? 2.0) as num).toDouble(),
      cancellationFee: ((map['cancellation_fee'] ?? 0.0) as num).toDouble(),
      packagingFee: ((map['packaging_fee'] ?? 0.0) as num).toDouble(),
      lastUpdatedAt: (map['last_updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdatedBy: map['last_updated_by'],
      isActive: map['is_active'] ?? true,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'platform_fee_percentage': platformFeePercentage,
      'delivery_fee_default': deliveryFeeDefault,
      'rush_delivery_fee': rushDeliveryFee,
      'free_delivery_threshold': freeDeliveryThreshold,
      'return_processing_fee': returnProcessingFee,
      'restocking_fee_percentage': restockingFeePercentage,
      'payment_gateway_fee_percentage': paymentGatewayFeePercentage,
      'payment_gateway_fixed_fee': paymentGatewayFixedFee,
      'cancellation_fee': cancellationFee,
      'packaging_fee': packagingFee,
      'last_updated_at': FieldValue.serverTimestamp(),
      'last_updated_by': lastUpdatedBy,
      'is_active': isActive,
    };
  }

  /// Create a copy with updated fields
  FeeConfigurationModel copyWith({
    String? id,
    double? platformFeePercentage,
    double? deliveryFeeDefault,
    double? rushDeliveryFee,
    double? freeDeliveryThreshold,
    double? returnProcessingFee,
    double? restockingFeePercentage,
    double? paymentGatewayFeePercentage,
    double? paymentGatewayFixedFee,
    double? cancellationFee,
    double? packagingFee,
    DateTime? lastUpdatedAt,
    String? lastUpdatedBy,
    bool? isActive,
  }) {
    return FeeConfigurationModel(
      id: id ?? this.id,
      platformFeePercentage: platformFeePercentage ?? this.platformFeePercentage,
      deliveryFeeDefault: deliveryFeeDefault ?? this.deliveryFeeDefault,
      rushDeliveryFee: rushDeliveryFee ?? this.rushDeliveryFee,
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      returnProcessingFee: returnProcessingFee ?? this.returnProcessingFee,
      restockingFeePercentage: restockingFeePercentage ?? this.restockingFeePercentage,
      paymentGatewayFeePercentage: paymentGatewayFeePercentage ?? this.paymentGatewayFeePercentage,
      paymentGatewayFixedFee: paymentGatewayFixedFee ?? this.paymentGatewayFixedFee,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      packagingFee: packagingFee ?? this.packagingFee,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Default fee configuration
  factory FeeConfigurationModel.defaultConfig() {
    return FeeConfigurationModel(
      id: 'default',
      platformFeePercentage: 10.0,
      deliveryFeeDefault: 40.0,
      rushDeliveryFee: 80.0,
      freeDeliveryThreshold: 500.0,
      returnProcessingFee: 50.0,
      restockingFeePercentage: 5.0,
      paymentGatewayFeePercentage: 2.0,
      paymentGatewayFixedFee: 2.0,
      cancellationFee: 0.0,
      packagingFee: 0.0,
      lastUpdatedAt: DateTime.now(),
      isActive: true,
    );
  }

  /// Calculate platform fee for a given amount
  double calculatePlatformFee(double amount) {
    return amount * (platformFeePercentage / 100);
  }

  /// Calculate payment gateway fee for a given amount
  double calculatePaymentGatewayFee(double amount) {
    return (amount * (paymentGatewayFeePercentage / 100)) + paymentGatewayFixedFee;
  }

  /// Calculate restocking fee for returned amount
  double calculateRestockingFee(double amount) {
    return amount * (restockingFeePercentage / 100);
  }

  /// Determine delivery fee based on order value and delivery type
  double getDeliveryFee({
    required double orderValue,
    bool isRushDelivery = false,
  }) {
    // Free delivery if order value exceeds threshold
    if (orderValue >= freeDeliveryThreshold) {
      return 0.0;
    }
    
    return isRushDelivery ? rushDeliveryFee : deliveryFeeDefault;
  }
}
