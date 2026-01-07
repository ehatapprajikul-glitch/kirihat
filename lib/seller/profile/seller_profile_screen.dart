import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/seller_model.dart';
import '../../services/seller_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerProfileScreen extends StatefulWidget {
  final SellerModel seller;

  const SellerProfileScreen({super.key, required this.seller});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final SellerService _sellerService = SellerService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  late SellerModel _seller; // Local state to update UI immediately

  // Edit Controllers
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _seller = widget.seller;
    _populateControllers();
  }

  void _populateControllers() {
    _businessNameCtrl.text = _seller.businessName;
    _ownerNameCtrl.text = _seller.ownerName;
    _phoneCtrl.text = _seller.phone;
    _addressCtrl.text = _seller.address;
  }

  Future<void> _uploadDocument(String docType) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isLoading = true);

      final url = await _sellerService.uploadDocument(_seller.id, docType, image);
      if (url != null) {
        // Update local map
        Map<String, String> newDocs = Map.from(_seller.documents ?? {});
        newDocs[docType] = url;

        // Save to Firestore
        await _sellerService.updateSellerDocuments(_seller.id, newDocs);

        setState(() {
          _seller = _seller.copyWith(documents: newDocs);
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully')),
        );
      } else {
        throw 'Upload failed';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final updates = {
        'business_name': _businessNameCtrl.text.trim(),
        'owner_name': _ownerNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      };

      final success = await _sellerService.updateSeller(_seller.id, updates);
      if (success) {
        setState(() {
          _seller = _seller.copyWith(
            businessName: updates['business_name'],
            ownerName: updates['owner_name'],
            phone: updates['phone'],
            address: updates['address'],
          );
          _isEditing = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      } else {
        throw 'Update failed';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
             // Header
            _buildHeader(),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Business Details', Icons.store),
                  const SizedBox(height: 16),
                  _buildProfileForm(),
                  
                  const SizedBox(height: 32),
                  _buildSectionHeader('Verification Documents', Icons.verified_user),
                  const SizedBox(height: 8),
                  Text('Upload clear images of your documents to get verified.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 16),
                  
                  _buildDocCard('GST Registration', 'gst'),
                  const SizedBox(height: 16),
                  _buildDocCard('PAN Card', 'pan'),
                  const SizedBox(height: 16),
                  _buildDocCard('FSSAI License', 'fssai'),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                         await FirebaseAuth.instance.signOut();
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Logout', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF0D9759),
            child: Text(
              _seller.businessName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _seller.businessName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _seller.verified ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _seller.verified ? Colors.green : Colors.orange),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _seller.verified ? Icons.check_circle : Icons.pending,
                  size: 16,
                  color: _seller.verified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _seller.verified ? 'Verified Seller' : 'Verification Pending',
                  style: TextStyle(
                    color: _seller.verified ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0D9759), size: 20),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildProfileForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isEditing)
                TextButton(
                  onPressed: _saveProfile,
                  child: _isLoading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                  onPressed: () => setState(() => _isEditing = true),
                ),
            ],
          ),
          _buildTextField('Business Name', _businessNameCtrl, enabled: _isEditing),
          const SizedBox(height: 12),
          _buildTextField('Owner Name', _ownerNameCtrl, enabled: _isEditing),
          const SizedBox(height: 12),
          _buildTextField('Phone', _phoneCtrl, enabled: _isEditing),
          const SizedBox(height: 12),
          _buildTextField('Address', _addressCtrl, enabled: _isEditing, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool enabled = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: enabled ? const OutlineInputBorder() : InputBorder.none,
        contentPadding: enabled ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        filled: enabled,
        fillColor: Colors.grey[50],
      ),
      style: TextStyle(
        fontWeight: enabled ? FontWeight.normal : FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDocCard(String title, String docKey) {
    final docs = _seller.documents ?? {};
    final docUrl = docs[docKey];
    final isUploaded = docUrl != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
           Container(
             width: 50,
             height: 50,
             decoration: BoxDecoration(
               color: isUploaded ? Colors.green.shade50 : Colors.grey.shade100,
               borderRadius: BorderRadius.circular(8),
               image: isUploaded ? DecorationImage(image: NetworkImage(docUrl), fit: BoxFit.cover) : null,
             ),
             child: isUploaded 
               ? null 
               : const Icon(Icons.upload_file, color: Colors.grey),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 4),
                 Text(
                   isUploaded ? 'Uploaded' : 'Missing',
                   style: TextStyle(
                     color: isUploaded ? Colors.green : Colors.red,
                     fontSize: 12,
                   ),
                 ),
               ],
             ),
           ),
           ElevatedButton(
             onPressed: () => _uploadDocument(docKey),
             style: ElevatedButton.styleFrom(
               backgroundColor: isUploaded ? Colors.white : const Color(0xFF0D9759),
               foregroundColor: isUploaded ? const Color(0xFF0D9759) : Colors.white,
               side: isUploaded ? const BorderSide(color: Color(0xFF0D9759)) : null,
             ),
             child: Text(isUploaded ? 'Update' : 'Upload'),
           ),
        ],
      ),
    );
  }
}
