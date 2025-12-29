import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Add intl package for DateFormat if needed, or use string formatting

class VendorRidersScreen extends StatefulWidget {
  const VendorRidersScreen({super.key});

  @override
  State<VendorRidersScreen> createState() => _VendorRidersScreenState();
}

class _VendorRidersScreenState extends State<VendorRidersScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- DELETE LOGIC ---
  void _deleteRider(String docId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Rider?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('riders')
                  .doc(docId)
                  .delete();
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Rider Management"),
        backgroundColor: Colors.orange[100],
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRiderForm(),
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add New Rider"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('riders')
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
                  Icon(Icons.moped, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("No riders found.",
                      style: TextStyle(color: Colors.grey)),
                  const Text("Add a rider to start delivering."),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'Active';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[50],
                    child: Text(
                      (data['name'] ?? "U")[0].toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange),
                    ),
                  ),
                  title: Text(data['name'] ?? "Unknown Rider",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${data['phone']}"),
                      Text(status,
                          style: TextStyle(
                              color: status == 'Active'
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 12)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _openRiderForm(riderDoc: docs[index]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRider(docs[index].id),
                      ),
                    ],
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
    _passCtrl.text = data['password'] ?? ''; // Displaying for edit convenience
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
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
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
        'password': _passCtrl.text.trim(), // Stored for reference/login logic
        'dob': _dobCtrl.text.trim(),
        'gender': _gender,
        'address': _addressCtrl.text.trim(),
        'aadhar_number': _aadharCtrl.text.trim(),
        'pan_number': _panCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'status': 'Active', // Default status
        'role': 'rider',
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.riderDoc == null) {
        // Create New
        riderData['created_at'] = FieldValue.serverTimestamp();
        riderData['joined_date'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('riders').add(riderData);
      } else {
        // Update Existing
        await widget.riderDoc!.reference.update(riderData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Rider Saved Successfully")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.riderDoc == null ? "Add Rider" : "Edit Rider Profile"),
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
                  isObscure: true), // In real app, hide this better

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
                      : Text(widget.riderDoc == null
                          ? "CREATE RIDER PROFILE"
                          : "UPDATE PROFILE"),
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
