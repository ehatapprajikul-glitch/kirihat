import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class RiderRequestsScreen extends StatefulWidget {
  const RiderRequestsScreen({super.key});

  @override
  State<RiderRequestsScreen> createState() => _RiderRequestsScreenState();
}

class _RiderRequestsScreenState extends State<RiderRequestsScreen> {
  // --- APPROVE LOGIC ---
  Future<void> _approveRequest(DocumentSnapshot doc) async {
    // 1. Show Confirmation Dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Approve Rider?"),
        content: Text(
            "This will create a new user account for ${doc['name']} and assign them to the requested vendor."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text("Confirm Approval")),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Perform Creation Logic
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      var data = doc.data() as Map<String, dynamic>;

      // A. Create User in Auth (Secondary App)
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'tempRiderCreation',
        options: Firebase.app().options,
      );
      
      auth.UserCredential userCredential = await auth.FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
        email: data['email'],
        password: data['password'], // Using the password provided in request
      );

      String uid = userCredential.user!.uid;

      // B. Create 'riders' profile doc
      await FirebaseFirestore.instance.collection('riders').doc(uid).set({
        'name': data['name'],
        'email': data['email'],
        'phone': data['phone'],
        'gender': data['gender'],
        'dob': data['dob'],
        'address': data['address'],
        'aadhar_number': data['aadhar_number'],
        'pan_number': data['pan_number'],
        'vendor_id': data['vendor_id'], // Assign to Vendor
        'role': 'rider',
        'status': 'Active',
        'is_active': true,
        'wallet_balance': 0.0,
        'total_earnings': 0.0,
        'rating': 5.0,
        'created_at': FieldValue.serverTimestamp(),
      });

      // C. Create 'users' doc for Login Role
       await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': data['name'],
        'email': data['email'],
        'phone': data['phone'],
        'role': 'rider',
        'created_at': FieldValue.serverTimestamp(),
        'uid': uid,
      });

      // D. Update Request Status to Approved
      await doc.reference.update({'status': 'approved', 'approved_at': FieldValue.serverTimestamp()});

      await tempApp.delete();

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rider Approved & Created!"), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // --- VIEW DETAILS LOGIC ---
  void _showDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Rider Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              _detailRow("Full Name", data['name']),
              _detailRow("Email", data['email']),
              _detailRow("Phone", data['phone']),
              _detailRow("Gender", data['gender']),
              _detailRow("Date of Birth", data['dob']),
              const SizedBox(height: 10),
              _detailRow("Address", data['address']),
              const Divider(),
              const Text("Documents", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 5),
              _detailRow("Aadhar Number", data['aadhar_number']),
              _detailRow("PAN Number", data['pan_number']),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close")),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))),
          Expanded(child: Text(value ?? "N/A", style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // --- REJECT LOGIC ---
  final _reasonCtrl = TextEditingController();
  final List<String> _reasons = ["Invalid Documents", "Underage", "Duplicate Application", "Incomplete Details", "Other"];
  String _selectedReason = "Invalid Documents";

  Future<void> _rejectRequest(DocumentReference ref) async {
    _reasonCtrl.clear();
    _selectedReason = _reasons.first;
    
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Reject Request", style: TextStyle(color: Colors.red)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Select a reason for rejection:"),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedReason,
                  items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setState(() => _selectedReason = val!),
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                ),
                if (_selectedReason == 'Other') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(labelText: "Specify Reason", border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                ]
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  String finalReason = _selectedReason == 'Other' ? _reasonCtrl.text.trim() : _selectedReason;
                  if (finalReason.isEmpty) return;
                  
                  await ref.update({
                    'status': 'rejected',
                    'rejection_reason': finalReason,
                    'rejected_at': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(c);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text("Reject"),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Rider Requests", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(25.0),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(25.0),
                color: Colors.blue,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black,
              tabs: const [
                Tab(text: "Pending Requests"),
                Tab(text: "Request History"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              children: [
                _buildRequestList(isHistory: false),
                _buildRequestList(isHistory: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList({required bool isHistory}) {
    Query query = FirebaseFirestore.instance.collection('rider_requests');

    if (isHistory) {
      query = query.where('status', whereIn: ['approved', 'rejected']);
      // Note: Add .orderBy('updated_at', descending: true) after creating Firebase Index
    } else {
      query = query.where('status', isEqualTo: 'pending');
      // Note: Add .orderBy('created_at', descending: true) after creating Firebase Index
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isHistory ? Icons.history : Icons.checklist, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(
                  isHistory ? "No history found" : "No pending requests",
                  style: const TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String status = data['status'] ?? 'pending';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: _getStatusColor(status).withOpacity(0.1),
                      child: Icon(Icons.person, color: _getStatusColor(status)),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showDetails(data),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(data['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                if (isHistory) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: _getStatusColor(status)),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                            Text("Vendor ID: ${data['vendor_id']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 5),
                            Text("Phone: ${data['phone']}"),
                            Text("Email: ${data['email']}"),
                            if (status == 'rejected' && data['rejection_reason'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text("Reason: ${data['rejection_reason']}", style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
                              ),
                            const SizedBox(height: 5),
                            const Text("Click to view full details", style: TextStyle(color: Colors.blue, fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),
                    if (!isHistory)
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _approveRequest(doc),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text("Approve"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _rejectRequest(doc.reference),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text("Reject"),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                          ),
                        ],
                      )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.blue;
  }
}
