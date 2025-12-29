import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorCommissionScreen extends StatefulWidget {
  const VendorCommissionScreen({super.key});

  @override
  State<VendorCommissionScreen> createState() => _VendorCommissionScreenState();
}

class _VendorCommissionScreenState extends State<VendorCommissionScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _baseCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  final _maxOrderCtrl = TextEditingController();
  final _minOrderValCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var doc = await FirebaseFirestore.instance
        .collection('vendor_settings')
        .doc(user?.uid)
        .get();
    if (doc.exists) {
      var data = doc.data()!;
      _baseCtrl.text = (data['commission_base_x'] ?? 40).toString();
      _extraCtrl.text = (data['commission_extra_y'] ?? 20).toString();
      _maxOrderCtrl.text = (data['max_orders_per_trip'] ?? 5).toString();
      _minOrderValCtrl.text =
          (data['min_order_value_free_delivery'] ?? 500).toString();
    }
  }

  Future<void> _saveSettings() async {
    await FirebaseFirestore.instance
        .collection('vendor_settings')
        .doc(user?.uid)
        .set({
      'vendor_id': user?.uid,
      'commission_base_x': double.tryParse(_baseCtrl.text) ?? 40,
      'commission_extra_y': double.tryParse(_extraCtrl.text) ?? 20,
      'max_orders_per_trip': int.tryParse(_maxOrderCtrl.text) ?? 5,
      'min_order_value_free_delivery':
          double.tryParse(_minOrderValCtrl.text) ?? 500,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Settings Saved!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Commission & Rules"),
          backgroundColor: Colors.orange[100]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection("Rider Commission Structure"),
            const Text("Define earnings to encourage batch deliveries.",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            _buildInputField("Base Pay (X) - 1st Order", _baseCtrl, "e.g. 40"),
            _buildInputField(
                "Extra Pay (Y) - Per Addt'l Order", _extraCtrl, "e.g. 20"),
            const Divider(height: 40),
            _buildSection("Delivery Rules"),
            _buildInputField("Max Orders Per Trip", _maxOrderCtrl, "e.g. 5"),
            _buildInputField("Free Delivery Above Order Value",
                _minOrderValCtrl, "e.g. 500"),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white),
                child: const Text("UPDATE SETTINGS",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  Widget _buildInputField(
      String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
      ),
    );
  }
}
