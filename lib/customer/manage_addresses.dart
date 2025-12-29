import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'address_screen.dart'; // To add/edit addresses

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- DELETE LOGIC (Fixes Ghost Address Bug) ---
  Future<void> _deleteAddress(
      String docId, Map<String, dynamic> addressData) async {
    if (user == null) return;

    // 1. Delete from subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('addresses')
        .doc(docId)
        .delete();

    // 2. Check if this was the 'current_address' in main profile
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (userDoc.exists && userDoc.data()!.containsKey('current_address')) {
      var current = userDoc.data()!['current_address'];

      // Compare unique fields (like created_at or pincode+street) to identify match
      // Ideally, save 'id' in current_address. For now, matching timestamps is safe.
      if (current['created_at'] == addressData['created_at']) {
        // It WAS the default. We must clear it or pick a new one.
        // Option A: Clear it (App will ask for location again)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({'current_address': FieldValue.delete()});

        // Option B (Better): Auto-select the most recent remaining address
        var remainingSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .orderBy('created_at', descending: true)
            .limit(1)
            .get();

        if (remainingSnap.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .update({'current_address': remainingSnap.docs.first.data()});
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Address Deleted")));
    }
  }

  // --- SET DEFAULT LOGIC ---
  Future<void> _setDefault(Map<String, dynamic> data) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .update({'current_address': data});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Set as Default Delivery Location")));
      Navigator.pop(context); // Go back to checkout or home
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null)
      return const Scaffold(body: Center(child: Text("Please Login")));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Addresses"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.green),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddressScreen()));
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text("No saved addresses",
                      style: TextStyle(color: Colors.grey)),
                  TextButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddressScreen()));
                      },
                      child: const Text("Add New Address"))
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String fullAddress =
                  "${data['house_no']}, ${data['street']}, ${data['city']} - ${data['pincode']}";

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.location_on, color: Colors.blue),
                      title: Text(data['landmark'] ?? "Address ${index + 1}",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(data['name'] ?? "User"),
                          Text(fullAddress),
                          Text("Phone: ${data['phone']}"),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                    const Divider(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () => _setDefault(data),
                            child: const Text("Set as Default")),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AddressScreen(
                                        addressId: docs[index].id,
                                        initialData: data)));
                          },
                          child: const Text("Edit",
                              style: TextStyle(color: Colors.grey)),
                        ),
                        TextButton(
                          onPressed: () => _deleteAddress(docs[index].id, data),
                          child: const Text("Delete",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
