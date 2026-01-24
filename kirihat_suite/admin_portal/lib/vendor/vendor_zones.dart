import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:kirihat_core/services/service_area_service.dart';

class VendorZonesScreen extends StatefulWidget {
  const VendorZonesScreen({super.key});

  @override
  State<VendorZonesScreen> createState() => _VendorZonesScreenState();
}

class _VendorZonesScreenState extends State<VendorZonesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final ServiceAreaService _service = ServiceAreaService();

  // Zone Management Controllers
  final TextEditingController _zonePincodeController = TextEditingController();
  
  List<dynamic> _availablePostOffices = [];
  final List<String> _selectedPostOffices = [];
  
  bool _isFetchingZones = false;
  String _zoneFetchStatus = ""; 
  bool _isFetchError = false;
  bool _isLoading = false;
  bool _isUpdateMode = false; // To track if we are updating an existing zone

  @override
  void dispose() {
    _zonePincodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchPostOfficesForPincode() async {
    String pincode = _zonePincodeController.text.trim();
    if (pincode.length != 6) {
      _showSnack("Enter a valid 6-digit Pincode", isError: true);
      return;
    }

    setState(() {
      _isFetchingZones = true;
      _zoneFetchStatus = "Fetching Post Offices...";
      _isFetchError = false;
      _availablePostOffices = [];
      _selectedPostOffices.clear();
      _isUpdateMode = false;
    });

    // 1. Fetch from API
    final apiResult = await _service.fetchPostOfficesForPincode(pincode);

    // 2. Check if Vendor ALREADY serves this pincode (Non-destructive check)
    List<String> existingServedAreas = [];
    try {
      final existingZones = await _service.getServiceAreasForPincode(pincode);
      // Filter for this vendor
      final myZone = existingZones.firstWhere(
        (z) => z['vendor_id'] == user!.uid, 
        orElse: () => {},
      );

      if (myZone.isNotEmpty) {
        existingServedAreas = List<String>.from(myZone['areas'] ?? []);
        _isUpdateMode = true;
      }
    } catch (e) {
      debugPrint("Error checking existing zones: $e");
    }

    setState(() {
      _isFetchingZones = false;
      if (apiResult['success'] == true) {
        _availablePostOffices = apiResult['data'];
        
        // Pre-select existing areas
        if (_isUpdateMode) {
          _selectedPostOffices.addAll(existingServedAreas);
          _zoneFetchStatus = "Update Mode: Existing areas selected. Add/Remove as needed.";
        } else {
          _zoneFetchStatus = "Found ${_availablePostOffices.length} areas. Select areas to serve:";
        }
      } else {
        _availablePostOffices = [];
        _zoneFetchStatus = apiResult['message'];
        _isFetchError = true;
      }
    });
  }

  Future<void> _addServiceZone(String uid) async {
    String pincode = _zonePincodeController.text.trim();
    if (pincode.isEmpty || _selectedPostOffices.isEmpty) {
      _showSnack("Enter Pincode and select at least one area", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    String zoneName = "Unknown City";
    if (_availablePostOffices.isNotEmpty) {
      zoneName = _availablePostOffices[0]['District'] ?? _availablePostOffices[0]['Circle'] ?? "Unknown";
    }

    final result = await _service.addServiceZone(
      uid: uid,
      pincode: pincode,
      selectedAreas: _selectedPostOffices,
      zoneName: zoneName,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSnack(result['message']);
      _resetInput();
    } else {
      if (result['type'] == 'conflict') {
        _showConflictDialog(result['conflictingAreas']);
      } else {
        _showSnack(result['message'], isError: true);
      }
    }
  }

  Future<void> _deleteServiceZone(String uid, String pincode) async {
    bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Delete Zone"),
              content: Text("Are you sure you want to stop serving Pincode $pincode?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Delete", style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirm != true) return;

    setState(() => _isLoading = true);
    
    final result = await _service.deleteServiceZone(uid: uid, pincode: pincode);
    
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSnack(result['message']);
    } else {
      _showSnack(result['message'], isError: true);
    }
  }

  void _resetInput() {
    _zonePincodeController.clear();
    setState(() {
      _availablePostOffices = [];
      _selectedPostOffices.clear();
      _zoneFetchStatus = "";
      _isFetchError = false;
      _isUpdateMode = false;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  void _showConflictDialog(List<dynamic> conflicting) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Area Already Claimed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The following areas are already served by another vendor:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: conflicting.map((area) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text(area.toString())),
                          ],
                        ),
                      )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Please uncheck these areas to proceed.'),
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

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login first")));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Delivery Zones Management"),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 1,
          shadowColor: Colors.black12,
          iconTheme: const IconThemeData(color: Colors.black87),
          titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
          bottom: const TabBar(
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepOrange,
            tabs: [
              Tab(text: "Manage Zones"),
              Tab(text: "History Logs"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildManageZonesTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildManageZonesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER INFO ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Search by Pincode to find areas. If you already serve a pincode, your existing areas will be pre-selected for easy expansion.",
                    style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- ADD ZONE SECTION ---
          const Text(
            "Add / Update Service Zone",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _zonePincodeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: "Pincode",
                            hintText: "e.g. 110001",
                            counterText: "",
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 58, 
                        child: ElevatedButton.icon(
                          onPressed: _isFetchingZones ? null : _fetchPostOfficesForPincode,
                          icon: _isFetchingZones
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search),
                          label: const Text("Search"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (_zoneFetchStatus.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _isFetchError ? Icons.error_outline : Icons.check_circle_outline,
                          size: 16,
                          color: _isFetchError ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _zoneFetchStatus,
                            style: TextStyle(
                              color: _isFetchError ? Colors.red : Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // AREA SELECTION
                  if (_availablePostOffices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availablePostOffices.map((office) {
                            String areaName = office['Name'];
                            bool isSelected = _selectedPostOffices.contains(areaName);
                            return FilterChip(
                              label: Text(areaName),
                              selected: isSelected,
                              selectedColor: Colors.orange.shade100,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.deepOrange : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              checkmarkColor: Colors.deepOrange,
                              side: BorderSide(
                                color: isSelected ? Colors.deepOrange.withOpacity(0.5) : Colors.grey.shade300,
                              ),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedPostOffices.add(areaName);
                                  } else {
                                    _selectedPostOffices.remove(areaName);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _addServiceZone(user!.uid),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_isUpdateMode 
                              ? "UPDATE ZONE (${_selectedPostOffices.length} Areas)" 
                              : "ADD ZONE (${_selectedPostOffices.length} Areas)"),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          const Text(
            "Active Service Zones",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),

          // --- ACTIVE ZONES LIST ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_areas')
                .where('vendorId', isEqualTo: user!.uid)
                .snapshots(),
            builder: (context, zoneSnap) {
              if (!zoneSnap.hasData) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ));
              }
              var zones = zoneSnap.data!.docs;

              if (zones.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.map_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No active zones", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: zones.length,
                itemBuilder: (context, index) {
                  var data = zones[index].data() as Map<String, dynamic>;
                  String displayPincode = data['pincode'] ?? "Unknown";
                  List<dynamic> areas = data['areas'] ?? [];
                  String zoneName = data['zoneName'] ?? "";

  Future<void> _removeAreaFromZone(String uid, String pincode, String areaToRemove, List<dynamic> currentAreas, String zoneName) async {
    // Determine new list
    List<String> newAreas = List<String>.from(currentAreas);
    newAreas.remove(areaToRemove);

    if (newAreas.isEmpty) {
      // If no areas left, delete the whole zone
       _deleteServiceZone(uid, pincode);
       return;
    }

    // Otherwise update
    setState(() => _isLoading = true);

    final result = await _service.addServiceZone(
      uid: uid,
      pincode: pincode,
      selectedAreas: newAreas,
      zoneName: zoneName,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSnack("Removed $areaToRemove from zone");
    } else {
      _showSnack(result['message'], isError: true);
    }
  }

  // ... (rest of the methods) 

  // Inside _buildManageZonesTab -> ListView.builder for Active Zones
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200)
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      displayPincode,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue.shade800,
                                        letterSpacing: 1
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (zoneName.isNotEmpty && zoneName != "Unknown City")
                                    Text(
                                      zoneName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
                                    ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteServiceZone(user!.uid, displayPincode),
                                tooltip: "Delete Entire Zone",
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          const Text(
                            "Serving Areas (Tap X to remove):",
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: areas.map((area) => Chip(
                              label: Text(
                                area,
                                style: TextStyle(fontSize: 12, color: Colors.deepOrange.shade700),
                              ),
                              backgroundColor: Colors.orange.shade50,
                              side: BorderSide(color: Colors.orange.shade100),
                              padding: const EdgeInsets.all(0),
                              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                              deleteIcon: const Icon(Icons.close, size: 14, color: Colors.deepOrange),
                              onDeleted: () => _removeAreaFromZone(user!.uid, displayPincode, area, areas, zoneName),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendor_zone_history')
          .where('vendor_id', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: SelectableText("Error loading history: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
           return const Center(child: Text("No history available."));
        }

        // ... (rest of list build)


        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            String action = data['action'] ?? "Unknown";
            String pincode = data['pincode'] ?? "";
            String details = data['details'] ?? "";
            Timestamp? ts = data['timestamp'];
            String timeStr = ts != null ? DateFormat('MMM d, h:mm a').format(ts.toDate()) : "-";

            Color color = Colors.blue;
            if (action == 'Create') color = Colors.green;
            if (action == 'Delete') color = Colors.red;
            if (action == 'Update') color = Colors.orange;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200)
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                action.toUpperCase(),
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text("Pincode: $pincode", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(details, style: TextStyle(color: Colors.grey[800])),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
