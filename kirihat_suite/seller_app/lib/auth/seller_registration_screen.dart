import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  State<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sellerService = SellerService();
  
  // Form controllers
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  final _aadharController = TextEditingController();
  final _udhyamController = TextEditingController();
  final _fssaiController = TextEditingController();
  
  // Bank account controllers
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _accountHolderController = TextEditingController();

  // Document files
  PlatformFile? _aadharDoc;
  PlatformFile? _udhyamDoc;
  PlatformFile? _panDoc;
  
  // Uploaded document URLs
  Map<String, String> _uploadedDocUrls = {};

  bool _isLoading = false;
  bool _termsAccepted = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    // Auto-populate email from signed-in user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email != null) {
      _emailController.text = currentUser!.email!;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _aadharController.dispose();
    _udhyamController.dispose();
    _fssaiController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  // Enhanced validators
  String? _validateGST(String? value) {
    if (value == null || value.isEmpty) return null;
    // GST format: 22AAAAA0000A1Z5
    final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    if (!gstRegex.hasMatch(value.toUpperCase())) {
      return 'Invalid GST format (e.g., 22AAAAA0000A1Z5)';
    }
    return null;
  }

  String? _validatePAN(String? value) {
    if (value == null || value.isEmpty) return null;
    // PAN format: AAAAA0000A
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegex.hasMatch(value.toUpperCase())) {
      return 'Invalid PAN format (e.g., ABCDE1234F)';
    }
    return null;
  }

  String? _validateIFSC(String? value) {
    if (value == null || value.isEmpty) return null;
    // IFSC format: AAAA0000000
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(value.toUpperCase())) {
      return 'Invalid IFSC format (e.g., SBIN0001234)';
    }
    return null;
  }

  String? _validateAadhar(String? value) {
    if (value == null || value.isEmpty) return 'Aadhar number is required';
    // Aadhar format: 12 digits
    final aadharRegex = RegExp(r'^\d{12}$');
    if (!aadharRegex.hasMatch(value)) {
      return 'Invalid Aadhar (must be 12 digits)';
    }
    return null;
  }

  String? _validateUdhyam(String? value) {
    if (value == null || value.isEmpty) return 'Udhyam number is required';
    // Udhyam format: UDYAM-XX-00-0000000
    final udhyamRegex = RegExp(r'^UDYAM-[A-Z]{2}-\d{2}-\d{7}$');
    if (!udhyamRegex.hasMatch(value.toUpperCase())) {
      return 'Invalid format (e.g., UDYAM-MH-01-0012345)';
    }
    return null;
  }

  String? _validatePANRequired(String? value) {
    if (value == null || value.isEmpty) return 'PAN number is required';
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegex.hasMatch(value.toUpperCase())) {
      return 'Invalid PAN format (e.g., ABCDE1234F)';
    }
    return null;
  }

  Future<void> _pickDocument(String docType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Check file size (max 500KB)
        if (file.size > 500 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File size must be less than 500 KB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          switch (docType) {
            case 'aadhar':
              _aadharDoc = file;
              break;
            case 'udhyam':
              _udhyamDoc = file;
              break;
            case 'pan':
              _panDoc = file;
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _uploadDocument(PlatformFile file, String docType) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = file.extension ?? 'jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('sellers/$userId/documents/${docType}_$timestamp.$ext');
      
      await ref.putData(file.bytes!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading $docType: $e');
      return null;
    }
  }

  Future<bool> _uploadAllDocuments() async {
    try {
      if (_aadharDoc != null) {
        final url = await _uploadDocument(_aadharDoc!, 'aadhar');
        if (url != null) _uploadedDocUrls['aadhar'] = url;
      }
      if (_udhyamDoc != null) {
        final url = await _uploadDocument(_udhyamDoc!, 'udhyam');
        if (url != null) _uploadedDocUrls['udhyam'] = url;
      }
      if (_panDoc != null) {
        final url = await _uploadDocument(_panDoc!, 'pan');
        if (url != null) _uploadedDocUrls['pan'] = url;
      }
      return true;
    } catch (e) {
      debugPrint('Error uploading documents: $e');
      return false;
    }
  }

  bool _validateCurrentStep() {
    // Validate only the fields in the current step
    switch (_currentStep) {
      case 0:
        return _businessNameController.text.isNotEmpty &&
               _ownerNameController.text.isNotEmpty &&
               _emailController.text.contains('@') &&
               _phoneController.text.length == 10;
      case 1:
        // Location + mandatory documents
        final hasLocation = _pincodeController.text.length == 6 &&
               _addressController.text.isNotEmpty &&
               _cityController.text.isNotEmpty &&
               _stateController.text.isNotEmpty;
        
        // Check mandatory document fields and uploads
        final hasAadhar = _aadharController.text.length == 12 && _aadharDoc != null;
        final hasUdhyam = _udhyamController.text.isNotEmpty && _udhyamDoc != null;
        final hasPan = _panController.text.length == 10 && _panDoc != null;
        
        return hasLocation && hasAadhar && hasUdhyam && hasPan;
      case 2:
        return _termsAccepted;
      default:
        return true;
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept Terms & Conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate mandatory documents
    if (_aadharDoc == null || _udhyamDoc == null || _panDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload all mandatory documents (Aadhar, Udhyam, PAN)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload documents first
      final uploadSuccess = await _uploadAllDocuments();
      if (!uploadSuccess) {
        throw Exception('Failed to upload documents');
      }
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final seller = SellerModel(
        id: '',
        userId: userId,
        businessName: _businessNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        pincode: _pincodeController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        gstNumber: _gstController.text.trim().isNotEmpty 
            ? _gstController.text.trim().toUpperCase() 
            : null,
        panNumber: _panController.text.trim().toUpperCase(),
        aadharNumber: _aadharController.text.trim(),
        udhyamNumber: _udhyamController.text.trim().toUpperCase(),
        fssaiLicense: _fssaiController.text.trim().isNotEmpty 
            ? _fssaiController.text.trim() 
            : null,
        bankAccount: _accountNumberController.text.trim().isNotEmpty
            ? BankAccount(
                accountNumber: _accountNumberController.text.trim(),
                ifsc: _ifscController.text.trim().toUpperCase(),
                accountHolder: _accountHolderController.text.trim(),
              )
            : null,
        documents: _uploadedDocUrls,
        createdAt: DateTime.now(),
      );

      final sellerId = await _sellerService.createSeller(seller);

      if (sellerId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration submitted successfully! Awaiting admin approval.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        // AuthWrapper will handle transition based on stream update
      } else {
        throw Exception('Failed to create seller registration');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTermsSection('1. Seller Agreement', 
                'By registering as a seller on Kirihat, you agree to our seller terms and conditions.'),
              _buildTermsSection('2. Product Compliance',
                'You are responsible for ensuring all products comply with Indian laws and regulations.'),
              _buildTermsSection('3. Accurate Information',
                'All information provided must be accurate and up-to-date. False information may result in account suspension.'),
              _buildTermsSection('4. Tax Compliance',
                'You are responsible for all applicable taxes including GST, income tax, etc.'),
              _buildTermsSection('5. Data Privacy',
                'Your information will be used as per our Privacy Policy and applicable data protection laws.'),
              _buildTermsSection('6. FSSAI Compliance',
                'If selling food products, valid FSSAI license is mandatory as per Food Safety and Standards Act, 2006.'),
              _buildTermsSection('7. Commission & Payments',
                'Kirihat will deduct applicable commission from sales. Payments follow our payment terms.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Become a Kirihat Seller'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
          child: Form(
            key: _formKey,
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Stepper(
      currentStep: _currentStep,
      onStepContinue: () {
        if (_validateCurrentStep()) {
          if (_currentStep < 2) {
            setState(() => _currentStep++);
          } else {
            _submitRegistration();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete all required fields'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      onStepCancel: () {
        if (_currentStep > 0) {
          setState(() => _currentStep--);
        }
      },
      controlsBuilder: (context, details) {
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9759),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep == 2 ? 'Submit Registration' : 'Continue',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Back', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      steps: [
        Step(
          title: const Text('Business Details'),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          content: _buildBusinessDetailsStep(),
        ),
        Step(
          title: const Text('Location & Licenses'),
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          content: _buildLocationLicenseStep(),
        ),
        Step(
          title: const Text('Bank & Confirmation'),
          isActive: _currentStep >= 2,
          state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          content: _buildBankConfirmationStep(),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressIndicator(),
              const SizedBox(height: 32),
              if (_currentStep == 0) _buildBusinessDetailsStep(),
              if (_currentStep == 1) _buildLocationLicenseStep(),
              if (_currentStep == 2) _buildBankConfirmationStep(),
              const SizedBox(height: 32),
              _buildDesktopControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        _buildProgressStep(0, 'Business', Icons.business),
        _buildProgressLine(0),
        _buildProgressStep(1, 'Location', Icons.location_on),
        _buildProgressLine(1),
        _buildProgressStep(2, 'Confirm', Icons.check_circle),
      ],
    );
  }

  Widget _buildProgressStep(int step, String label, IconData icon) {
    final isActive = _currentStep >= step;
    final isComplete = _currentStep > step;
    
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isComplete 
                ? const Color(0xFF0D9759) 
                : isActive 
                    ? const Color(0xFF0D9759).withOpacity(0.2) 
                    : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isComplete ? Icons.check : icon,
            color: isComplete 
                ? Colors.white 
                : isActive 
                    ? const Color(0xFF0D9759) 
                    : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF0D9759) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(int step) {
    final isComplete = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 32),
        color: isComplete ? const Color(0xFF0D9759) : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildDesktopControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton.icon(
            onPressed: () => setState(() => _currentStep--),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          )
        else
          const SizedBox(),
        ElevatedButton.icon(
          onPressed: _isLoading 
              ? null 
              : () {
                  if (_validateCurrentStep()) {
                    if (_currentStep < 2) {
                      setState(() => _currentStep++);
                    } else {
                      _submitRegistration();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please complete all required fields'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(_currentStep == 2 ? Icons.check : Icons.arrow_forward),
          label: Text(_currentStep == 2 ? 'Submit Registration' : 'Continue'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9759),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Information',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Provide your business details for registration',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _businessNameController,
          label: 'Business Name',
          icon: Icons.business,
          required: true,
          validator: (value) => value?.isEmpty ?? true ? 'Business name is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _ownerNameController,
          label: 'Owner Name',
          icon: Icons.person,
          required: true,
          validator: (value) => value?.isEmpty ?? true ? 'Owner name is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email,
          required: true,
          readOnly: true,
          keyboardType: TextInputType.emailAddress,
          helperText: 'Email from your signed-in account',
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Email is required';
            if (!value!.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone,
          required: true,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          prefixText: '+91 ',
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value?.length != 10) return 'Enter valid 10-digit number';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLocationLicenseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location & Business Licenses',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Provide your business address and mandatory documents',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _pincodeController,
          label: 'Pincode',
          icon: Icons.pin_drop,
          required: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value?.length != 6) return 'Enter valid 6-digit pincode';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: 'Complete Address',
          icon: Icons.home,
          required: true,
          maxLines: 3,
          validator: (value) => value?.isEmpty ?? true ? 'Address is required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _cityController,
                label: 'City',
                required: true,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _stateController,
                label: 'State',
                required: true,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        
        // Mandatory Documents Section
        _buildInfoCard(
          icon: Icons.warning_amber,
          title: 'Mandatory Documents',
          message: 'Aadhar, Udhyam, and PAN are required. Upload jpg, png, or pdf (max 500KB).',
          color: Colors.orange,
        ),
        const SizedBox(height: 20),
        
        // Aadhar Number with Upload
        _buildDocumentField(
          controller: _aadharController,
          label: 'Aadhar Number',
          icon: Icons.badge,
          docType: 'aadhar',
          selectedFile: _aadharDoc,
          helperText: 'Enter 12-digit Aadhar number',
          maxLength: 12,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: _validateAadhar,
        ),
        const SizedBox(height: 20),
        
        // Udhyam Registration Number with Upload
        _buildDocumentField(
          controller: _udhyamController,
          label: 'Udhyam Registration Number',
          icon: Icons.business_center,
          docType: 'udhyam',
          selectedFile: _udhyamDoc,
          helperText: 'Format: UDYAM-MH-01-0012345',
          textCapitalization: TextCapitalization.characters,
          validator: _validateUdhyam,
        ),
        const SizedBox(height: 20),
        
        // PAN Number with Upload
        _buildDocumentField(
          controller: _panController,
          label: 'PAN Number',
          icon: Icons.credit_card,
          docType: 'pan',
          selectedFile: _panDoc,
          helperText: 'Format: ABCDE1234F',
          maxLength: 10,
          textCapitalization: TextCapitalization.characters,
          validator: _validatePANRequired,
        ),
        
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        
        // Optional Fields
        _buildInfoCard(
          icon: Icons.info_outline,
          title: 'Optional Business Details',
          message: 'GST is recommended for business operations. FSSAI is mandatory for food products.',
          color: Colors.blue,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _gstController,
          label: 'GST Number',
          icon: Icons.receipt_long,
          helperText: 'Format: 22AAAAA0000A1Z5 (Optional)',
          textCapitalization: TextCapitalization.characters,
          validator: _validateGST,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _fssaiController,
          label: 'FSSAI License Number',
          icon: Icons.food_bank,
          helperText: 'Required for selling food products',
        ),
      ],
    );
  }

  Widget _buildDocumentField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String docType,
    required PlatformFile? selectedFile,
    String? helperText,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: selectedFile != null ? const Color(0xFF0D9759) : Colors.grey.shade300,
          width: selectedFile != null ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: selectedFile != null ? const Color(0xFF0D9759).withOpacity(0.05) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: controller,
            label: label,
            icon: icon,
            required: true,
            helperText: helperText,
            maxLength: maxLength,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            textCapitalization: textCapitalization,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDocument(docType),
                  icon: Icon(
                    selectedFile != null ? Icons.check_circle : Icons.upload_file,
                    color: selectedFile != null ? const Color(0xFF0D9759) : null,
                  ),
                  label: Text(
                    selectedFile != null 
                        ? selectedFile.name 
                        : 'Upload Document *',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    side: BorderSide(
                      color: selectedFile != null ? const Color(0xFF0D9759) : Colors.grey,
                    ),
                  ),
                ),
              ),
              if (selectedFile != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${(selectedFile.size / 1024).toStringAsFixed(0)} KB',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bank Account Details (Optional)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add bank details to receive payments (can be added later)',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        _buildInfoCard(
          icon: Icons.account_balance,
          title: 'Payment Information',
          message: 'You can skip this step and add bank details later from your seller dashboard.',
          color: Colors.orange,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _accountHolderController,
          label: 'Account Holder Name',
          icon: Icons.person_outline,
          helperText: 'Name as per bank records',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _accountNumberController,
          label: 'Account Number',
          icon: Icons.account_balance_wallet,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _ifscController,
          label: 'IFSC Code',
          icon: Icons.code,
          helperText: 'Format: SBIN0001234',
          textCapitalization: TextCapitalization.characters,
          validator: _validateIFSC,
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        _buildTermsCheckbox(),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _termsAccepted ? const Color(0xFF0D9759) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: _termsAccepted,
            onChanged: (value) => setState(() => _termsAccepted = value ?? false),
            activeColor: const Color(0xFF0D9759),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'I agree to the Terms & Conditions and confirm that all information provided is accurate',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: _showTermsDialog,
                  child: const Text('View Terms'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.verified_user,
            title: 'Legal Compliance',
            message: 'By submitting this registration, you confirm compliance with all applicable Indian laws including GST Act, Income Tax Act, FSSAI regulations, and e-commerce guidelines.',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool required = false,
    bool readOnly = false,
    String? helperText,
    String? prefixText,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        helperText: helperText,
        helperMaxLines: 2,
        prefixText: prefixText,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0D9759), width: 2),
        ),
        counterText: maxLength != null ? '' : null,
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
      ),
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator,
      textCapitalization: textCapitalization,
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HSLColor.fromColor(color).withLightness(0.35).toColor(),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: HSLColor.fromColor(color).withLightness(0.30).toColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}