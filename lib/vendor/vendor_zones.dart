import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorZonesScreen extends StatefulWidget {
  const VendorZonesScreen({super.key});

  @override
  State<VendorZonesScreen> createState() => _VendorZonesScreenState();
}

class _VendorZonesScreenState extends State<VendorZonesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _pincodesCtrl = TextEditingController();
  final _standardFeeCtrl = TextEditingController();
  final _instantFeeCtrl = TextEditingController();

  void _showZoneDialog({DocumentSnapshot? doc}) {
    if (doc != null) {
      var data = doc.data() as Map<String, dynamic>;
      _nameCtrl.text = data['zone_name'] ?? "";

      // Handle 'pincodes' safely (List or String)
      var pins = data['pincodes'];
      if (pins is List) {
        _pincodesCtrl.text = pins.join(',');
      } else {
        _pincodesCtrl.text = pins?.toString() ?? "";
      }

      _standardFeeCtrl.text = (data['standard_fee'] ?? 0).toString();
      _instantFeeCtrl.text = (data['instant_fee'] ?? 0).toString();
    } else {
      _nameCtrl.clear();
      _pincodesCtrl.clear();
      _standardFeeCtrl.clear();
      _instantFeeCtrl.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc == null ? "Create Zone" : "Edit Zone"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: "Zone Name (e.g., Downtown)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pincodesCtrl,
                // FIX: hintText moved inside InputDecoration
                decoration: const InputDecoration(
                    labelText: "Pincodes (comma separated)",
                    hintText: "781001, 781005..."),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _standardFeeCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: "Standard Fee (₹)"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _instantFeeCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: "Instant Fee (₹)"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.isEmpty) return;

              // Always save as List<String> to fix future errors
              List<String> pins = _pincodesCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              Map<String, dynamic> data = {
                'vendor_id': user?.uid,
                'zone_name': _nameCtrl.text.trim(),
                'pincodes': pins,
                'standard_fee': double.tryParse(_standardFeeCtrl.text) ?? 0,
                'instant_fee': double.tryParse(_instantFeeCtrl.text) ?? 0,
                'updated_at': FieldValue.serverTimestamp(),
              };

              if (doc == null) {
                await FirebaseFirestore.instance
                    .collection('vendor_zones')
                    .add(data);
              } else {
                await doc.reference.update(data);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save Zone"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Zone Management"),
          backgroundColor: Colors.orange[100]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showZoneDialog(),
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendor_zones')
            .where('vendor_id', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
                child: Text("No zones created. Add one to start delivery."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;

              // Handle 'pincodes' safely in list view
              var pins = data['pincodes'];
              int pinCount = (pins is List) ? pins.length : 1;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(data['zone_name'] ?? "Unknown Zone",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "Standard: ₹${data['standard_fee']} | Instant: ₹${data['instant_fee']}\nPincodes: $pinCount"),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showZoneDialog(doc: docs[index]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
