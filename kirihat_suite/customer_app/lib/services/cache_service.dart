import 'dart:async';

/// Cached data wrapper with expiration tracking
class CachedData<T> {
  final T data;
  final DateTime timestamp;
  final Duration duration;

  CachedData(
    this.data,
    this.timestamp, {
    this.duration = const Duration(minutes: 5),
  });

  bool get isExpired => DateTime.now().difference(timestamp) > duration;
}

/// Service for caching Firestore data to reduce read operations
/// 
/// Usage:
/// ```dart
/// final products = await CacheService().get(
///   key: 'products_$vendorId',
///   fetcher: () => fetchProductsFromFirestore(vendorId),
///   duration: Duration(minutes: 10),
/// );
/// ```
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CachedData> _cache = {};

  /// Get data from cache or fetch if not available/expired
  Future<T?> get<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration duration = const Duration(minutes: 5),
  }) async {
    // Check if cached and not expired
    if (_cache.containsKey(key)) {
      final cached = _cache[key]!;
      if (!cached.isExpired) {
        print('✅ Cache HIT: $key');
        return cached.data as T;
      } else {
        print('⏰ Cache EXPIRED: $key');
      }
    } else {
      print('❌ Cache MISS: $key');
    }

    // Fetch fresh data
    try {
      final data = await fetcher();
      _cache[key] = CachedData(data, DateTime.now(), duration: duration);
      print('💾 Cached: $key (expires in ${duration.inMinutes}min)');
      return data;
    } catch (e) {
      // If fetch fails and we have expired cache, return it as fallback
      if (_cache.containsKey(key)) {
        print('⚠️ Fetch failed, using stale cache: $key');
        return _cache[key]!.data as T;
      }
      rethrow;
    }
  }

  /// Invalidate a specific cache entry
  void invalidate(String key) {
    _cache.remove(key);
    print('🗑️ Invalidated cache: $key');
  }

  /// Invalidate all cache entries
  void invalidateAll() {
    final count = _cache.length;
    _cache.clear();
    print('🗑️ Cleared all cache ($count entries)');
  }

  /// Invalidate cache entries matching a pattern
  void invalidatePattern(String pattern) {
    final keysToRemove = _cache.keys.where((key) => key.contains(pattern)).toList();
    for (var key in keysToRemove) {
      _cache.remove(key);
    }
    print('🗑️ Invalidated ${keysToRemove.length} entries matching: $pattern');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    int expired = 0;
    int valid = 0;
    
    for (var entry in _cache.values) {
      if (entry.isExpired) {
        expired++;
      } else {
        valid++;
      }
    }
    
    return {
      'total': _cache.length,
      'valid': valid,
      'expired': expired,
      'keys': _cache.keys.toList(),
    };
  }

  /// Clean up expired entries
  void cleanExpired() {
    final keysToRemove = <String>[];
    
    _cache.forEach((key, value) {
      if (value.isExpired) {
        keysToRemove.add(key);
      }
    });
    
    for (var key in keysToRemove) {
      _cache.remove(key);
    }
    
    print('🧹 Cleaned ${keysToRemove.length} expired entries');
  }
}
