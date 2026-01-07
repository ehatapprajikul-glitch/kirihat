import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceAreaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Find all service areas (Post Offices) available for a pincode across ALL vendors
  /// Returns: { zoneName, areas: Set<String>, vendors: List<String> }
  Future<Map<String, dynamic>?> getAggregatedServiceAreas(String pincode) async {
    try {
      // Logic: Query 'service_areas' collection where pincode == X
      // Note: We need a field 'pincode' in the doc to query, since DocID might be composite
      final querySnapshot = await _firestore
          .collection('service_areas')
          .where('pincode', isEqualTo: pincode)
          .where('isActive', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      Set<String> aggregatedAreas = {};
      Set<String> vendorIds = {};
      String zoneName = "";

      for (var doc in querySnapshot.docs) {
        var data = doc.data();
        if (data['areas'] != null) {
          aggregatedAreas.addAll(List<String>.from(data['areas']));
        }
        if (data['vendorId'] != null) vendorIds.add(data['vendorId']);
        if (zoneName.isEmpty && data['zoneName'] != null) {
          zoneName = data['zoneName'];
        }
      }

      return {
        'pincode': pincode,
        'zoneName': zoneName,
        'areas': aggregatedAreas.toList()..sort(),
        'vendorIds': vendorIds.toList(),
      };
    } catch (e) {
      print('Error getting aggregated areas: $e');
      return null;
    }
  }

  /// Find all vendors serving a specific Pincode AND Area
  Future<List<String>> findVendorsForArea(String pincode, String areaName) async {
    try {
      print('🔍 Searching vendors for pincode: $pincode, area: $areaName');
      
      final querySnapshot = await _firestore
          .collection('service_areas')
          .where('pincode', isEqualTo: pincode)
          .where('areas', arrayContains: areaName)
          .where('isActive', isEqualTo: true)
          .get();

      print('📦 Found ${querySnapshot.docs.length} matching service areas');

      Set<String> vendorIds = {};
      for (var doc in querySnapshot.docs) {
        final vendorId = doc.data()['vendorId'] ?? doc.data()['vendor_id'];
        if (vendorId != null) {
          vendorIds.add(vendorId);
          print('✅ Added vendor: $vendorId');
        }
      }

      print('🎯 Total unique vendors: ${vendorIds.length}');
      return vendorIds.toList();
    } catch (e) {
      print('❌ Error finding vendors for area: $e');
      return [];
    }
  }

  /// Check if any of the given areas are already claimed by another vendor
  /// Returns: { isAvailable: bool, conflictingAreas: [], claimedBy: 'vendor_id' }
  Future<Map<String, dynamic>> checkAreaExclusivity({
    required String pincode,
    required List<String> areasToCheck,
    required String currentVendorId,
  }) async {
    try {
      // Query all service_areas for this pincode
      final querySnapshot = await _firestore
          .collection('service_areas')
          .where('pincode', isEqualTo: pincode)
          .where('isActive', isEqualTo: true)
          .get();

      Map<String, String> areaOwnership = {}; // area -> vendor_id

      for (var doc in querySnapshot.docs) {
        var data = doc.data();
        String vendorId = data['vendorId'] ?? data['vendor_id'] ?? '';
        
        // Skip if it's the current vendor (allow editing own areas)
        if (vendorId == currentVendorId) continue;

        List<dynamic> areas = data['areas'] ?? [];
        for (var area in areas) {
          areaOwnership[area.toString()] = vendorId;
        }
      }

      // Check for conflicts
      List<String> conflictingAreas = [];
      String? claimedBy;

      for (var area in areasToCheck) {
        if (areaOwnership.containsKey(area)) {
          conflictingAreas.add(area);
          claimedBy = areaOwnership[area];
        }
      }

      return {
        'isAvailable': conflictingAreas.isEmpty,
        'conflictingAreas': conflictingAreas,
        'claimedBy': claimedBy,
      };
    } catch (e) {
      print('Error checking area exclusivity: $e');
      return {
        'isAvailable': false,
        'conflictingAreas': [],
        'error': e.toString(),
      };
    }
  }

  /// Get all vendor zones (service areas) for a specific pincode
  /// Returns list of zone data including zone_name and vendor_id
  Future<List<Map<String, dynamic>>> getServiceAreasForPincode(String pincode) async {
    try {
      // First try with arrayContains (if pincodes is an array)
      var querySnapshot = await _firestore
          .collection('service_areas')
          .where('pincodes', arrayContains: pincode)
          .where('isActive', isEqualTo: true)
          .get();

      // If no results, try with equality (if pincode is a string)
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _firestore
            .collection('service_areas')
            .where('pincode', isEqualTo: pincode)
            .where('isActive', isEqualTo: true)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        print('❌ No service areas found for pincode: $pincode');
        return [];
      }

      print('✅ Found ${querySnapshot.docs.length} service areas for pincode: $pincode');

      List<Map<String, dynamic>> zones = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        print('Service Area: ${doc.id} - ${data['zoneName']} - ${data['areas']}');
        zones.add({
          'zone_id': doc.id,
          'zone_name': data['zoneName'] ?? '',
          'vendor_id': data['vendorId'] ?? data['vendor_id'] ?? '',
          'areas': data['areas'] ?? [],
        });
      }

      return zones;
    } catch (e) {
      print('❌ Error getting service areas for pincode: $e');
      return [];
    }
  }
}
