import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/service_area_service.dart';

class VendorZonesScreen extends StatefulWidget {
  const VendorZonesScreen({super.key});

  @override
  State<VendorZonesScreen> createState() => _VendorZonesScreenState();
}

class _VendorZonesScreenState extends State<VendorZonesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Zone Management Controllers
  final TextEditingController _zonePincodeController = TextEditingController();
  List<dynamic> _availablePostOffices = [];
  final List<String> _selectedPostOffices = [];
  bool _isFetchingZones = false;
  String _zoneFetchStatus = "";
  bool _isLoading = false;

  @override
  void dispose() {
    _zonePincodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchPostOfficesForPincode() async {
    String pincode = _zonePincodeController.text.trim();
    if (pincode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter a valid 6-digit Pincode")));
      return;
    }

    setState(() {
      _isFetchingZones = true;
      _zoneFetchStatus = "Fetching Post Offices...";
      _availablePostOffices = [];
      _selectedPostOffices.clear();
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          setState(() {
            _availablePostOffices = data[0]['PostOffice'];
            _zoneFetchStatus = "Found ${_availablePostOffices.length} areas.";
          });
        } else {
          setState(() =>
              _zoneFetchStatus = "No Post Offices found for this pincode.");
        }
      } else {
        setState(() => _zoneFetchStatus = "Error fetching data.");
      }
    } catch (e) {
      setState(() => _zoneFetchStatus = "Network Error: $e");
    } finally {
      setState(() => _isFetchingZones = false);
    }
  }

  Future<void> _addServiceZone(String uid) async {
    String pincode = _zonePincodeController.text.trim();
    if (pincode.isEmpty || _selectedPostOffices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Enter Pincode and select at least one area")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ===== EXCLUSIVITY CHECK =====
      final serviceAreaService = ServiceAreaService();
      final exclusivityCheck = await serviceAreaService.checkAreaExclusivity(
        pincode: pincode,
        areasToCheck: _selectedPostOffices,
        currentVendorId: uid,
      );

      if (!exclusivityCheck['isAvailable']) {
        List<String> conflicting = List<String>.from(exclusivityCheck['conflictingAreas']);
        
        if (mounted) {
          setState(() => _isLoading = false);
          
          // Show error dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Area Already Claimed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The following areas are already being served by another vendor:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...conflicting.map((area) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text(area)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                  Text(
                    'Please select different areas or choose a different pincode.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return; // Stop execution
      }
      // ===== END EXCLUSIVITY CHECK =====

      // 1. Add to service_areas collection
      String zoneName = "Unknown City";
      if (_availablePostOffices.isNotEmpty) {
         zoneName = _availablePostOffices[0]['District'] ?? _availablePostOffices[0]['Circle'] ?? "Unknown";
      }

      // Validating doc ID to be unique per vendor per pincode
      String docId = '${pincode}_$uid';

      await FirebaseFirestore.instance
          .collection('service_areas')
          .doc(docId)
          .set({
        'doc_id': docId,
        'pincode': pincode, // Critical for querying
        'vendorId': uid,
        'vendor_id': uid, 
        'areas': _selectedPostOffices,
        'zoneName': zoneName,
        'isActive': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 2. Update Vendor's service_pincodes list (Set to unique)
      await FirebaseFirestore.instance.collection('vendors').doc(uid).update({
        'service_pincodes': FieldValue.arrayUnion([pincode])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Service Zone $pincode added successfully!"),
            backgroundColor: Colors.green));
        
        // Reset inputs
        _zonePincodeController.clear();
        setState(() {
          _availablePostOffices = [];
          _selectedPostOffices.clear();
          _zoneFetchStatus = "";
        });
      }
    } catch (e) {
      debugPrint("Error adding zone: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteServiceZone(String uid, String pincode) async {
    // Note: pincode here is the 'pincode string', but docID is derived
    String docId = '${pincode}_$uid';

    bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Delete Zone"),
              content: Text(
                  "Are you sure you want to stop serving Pincode $pincode?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // 1. Delete from service_areas
      await FirebaseFirestore.instance
          .collection('service_areas')
          .doc(docId)
          .delete();

      // 2. Remove from vendor's service_pincodes
      await FirebaseFirestore.instance.collection('vendors').doc(uid).update({
        'service_pincodes': FieldValue.arrayRemove([pincode])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Zone removed."), backgroundColor: Colors.orange));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login first")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Zones"),
        backgroundColor: Colors.orange[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Add New Service Zone",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 5),
            const Text(
              "Defined pincodes and areas where you offer delivery.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Zone Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _zonePincodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: "Enter Service Pincode",
                      border: OutlineInputBorder(),
                      counterText: "",
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isFetchingZones ? null : _fetchPostOfficesForPincode,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15)),
                  child: _isFetchingZones
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("FETCH AREAS"),
                ),
              ],
            ),
            if (_zoneFetchStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_zoneFetchStatus,
                    style: TextStyle(
                        color: _zoneFetchStatus.contains("Error")
                            ? Colors.red
                            : Colors.green)),
              ),

            // Area Selection List
            if (_availablePostOffices.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text("Select Areas to Serve:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                height: 200,
                margin: const EdgeInsets.only(top: 5, bottom: 10),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availablePostOffices.length,
                  itemBuilder: (context, index) {
                    String areaName = _availablePostOffices[index]['Name'];
                    bool isSelected = _selectedPostOffices.contains(areaName);
                    return CheckboxListTile(
                      title: Text(areaName),
                      subtitle: Text(_availablePostOffices[index]['District']),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedPostOffices.add(areaName);
                          } else {
                            _selectedPostOffices.remove(areaName);
                          }
                        });
                      },
                      dense: true,
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _addServiceZone(user!.uid),
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text("ADD SERVICE ZONE"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white),
                ),
              ),
            ],

            const SizedBox(height: 30),
            const Divider(thickness: 2),
            const SizedBox(height: 10),

            const Text("Active Service Zones",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),

            // List of Active Zones for this Vendor
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_areas')
                  .where('vendorId', isEqualTo: user!.uid)
                  .snapshots(),
              builder: (context, zoneSnap) {
                if (!zoneSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var zones = zoneSnap.data!.docs;

                if (zones.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text("No Service Zones Active. Add one above."),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: zones.length,
                  itemBuilder: (context, index) {
                    var data = zones[index].data() as Map<String, dynamic>;
                    
                    // Handle 'doc_id' vs 'pincode' fallback logic if necessary
                    // The docID logic above ensures we know the ID usually matches pincode_vendorId
                    // but for display we use data['pincode']
                    String displayPincode = data['pincode'] ?? zones[index].id.split('_')[0];
                    List<dynamic> areas = data['areas'] ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.location_on,
                              color: Colors.deepOrange, size: 20),
                        ),
                        title: Text("Pincode: $displayPincode",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "${areas.length} Areas: ${areas.take(3).join(', ')}..."),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _deleteServiceZone(user!.uid, displayPincode),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
