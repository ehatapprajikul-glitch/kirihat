import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionService {
  static const String _KEY_PINCODE = 'current_pincode';
  static const String _KEY_AREA = 'current_area';
  static const String _KEY_VENDOR_ID = 'assigned_vendor_id'; // Legacy
  static const String _KEY_VENDOR_IDS = 'assigned_vendor_ids'; // New
  static const String _KEY_USER_ID = 'current_user_id';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current session data
  Future<Map<String, dynamic>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> vendorIds = prefs.getStringList(_KEY_VENDOR_IDS) ?? [];
    
    // Fallback for migration
    if (vendorIds.isEmpty) {
      String? legacyVid = prefs.getString(_KEY_VENDOR_ID);
      if (legacyVid != null) vendorIds.add(legacyVid);
    }

    return {
      'pincode': prefs.getString(_KEY_PINCODE),
      'area': prefs.getString(_KEY_AREA),
      'vendorId': vendorIds.isNotEmpty ? vendorIds.first : null, // Compat
      'vendorIds': vendorIds,
      'userId': prefs.getString(_KEY_USER_ID),
    };
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final session = await getSession();
    return session['pincode'] != null && 
           session['area'] != null && 
           (session['vendorIds'] as List).isNotEmpty;
  }

  /// Save session to SharedPreferences and Firestore
  /// Now accepts List<String> vendorIds
  Future<void> saveSession({
    required String userId,
    required String pincode,
    required String area,
    List<String> vendorIds = const [],
    // Legacy support
    String? vendorId, 
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Handle single/multi logic
    List<String> finalVendorIds = List.from(vendorIds);
    if (finalVendorIds.isEmpty && vendorId != null) {
      finalVendorIds.add(vendorId);
    }

    await prefs.setString(_KEY_USER_ID, userId);
    await prefs.setString(_KEY_PINCODE, pincode);
    await prefs.setString(_KEY_AREA, area);
    await prefs.setStringList(_KEY_VENDOR_IDS, finalVendorIds);
    
    if (finalVendorIds.isNotEmpty) {
      await prefs.setString(_KEY_VENDOR_ID, finalVendorIds.first); // Compat
    }

    // Update Firestore user document
    try {
      await _firestore.collection('users').doc(userId).update({
        'session': {
          'current_pincode': pincode,
          'current_area': area,
          'assigned_vendor_ids': finalVendorIds,
          'last_updated': FieldValue.serverTimestamp(),
        },
      });
      print('Session saved: P:$pincode, A:$area, Vs:$finalVendorIds');
    } catch (e) {
      print('Error updating Firestore session: $e');
    }
  }

  /// Clear session (logout)
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_KEY_PINCODE);
    await prefs.remove(_KEY_AREA);
    await prefs.remove(_KEY_VENDOR_ID);
    await prefs.remove(_KEY_VENDOR_IDS);
    await prefs.remove(_KEY_USER_ID);
    print('Session cleared');
  }

  /// Load session from Firestore and sync to SharedPreferences
  /// Call this after login to restore session from cloud
  Future<bool> loadSessionFromFirestore(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        print('⚠️ User document not found in Firestore');
        return false;
      }

      final data = userDoc.data();
      if (data == null || !data.containsKey('session')) {
        print('⚠️ No session data in Firestore user document');
        return false;
      }

      final session = data['session'] as Map<String, dynamic>;
      final pincode = session['current_pincode'] as String?;
      final area = session['current_area'] as String?;
      final vendorIds = session['assigned_vendor_ids'] as List<dynamic>?;

      if (pincode == null || area == null || vendorIds == null || vendorIds.isEmpty) {
        print('⚠️ Incomplete session data in Firestore');
        return false;
      }

      // Sync to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_KEY_USER_ID, userId);
      await prefs.setString(_KEY_PINCODE, pincode);
      await prefs.setString(_KEY_AREA, area);
      await prefs.setStringList(_KEY_VENDOR_IDS, vendorIds.map((v) => v.toString()).toList());
      await prefs.setString(_KEY_VENDOR_ID, vendorIds.first.toString());

      print('✅ Session restored from Firestore: P:$pincode, A:$area, V:${vendorIds.first}');
      return true;
    } catch (e) {
      print('❌ Error loading session from Firestore: $e');
      return false;
    }
  }
}

