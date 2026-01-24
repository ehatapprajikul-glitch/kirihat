import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ServiceAreaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- EXTERNAL API ---

  /// Fetch available Post Offices for a given Pincode from external API
  Future<Map<String, dynamic>> fetchPostOfficesForPincode(String pincode) async {
    if (pincode.length != 6) {
      return {'success': false, 'message': 'Invalid Pincode length'};
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          return {
            'success': true,
            'data': data[0]['PostOffice'],
            'message': 'Found areas'
          };
        } else {
          return {
            'success': false, 
            'message': 'No Post Offices found for this pincode.'
          };
        }
      } else {
        return {'success': false, 'message': 'API Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network Error: $e'};
    }
  }

  // --- QUERY & READ ---

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

  // --- WRITE OPERATIONS ---

  /// Internal helper to log history
  Future<void> _logHistory({
    required String vendorId,
    required String action, // 'Create', 'Update', 'Delete'
    required String pincode,
    required String details,
  }) async {
    try {
      await _firestore.collection('vendor_zone_history').add({
        'vendor_id': vendorId,
        'action': action,
        'pincode': pincode,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to log history: $e');
    }
  }

  /// Add a new service zone or update existing one
  Future<Map<String, dynamic>> addServiceZone({
    required String uid, 
    required String pincode, 
    required List<String> selectedAreas,
    required String zoneName,
  }) async {
    try {
      // 0. Check if zone exists to determine Action (Create vs Update)
      String docId = '${pincode}_$uid';
      final docSnap = await _firestore.collection('service_areas').doc(docId).get();
      
      bool isUpdate = docSnap.exists;
      Set<String> oldAreas = {};
      if (isUpdate) {
        oldAreas = Set<String>.from(docSnap.data()?['areas'] ?? []);
      }

      // 1. Exclusivity Check (Internal call)
      // Check ALL selected areas, even if previously owned (checkAreaExclusivity handles self-exclusion)
      final exclusivity = await checkAreaExclusivity(
        pincode: pincode,
        areasToCheck: selectedAreas,
        currentVendorId: uid,
      );

      if (!exclusivity['isAvailable']) {
        return {
          'success': false,
          'type': 'conflict',
          'conflictingAreas': exclusivity['conflictingAreas'],
          'message': 'Some areas are already claimed by another vendor.'
        };
      }

      // 2. Add/Update service_areas collection
      await _firestore.collection('service_areas').doc(docId).set({
        'doc_id': docId,
        'pincode': pincode,
        'vendorId': uid,
        'vendor_id': uid, // maintain consistency
        'areas': selectedAreas,
        'zoneName': zoneName,
        'isActive': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 3. Update Vendor's service_pincodes list
      await _firestore.collection('vendors').doc(uid).update({
        'service_pincodes': FieldValue.arrayUnion([pincode])
      });

      // 4. Log History
      if (isUpdate) {
        Set<String> newSet = Set.from(selectedAreas);
        List<String> added = newSet.difference(oldAreas).toList();
        List<String> removed = oldAreas.difference(newSet).toList();
        
        String details = "Updated zone.";
        if (added.isNotEmpty) details += " Added: ${added.join(', ')}.";
        if (removed.isNotEmpty) details += " Removed: ${removed.join(', ')}.";
        if (added.isEmpty && removed.isEmpty) details = "Updated zone details (no area change).";

        await _logHistory(vendorId: uid, action: 'Update', pincode: pincode, details: details);
      } else {
        await _logHistory(vendorId: uid, action: 'Create', pincode: pincode, details: "Created zone with ${selectedAreas.length} areas.");
      }

      return {'success': true, 'message': isUpdate ? 'Service Zone updated successfully' : 'Service Zone added successfully'};
    } catch (e) {
      return {'success': false, 'message': 'Database Error: $e'};
    }
  }

  /// Delete a service zone
  Future<Map<String, dynamic>> deleteServiceZone({
    required String uid, 
    required String pincode
  }) async {
    String docId = '${pincode}_$uid';
    try {
      // 1. Delete from service_areas
      await _firestore.collection('service_areas').doc(docId).delete();

      // 2. Remove from vendor's service_pincodes
      await _firestore.collection('vendors').doc(uid).update({
        'service_pincodes': FieldValue.arrayRemove([pincode])
      });

      // 3. Log History
      await _logHistory(vendorId: uid, action: 'Delete', pincode: pincode, details: "Deleted zone $pincode.");

      return {'success': true, 'message': 'Zone removed successfully'};
    } catch (e) {
      return {'success': false, 'message': 'Delete Error: $e'};
    }
  }
}
