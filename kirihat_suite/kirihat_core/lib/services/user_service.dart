import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache keys for SharedPreferences
  static const String _KEY_PROFILE_COMPLETE_PREFIX = 'profile_complete_';
  static const String _KEY_PROFILE_CACHE_TIME_PREFIX = 'profile_cache_time_';
  static const int _CACHE_VALIDITY_HOURS = 24;

  /// Checks if the user's profile is complete (Name, Gender, and at least one Address).
  Future<bool> isProfileComplete(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) return false;

      final data = userDoc.data();
      if (data == null) return false;

      // Check for Name and Gender
      final hasName = data.containsKey('name') &&
          (data['name'] as String?)?.isNotEmpty == true;
      final hasGender = data.containsKey('gender') &&
          (data['gender'] as String?)?.isNotEmpty == true;

      if (!hasName || !hasGender) return false;

      // Check for at least one Address
      final addressSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .limit(1)
          .get();

      return addressSnapshot.docs.isNotEmpty;
    } catch (e) {
      // In case of error (e.g. network), fail safe to false to force check/retry?
      // Or true to avoid blocking? 
      // Safe to assume false to ensure data integrity.
      print('Error checking profile completion: $e');
      return false;
    }
  }


  /// Checks if the user's profile is complete with local cache fallback.
  /// This method prevents false negatives when Firestore is temporarily unavailable.
  Future<bool> checkProfileCompletionWithCache(String uid) async {
    try {
      // First, try to get fresh data from Firestore
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        // User doesn't exist - definitely not complete
        await _updateProfileCompletionCache(uid, false);
        return false;
      }

      final data = userDoc.data();
      if (data == null) {
        await _updateProfileCompletionCache(uid, false);
        return false;
      }

      // Check for Name and Gender
      final hasName = data.containsKey('name') &&
          (data['name'] as String?)?.isNotEmpty == true;
      final hasGender = data.containsKey('gender') &&
          (data['gender'] as String?)?.isNotEmpty == true;

      if (!hasName || !hasGender) {
        await _updateProfileCompletionCache(uid, false);
        return false;
      }

      // Check for at least one Address
      final addressSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .limit(1)
          .get();

      final isComplete = addressSnapshot.docs.isNotEmpty;
      
      // Update cache with the fresh result
      await _updateProfileCompletionCache(uid, isComplete);
      
      return isComplete;
    } catch (e) {
      // On error (network issues, offline, etc.), use cached value
      print('⚠️ Error checking profile completion, using cache: $e');
      
      final cachedValue = await _getProfileCompletionFromCache(uid);
      
      if (cachedValue != null) {
        print('✅ Using cached profile completion status: $cachedValue');
        return cachedValue;
      }
      
      // No cache available - fail safe to false but log it
      print('❌ No cache available, defaulting to false');
      return false;
    }
  }

  /// Get cached profile completion status
  Future<bool?> _getProfileCompletionFromCache(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_KEY_PROFILE_COMPLETE_PREFIX$uid';
      final cacheTimeKey = '$_KEY_PROFILE_CACHE_TIME_PREFIX$uid';
      
      final cachedValue = prefs.getBool(cacheKey);
      final cacheTime = prefs.getInt(cacheTimeKey);
      
      if (cachedValue == null || cacheTime == null) {
        return null; // No cache
      }
      
      // Check if cache is still valid (within 24 hours)
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
      final cacheAgeHours = cacheAge / (1000 * 60 * 60);
      
      if (cacheAgeHours > _CACHE_VALIDITY_HOURS) {
        print('Cache expired (${cacheAgeHours.toStringAsFixed(1)} hours old)');
        return null; // Cache expired
      }
      
      return cachedValue;
    } catch (e) {
      print('Error reading cache: $e');
      return null;
    }
  }

  /// Update cached profile completion status
  Future<void> _updateProfileCompletionCache(String uid, bool isComplete) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_KEY_PROFILE_COMPLETE_PREFIX$uid';
      final cacheTimeKey = '$_KEY_PROFILE_CACHE_TIME_PREFIX$uid';
      
      await prefs.setBool(cacheKey, isComplete);
      await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      
      print('📝 Cached profile completion status: $isComplete for uid: $uid');
    } catch (e) {
      print('Error updating cache: $e');
      // Non-fatal, just log it
    }
  }

  /// Updates the user's basic profile information
  Future<void> updateProfile(String uid, {String? name, String? gender}) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (gender != null) updates['gender'] = gender;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
      
      // Invalidate cache since profile was just updated
      // We'll let the next check repopulate it
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_KEY_PROFILE_COMPLETE_PREFIX$uid');
      await prefs.remove('$_KEY_PROFILE_CACHE_TIME_PREFIX$uid');
      print('🗑️ Invalidated profile cache after update');
    }
  }
}
