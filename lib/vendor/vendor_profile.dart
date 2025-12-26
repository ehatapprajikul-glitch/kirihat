import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.orange[100],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.orange,
              child: Icon(Icons.store, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              "My Shop Name",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              user?.email ?? "Vendor",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Verified Vendor",
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ),
            const SizedBox(height: 30),
            _buildSectionHeader("Account Settings"),
            _buildListTile(Icons.edit, "Edit Profile Name", () {}),
            _buildListTile(Icons.storefront, "Change Vendor Type", () {}),
            _buildListTile(Icons.lock, "Change PIN", () {}),
            _buildSectionHeader("Rider Management"),
            _buildListTile(Icons.moped, "My Riders", () {}),
            _buildListTile(Icons.person_add, "Request New Rider", () {}),
            _buildSectionHeader("Danger Zone"),
            _buildListTile(
              Icons.power_settings_new,
              "Disable Account",
              () {},
              isDanger: true,
            ),
            _buildListTile(
              Icons.logout,
              "Logout",
              () => FirebaseAuth.instance.signOut(),
              isDanger: true,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDanger = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDanger ? Colors.red : Colors.black87),
      title: Text(
        title,
        style: TextStyle(color: isDanger ? Colors.red : Colors.black87),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
