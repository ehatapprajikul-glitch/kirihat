import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fee_configuration_model.dart';

/// Service to manage platform fee configurations
/// Handles CRUD operations and caching for fee settings
class FeeConfigurationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection reference
  static const String _collectionName = 'fee_configuration';
  static const String _defaultDocId = 'default';
  
  // Cache for performance
  FeeConfigurationModel? _cachedConfig;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get current fee configuration (with caching)
  Future<FeeConfigurationModel> getFeeConfiguration() async {
    // Return cached if still valid
    if (_cachedConfig != null && _cacheTime != null) {
      final cacheAge = DateTime.now().difference(_cacheTime!);
      if (cacheAge < _cacheDuration) {
        return _cachedConfig!;
      }
    }

    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(_defaultDocId)
          .get();

      if (doc.exists && doc.data() != null) {
        _cachedConfig = FeeConfigurationModel.fromMap(doc.data()!, doc.id);
        _cacheTime = DateTime.now();
        return _cachedConfig!;
      } else {
        // Create default config if doesn't exist
        final defaultConfig = FeeConfigurationModel.defaultConfig();
        await _createDefaultConfiguration(defaultConfig);
        _cachedConfig = defaultConfig;
        _cacheTime = DateTime.now();
        return defaultConfig;
      }
    } catch (e) {
      print('Error fetching fee configuration: $e');
      // Return default config on error
      return FeeConfigurationModel.defaultConfig();
    }
  }

  /// Get fee configuration as a stream for real-time updates
  Stream<FeeConfigurationModel> getFeeConfigurationStream() {
    return _firestore
        .collection(_collectionName)
        .doc(_defaultDocId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final config = FeeConfigurationModel.fromMap(snapshot.data()!, snapshot.id);
        _cachedConfig = config;
        _cacheTime = DateTime.now();
        return config;
      }
      return FeeConfigurationModel.defaultConfig();
    });
  }

  /// Update fee configuration
  Future<bool> updateFeeConfiguration(
    FeeConfigurationModel config,
    String updatedBy,
  ) async {
    try {
      final updatedConfig = config.copyWith(
        lastUpdatedBy: updatedBy,
        lastUpdatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_collectionName)
          .doc(_defaultDocId)
          .set(updatedConfig.toMap(), SetOptions(merge: true));

      // Clear cache to force refresh
      _cachedConfig = null;
      _cacheTime = null;

      return true;
    } catch (e) {
      print('Error updating fee configuration: $e');
      return false;
    }
  }

  /// Reset to default configuration
  Future<bool> resetToDefault(String updatedBy) async {
    try {
      final defaultConfig = FeeConfigurationModel.defaultConfig().copyWith(
        lastUpdatedBy: updatedBy,
      );

      await _firestore
          .collection(_collectionName)
          .doc(_defaultDocId)
          .set(defaultConfig.toMap());

      // Clear cache
      _cachedConfig = null;
      _cacheTime = null;

      return true;
    } catch (e) {
      print('Error resetting fee configuration: $e');
      return false;
    }
  }

  /// Create default configuration (internal use)
  Future<void> _createDefaultConfiguration(FeeConfigurationModel config) async {
    await _firestore
        .collection(_collectionName)
        .doc(_defaultDocId)
        .set(config.toMap());
  }

  /// Clear cache (useful for testing or forcing refresh)
  void clearCache() {
    _cachedConfig = null;
    _cacheTime = null;
  }

  /// Get platform fee percentage (quick access)
  Future<double> getPlatformFeePercentage() async {
    final config = await getFeeConfiguration();
    return config.platformFeePercentage;
  }

  /// Get delivery fee (quick access)
  Future<double> getDeliveryFee({
    required double orderValue,
    bool isRushDelivery = false,
  }) async {
    final config = await getFeeConfiguration();
    return config.getDeliveryFee(
      orderValue: orderValue,
      isRushDelivery: isRushDelivery,
    );
  }

  /// Calculate total fees for an order
  Future<Map<String, double>> calculateOrderFees({
    required double orderValue,
    bool isRushDelivery = false,
    bool includePaymentGatewayFee = true,
  }) async {
    final config = await getFeeConfiguration();
    
    final platformFee = config.calculatePlatformFee(orderValue);
    final deliveryFee = config.getDeliveryFee(
      orderValue: orderValue,
      isRushDelivery: isRushDelivery,
    );
    final paymentGatewayFee = includePaymentGatewayFee 
        ? config.calculatePaymentGatewayFee(orderValue) 
        : 0.0;

    return {
      'platformFee': platformFee,
      'deliveryFee': deliveryFee,
      'paymentGatewayFee': paymentGatewayFee,
      'packagingFee': config.packagingFee,
      'totalFees': platformFee + deliveryFee + paymentGatewayFee + config.packagingFee,
    };
  }
}
