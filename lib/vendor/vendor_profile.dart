import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vendor_riders.dart';
import '../auth/login_screen.dart';
import 'vendor_zones.dart';
import 'vendor_commission.dart';
import 'vendor_settlements.dart';
import 'vendor_location_setup.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Controllers for Editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false; // THE HIDE/UNHIDE TOGGLE
  Map<String, dynamic>? vendorData;

  @override
  void initState() {
    super.initState();
    _fetchVendorDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchVendorDetails() async {
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(user!.uid)
            .get();
        if (doc.exists) {
          setState(() {
            vendorData = doc.data();
            // Pre-fill controllers
            _nameController.text =
                vendorData?['business_name'] ?? vendorData?['shop_name'] ?? "";
            _phoneController.text = vendorData?['phone'] ?? "";
            _addressController.text =
                vendorData?['shop_address'] ?? vendorData?['address'] ?? "";
            _isLoading = false;
          });
        } else {
          // New vendor - no profile yet
          setState(() {
            _isLoading = false;
            _isEditing = true; // Auto-open edit mode for new users
          });
        }
      } catch (e) {
        debugPrint("Error fetching profile: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(user!.uid)
          .update({
        'business_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'shop_address':
            _addressController.text.trim(), // Updates display address
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Profile Updated Successfully!"),
            backgroundColor: Colors.green));
        setState(() {
          _isEditing = false; // Hide edit mode
          _isLoading = false;
          // Update local data variable to reflect changes immediately
          vendorData?['business_name'] = _nameController.text.trim();
          vendorData?['phone'] = _phoneController.text.trim();
          vendorData?['shop_address'] = _addressController.text.trim();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.orange[100],
        elevation: 0,
        actions: [
          // EDIT / SAVE BUTTON IN APPBAR
          TextButton.icon(
            onPressed: () {
              if (_isEditing) {
                _saveProfileChanges();
              } else {
                setState(() => _isEditing = true);
              }
            },
            icon: Icon(_isEditing ? Icons.check : Icons.edit,
                color: Colors.deepOrange),
            label: Text(_isEditing ? "SAVE" : "EDIT",
                style: const TextStyle(
                    color: Colors.deepOrange, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 1. HEADER (Static - Identity)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.orange[100]),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.store,
                              size: 40, color: Colors.deepOrange),
                        ),
                        const SizedBox(height: 10),
                        // Name is now controlled by the input field in the body,
                        // but we show a static preview here or the email
                        Text(
                          user?.email ?? "",
                          style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold),
                        ),
                        if (vendorData?['is_verified'] == true)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Text("Verified ✅",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          )
                      ],
                    ),
                  ),

                  // 2. EDITABLE BUSINESS CARD
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Business Information",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            if (_isEditing)
                              const Text("Editing...",
                                  style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                _buildEditableRow("Business Name",
                                    Icons.business, _nameController),
                                const Divider(height: 30),
                                _buildEditableRow("Phone Number", Icons.phone,
                                    _phoneController),
                                const Divider(height: 30),
                                _buildEditableRow("Display Address",
                                    Icons.location_on, _addressController,
                                    maxLines: 2),
                                if (!_isEditing) ...[
                                  const Divider(height: 30),
                                  _buildStaticRow(
                                      Icons.confirmation_number,
                                      "Tax ID",
                                      vendorData?['tax_id'] ??
                                          "Not Set (Contact Admin)"),
                                ]
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. MENU OPTIONS (Preserved)
                  _buildSettingsTile(
                    icon: Icons.two_wheeler,
                    title: "Manage Riders",
                    subtitle: "Add or remove delivery staff",
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VendorRidersScreen())),
                  ),
                  _buildSettingsTile(
                    icon: Icons.store_mall_directory,
                    title: "Shop Location (GPS)",
                    subtitle: "Set GPS coordinates & Pincode",
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VendorLocationSetup())),
                  ),
                  _buildSettingsTile(
                    icon: Icons.map,
                    title: "Delivery Zones",
                    subtitle: "Manage fees & pincodes",
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VendorZonesScreen())),
                  ),
                  _buildSettingsTile(
                    icon: Icons.settings_input_component,
                    title: "Commission Logic",
                    subtitle: "Set Rider Pay X + Y",
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VendorCommissionScreen())),
                  ),
                  _buildSettingsTile(
                    icon: Icons.notifications,
                    title: "Notifications",
                    subtitle: "Manage alerts & sounds",
                    onTap: () {},
                  ),

                  const SizedBox(height: 20),

                  ListTile(
                    title: const Text("Rider Settlements"),
                    leading: const Icon(Icons.money, color: Colors.green),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VendorSettlementsScreen())),
                  ),

                  // 4. LOGOUT
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 30),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text("Log Out",
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- WIDGET HELPER FOR EDITABLE FIELDS ---
  Widget _buildEditableRow(
      String label, IconData icon, TextEditingController controller,
      {int maxLines = 1}) {
    if (_isEditing) {
      // EDIT MODE: Show Input Field
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              prefixIcon: Icon(icon, color: Colors.deepOrange, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.deepOrange)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      );
    } else {
      // VIEW MODE: Show Static Text
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(controller.text.isEmpty ? "Not set" : controller.text,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      );
    }
  }

  // Helper for things that are NEVER editable (like Tax ID)
  Widget _buildStaticRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54)),
            ],
          ),
        ),
        const Icon(Icons.lock,
            size: 14, color: Colors.grey), // Lock icon indicates read-only
      ],
    );
  }

  Widget _buildSettingsTile(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.deepOrange),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
