import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Updates the user's basic profile information
  Future<void> updateProfile(String uid, {String? name, String? gender}) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (gender != null) updates['gender'] = gender;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }
}
