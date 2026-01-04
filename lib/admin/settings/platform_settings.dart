import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformSettings extends StatefulWidget {
  const PlatformSettings({super.key});

  @override
  State<PlatformSettings> createState() => _PlatformSettingsState();
}

class _PlatformSettingsState extends State<PlatformSettings> {
  final _appNameController = TextEditingController();
  final _appVersionController = TextEditingController();
  final _minAppVersionController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _supportPhoneController = TextEditingController();

  // Branding
  String? _appIconUrl;
  String? _faviconUrl;
  bool _isUploading = false;
  String _brandingSource = 'manual'; // 'manual' or 'cloudinary'
  final _cloudNameController = TextEditingController();
  final _uploadPresetController = TextEditingController();

  bool _maintenanceMode = false;
  bool _newUserRegistration = true;
  bool _vendorRegistration = true;
  bool _razorpayEnabled = false;
  bool _codEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('platform_settings')
          .doc('app_config')
          .get();

      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          _appNameController.text = data['app_name'] ?? 'Kiri Hat';
          _appVersionController.text = data['app_version'] ?? '1.0.0';
          _minAppVersionController.text = data['min_app_version'] ?? '1.0.0';
          _supportEmailController.text = data['support_email'] ?? '';
          _supportPhoneController.text = data['support_phone'] ?? '';
          
          _appIconUrl = data['app_icon_url'];
          _faviconUrl = data['favicon_url'];
          _brandingSource = data['branding_source'] ?? 'manual';
          _cloudNameController.text = data['cloudinary_cloud_name'] ?? '';
          _uploadPresetController.text = data['cloudinary_upload_preset'] ?? '';

