import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorRidersScreen extends StatefulWidget {
  const VendorRidersScreen({super.key});

  @override
  State<VendorRidersScreen> createState() => _VendorRidersScreenState();
}

class _VendorRidersScreenState extends State<VendorRidersScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- DELETE LOGIC ---
  void _deleteDoc(DocumentReference ref) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              ref.delete();
              Navigator.pop(c);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // --- OPEN ADD/EDIT SCREEN ---
  void _openRiderForm({DocumentSnapshot? riderDoc}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RiderFormScreen(vendorId: user?.uid, riderDoc: riderDoc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Rider Management"),
          backgroundColor: Colors.orange[100],
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepOrange,
            tabs: [
              Tab(text: "Active Riders"),
              Tab(text: "Pending Requests"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openRiderForm(),
          backgroundColor: Colors.deepOrange,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("Request New Rider"),
        ),
        body: TabBarView(
          children: [
            _buildRiderList(isRequests: false),
            _buildRiderList(isRequests: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderList({required bool isRequests}) {
    String collection = isRequests ? 'rider_requests' : 'riders';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('vendor_id', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isRequests ? Icons.pending_actions : Icons.moped,
                    size: 80, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(
                    isRequests
                        ? "No pending requests."
                        : "No active riders found.",
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String status = data['status'] ?? (isRequests ? 'Pending' : 'Active');

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isRequests ? Colors.blue[50] : Colors.orange[50],
                  child: Text(
                    (data['name'] ?? "U")[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            isRequests ? Colors.blue : Colors.deepOrange),
                  ),
                ),
                title: Text(data['name'] ?? "Unknown Rider",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${data['phone']}"),
                    Row(
                      children: [
                        Text(status,
                            style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        if (status.toLowerCase() == 'rejected' && data['rejection_reason'] != null)
                           Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                "(${data['rejection_reason']})",
                                style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                           ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Only allow Editing Requests or Active Riders if needed
                    IconButton(
                      icon: Icon(
                          status.toLowerCase() == 'rejected'
                              ? Icons.refresh
                              : Icons.edit,
                          color: status.toLowerCase() == 'rejected'
                              ? Colors.red
                              : Colors.blue),
                      tooltip: status.toLowerCase() == 'rejected'
                          ? "Re-apply"
                          : "Edit",
                      onPressed: () => _openRiderForm(riderDoc: docs[index]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteDoc(docs[index].reference),
                    ),
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
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// ==========================================
//        SEPARATE RIDER FORM SCREEN
// ==========================================

class RiderFormScreen extends StatefulWidget {
  final String? vendorId;
  final DocumentSnapshot? riderDoc; // Null if adding new

  const RiderFormScreen({super.key, this.vendorId, this.riderDoc});

  @override
  State<RiderFormScreen> createState() => _RiderFormScreenState();
}

class _RiderFormScreenState extends State<RiderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _gender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    if (widget.riderDoc != null) {
      _loadData();
    }
  }

  void _loadData() {
    var data = widget.riderDoc!.data() as Map<String, dynamic>;
    _nameCtrl.text = data['name'] ?? '';
    _emailCtrl.text = data['email'] ?? '';
    _passCtrl.text = data['password'] ?? ''; 
    _dobCtrl.text = data['dob'] ?? '';
    _gender = data['gender'] ?? 'Male';
    _addressCtrl.text = data['address'] ?? '';
    _aadharCtrl.text = data['aadhar_number'] ?? '';
    _panCtrl.text = data['pan_number'] ?? '';
    _phoneCtrl.text = data['phone'] ?? '';
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005), // Default to 20ish years ago
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      // Age Validation
      final now = DateTime.now();
      final age = now.year - picked.year - 
          ((now.month < picked.month || (now.month == picked.month && now.day < picked.day)) ? 1 : 0);

      if (age < 18) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Rider must be at least 18 years old."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _dobCtrl.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _saveRider() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> riderData = {
        'vendor_id': widget.vendorId,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text.trim(), 
        'dob': _dobCtrl.text.trim(),
        'gender': _gender,
        'address': _addressCtrl.text.trim(),
        'aadhar_number': _aadharCtrl.text.trim(),
        'pan_number': _panCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.riderDoc == null) {
        // --- CREATE NEW REQUEST ---
        riderData['status'] = 'pending';
        riderData['created_at'] = FieldValue.serverTimestamp();
        
        await FirebaseFirestore.instance.collection('rider_requests').add(riderData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Request Submitted. Admin will review.")));
          Navigator.pop(context);
        }
      } else {
        // --- UPDATE EXISTING ---
        // If Status was Rejected, reset to Pending (Re-apply)
        var currentData = widget.riderDoc!.data() as Map<String, dynamic>;
        if (currentData['status'] == 'rejected') {
          riderData['status'] = 'pending';
          riderData['rejection_reason'] = FieldValue.delete();
        }
        
        await widget.riderDoc!.reference.update(riderData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Request Updated/Re-submitted")));
          Navigator.pop(context);
        }
      }

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    bool isNew = widget.riderDoc == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? "Request New Rider" : "Edit Details"),
        backgroundColor: Colors.orange[100],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Personal Information"),
              _buildTextField(_nameCtrl, "Full Name", Icons.person),
              _buildTextField(_emailCtrl, "Email Address", Icons.email,
                  isEmail: true),
              _buildTextField(_passCtrl, "Password", Icons.lock,
                  isObscure: true),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: AbsorbPointer(
                        child: _buildTextField(
                            _dobCtrl, "Date of Birth", Icons.calendar_today),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                          labelText: "Gender", border: OutlineInputBorder()),
                      items: _genders
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) => setState(() => _gender = val!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              _buildSectionHeader("Contact & Address"),
              _buildTextField(_phoneCtrl, "Mobile Number", Icons.phone,
                  isNumber: true, isMobile: true),
              _buildTextField(_addressCtrl, "Full Address", Icons.home,
                  maxLines: 3),

              const SizedBox(height: 20),
              _buildSectionHeader("Identity Verification"),
              _buildTextField(
                  _aadharCtrl, "Aadhar Number (12 Digits)", Icons.badge,
                  isNumber: true, isAadhar: true),
              _buildTextField(_panCtrl, "PAN Number", Icons.credit_card,
                  isPan: true),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRider,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isNew
                          ? "SUBMIT REQUEST"
                          : "UPDATE DETAILS"),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange)),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false,
      bool isEmail = false,
      bool isMobile = false,
      bool isAadhar = false,
      bool isPan = false,
      bool isObscure = false,
      int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        obscureText: isObscure,
        maxLines: maxLines,
        textCapitalization:
            isPan ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: (val) {
          if (val == null || val.isEmpty) return "$label is required";
          if (isEmail && !val.contains('@')) return "Invalid Email";
          if (isMobile && !RegExp(r'^[6-9]\d{9}$').hasMatch(val)) {
            return "Invalid Mobile (10 digits)";
          }
          if (isAadhar && !RegExp(r'^\d{12}$').hasMatch(val)) {
            return "Invalid Aadhar (12 digits)";
          }
          if (isPan && !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(val)) {
            return "Invalid PAN Format";
          }
          return null;
        },
      ),
    );
  }
}
