import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/banner_model.dart';

class BannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all active banners ordered by position
  /// Get all active banners ordered by position
  Stream<List<BannerModel>> getActiveBanners() {
    return _firestore
        .collection('hero_banners')
        .orderBy('position')
        .limit(12)
        .snapshots()
        .map((snapshot) {
      final banners = snapshot.docs
          .map((doc) {
            final banner = BannerModel.fromFirestore(doc.id, doc.data());
            return banner;
          })
          .where((banner) => banner.isActive) // Filter active in Dart instead of Firestore
          .toList();
      return banners;
    });
  }

  /// Get all banners for admin (including inactive)
  Stream<List<BannerModel>> getAllBanners() {
    return _firestore
        .collection('hero_banners')
        .orderBy('position')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BannerModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Add new banner
  Future<String> addBanner(BannerModel banner) async {
    // Check active banner count
    final activeCount = await _firestore
        .collection('hero_banners')
        .where('is_active', isEqualTo: true)
        .get()
        .then((snap) => snap.docs.length);

    if (activeCount >= 12) {
      throw Exception('Maximum 12 active banners allowed');
    }

    final docRef = await _firestore.collection('hero_banners').add({
      ...banner.toFirestore(),
      'created_at': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Update banner
  Future<void> updateBanner(String bannerId, BannerModel banner) async {
    await _firestore
        .collection('hero_banners')
        .doc(bannerId)
        .update(banner.toFirestore());
  }

  /// Delete banner
  Future<void> deleteBanner(String bannerId) async {
    await _firestore.collection('hero_banners').doc(bannerId).delete();
  }

  /// Reorder banners
  Future<void> reorderBanners(List<BannerModel> banners) async {
    final batch = _firestore.batch();

    for (int i = 0; i < banners.length; i++) {
      final docRef = _firestore.collection('hero_banners').doc(banners[i].id);
      batch.update(docRef, {'position': i});
    }

    await batch.commit();
  }

  /// Toggle banner active status
  Future<void> toggleBannerStatus(String bannerId, bool isActive) async {
    await _firestore
        .collection('hero_banners')
        .doc(bannerId)
        .update({'is_active': isActive, 'updated_at': FieldValue.serverTimestamp()});
  }
}