          _maintenanceMode = data['maintenance_mode'] ?? false;
          _newUserRegistration = data['new_user_registration'] ?? true;
          _vendorRegistration = data['vendor_registration'] ?? true;
          _razorpayEnabled = data['razorpay_enabled'] ?? false;
          _codEnabled = data['cod_enabled'] ?? true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadToCloudinary(String type) async {
    if (_cloudNameController.text.isEmpty || _uploadPresetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Cloud Name and Preset first')));
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/${_cloudNameController.text}/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPresetController.text
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      // For web, fromPath might not work with some pickers, but XFile usually handles it. 
      // If web fails, we need readAsBytes. Compatible fallback:
      if (kIsWeb) {
         request.files.clear();
         request.files.add(http.MultipartFile.fromBytes('file', await image.readAsBytes(), filename: 'upload.png'));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        final downloadUrl = jsonMap['secure_url'];

        setState(() {
          if (type == 'app_icon') {
            _appIconUrl = downloadUrl;
          } else {
            _faviconUrl = downloadUrl;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload successful!')));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // Helper for UI
  Widget _buildBrandingUI() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('App Branding', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _brandingSource,
            decoration: const InputDecoration(labelText: 'Branding Source', border: OutlineInputBorder()),
            items: const [
               DropdownMenuItem(value: 'manual', child: Text('Manual (Local File)')),
               DropdownMenuItem(value: 'cloudinary', child: Text('Cloudinary Storage')),
            ],
            onChanged: (val) => setState(() => _brandingSource = val!),
          ),
          const SizedBox(height: 16),

          if (_brandingSource == 'manual')
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
               child: const Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Icon(Icons.info_outline, color: Colors.blue),
                   SizedBox(width: 12),
                   Expanded(child: Text("Only 'App Name' will be saved here.\n\nFor Icons: Please verify 'assets/icon/icon.png' exists in your project folder and run the update script.")),
                 ],
               ),
             ),
          
          if (_brandingSource == 'cloudinary') ...[
             Row(
               children: [
                 Expanded(child: TextField(controller: _cloudNameController, decoration: const InputDecoration(labelText: 'Cloud Name', border: OutlineInputBorder()))),
                 const SizedBox(width: 16),
                 Expanded(child: TextField(controller: _uploadPresetController, decoration: const InputDecoration(labelText: 'Upload Preset', border: OutlineInputBorder()))),
               ],
             ),
             const SizedBox(height: 16),
             Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildImageUploader(
                      label: 'App Icon',
                      imageUrl: _appIconUrl,
                      onUpload: () => _uploadToCloudinary('app_icon'),
                      hint: '1024x1024 PNG',
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildImageUploader(
                      label: 'Web Favicon',
                      imageUrl: _faviconUrl,
                      onUpload: () => _uploadToCloudinary('favicon'),
                      hint: '32x32 PNG',
                    ),
                  ),
                ],
             ),
          ]
        ],
      ),
    );
  }

  Widget _buildImageUploader({
    required String label,
    required String? imageUrl,
    required VoidCallback onUpload,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isUploading ? null : onUpload,
          child: Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _isUploading
                ? const Center(child: CircularProgressIndicator())
                : imageUrl != null && imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('Upload', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 4),
        Text(hint, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _appVersionController.dispose();
    _minAppVersionController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Platform Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure app behavior and features',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 32),

          // App Information
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _appNameController,
                  decoration: const InputDecoration(
                    labelText: 'App Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _appVersionController,
                        decoration: const InputDecoration(
                          labelText: 'Current Version',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _minAppVersionController,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Version Required',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _supportEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Support Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _supportPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Support Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // App Branding
          _buildBrandingUI(),

          const SizedBox(height: 24),

          // Feature Flags
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Feature Flags',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text('Maintenance Mode'),
                  subtitle: const Text('Disable app for maintenance'),
                  value: _maintenanceMode,
                  activeColor: const Color(0xFF0D9759),
                  onChanged: (value) {
                    setState(() => _maintenanceMode = value);
                  },
                ),

                const Divider(),

                SwitchListTile(
                  title: const Text('New User Registration'),
                  subtitle: const Text('Allow new customers to sign up'),
                  value: _newUserRegistration,
                  activeColor: const Color(0xFF0D9759),
                  onChanged: (value) {
                    setState(() => _newUserRegistration = value);
                  },
                ),

                const Divider(),

                SwitchListTile(
                  title: const Text('Vendor Registration'),
                  subtitle: const Text('Allow new vendors to register'),
                  value: _vendorRegistration,
                  activeColor: const Color(0xFF0D9759),
                  onChanged: (value) {
                    setState(() => _vendorRegistration = value);
                  },
                ),

                const Divider(),

                SwitchListTile(
                  title: const Text('Razorpay Payment'),
                  subtitle: const Text('Enable online payments'),
                  value: _razorpayEnabled,
                  activeColor: const Color(0xFF0D9759),
                  onChanged: (value) {
                    setState(() => _razorpayEnabled = value);
                  },
                ),

                const Divider(),

                SwitchListTile(
                  title: const Text('Cash on Delivery'),
                  subtitle: const Text('Enable COD payment method'),
                  value: _codEnabled,
                  activeColor: const Color(0xFF0D9759),
                  onChanged: (value) {
                    setState(() => _codEnabled = value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('SAVE SETTINGS', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('platform_settings')
          .doc('app_config')
          .set({
        'app_name': _appNameController.text.trim(),
        'app_version': _appVersionController.text.trim(),
        'min_app_version': _minAppVersionController.text.trim(),
        'support_email': _supportEmailController.text.trim(),
        'support_phone': _supportPhoneController.text.trim(),
        'branding_source': _brandingSource,
        'cloudinary_cloud_name': _cloudNameController.text,
        'cloudinary_upload_preset': _uploadPresetController.text,
        'app_icon_url': _appIconUrl,
        'favicon_url': _faviconUrl,
        'maintenance_mode': _maintenanceMode,
        'new_user_registration': _newUserRegistration,
        'vendor_registration': _vendorRegistration,
        'razorpay_enabled': _razorpayEnabled,
        'cod_enabled': _codEnabled,
        'updated_at': FieldValue.serverTimestamp(),
      });


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
