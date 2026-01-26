import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

/// Enhanced multi-step account deletion flow for Customers
class DeleteAccountEnhancedScreen extends StatefulWidget {
  const DeleteAccountEnhancedScreen({super.key});

  @override
  State<DeleteAccountEnhancedScreen> createState() => _DeleteAccountEnhancedScreenState();
}

class _DeleteAccountEnhancedScreenState extends State<DeleteAccountEnhancedScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  
  int _currentStep = 0;
  bool _isLoading = false;
  String? _selectedReason;
  final List<String> _selectedIssues = [];
  bool _agreedToTerms = false;
  
  final User? user = FirebaseAuth.instance.currentUser;

  // Customer-specific deletion reasons
  final List<Map<String, dynamic>> _deletionReasons = [
    {
      'title': 'Privacy Concerns',
      'icon': Icons.privacy_tip_outlined,
      'description': 'Worried about my data being shared',
    },
    {
      'title': 'Not Shopping Anymore',
      'icon': Icons.shopping_cart_outlined,
      'description': 'Don\'t need online shopping',
    },
    {
      'title': 'Too Many Notifications',
      'icon': Icons.notifications_off_outlined,
      'description': 'Getting too many promotional alerts',
    },
    {
      'title': 'Found Better Alternative',
      'icon': Icons.compare_arrows_outlined,
      'description': 'Using another shopping app',
    },
    {
      'title': 'Poor Delivery Experience',
      'icon': Icons.local_shipping_outlined,
      'description': 'Deliveries are late or damaged',
    },
    {
      'title': 'Product Quality Issues',
      'icon': Icons.thumb_down_outlined,
      'description': 'Products not as described',
    },
    {
      'title': 'Moving to Different Area',
      'icon': Icons.location_off_outlined,
      'description': 'Service not available in new location',
    },
    {
      'title': 'Other',
      'icon': Icons.more_horiz,
      'description': 'Different reason',
    },
  ];

  // Customer-specific issues
  final List<String> _commonIssues = [
    'App crashes frequently',
    'Poor product selection',
    'High prices',
    'Delivery delays',
    'Payment issues',
    'Refund problems',
    'Poor customer support',
    'Wrong items delivered',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _feedbackController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedReason != null;
      case 1:
        return true;
      case 2:
        return _agreedToTerms;
      case 3:
        return _confirmationController.text.toLowerCase() == 'delete';
      default:
        return false;
    }
  }

  Future<void> _deleteAccount() async {
    if (!_canProceed()) return;

    setState(() => _isLoading = true);

    try {
      // Save deletion reason to Firestore
      await _saveDeletionReason();
      
      // Delete user account
      await user?.delete();
      
      if (mounted) {
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'requires-recent-login') {
          _showReAuthDialog();
        } else {
          _showErrorDialog(e.message ?? 'Failed to delete account');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An unexpected error occurred: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDeletionReason() async {
    await FirebaseFirestore.instance.collection('account_deletions').add({
      'user_id': user?.uid,
      'user_type': 'customer',
      'email': user?.email,
      'phone': user?.phoneNumber,
      'reason': _selectedReason,
      'issues': _selectedIssues,
      'feedback': _feedbackController.text.trim(),
      'deleted_at': FieldValue.serverTimestamp(),
    });
  }

  void _showReAuthDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('Security Verification'),
          ],
        ),
        content: const Text(
          'For your security, you need to sign in again before deleting your account.\n\nPlease log out, sign in again, and retry.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('Account Deleted', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: const Text(
          'Your account has been permanently deleted. We\'re sorry to see you go.\n\nThank you for using Kirihat.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Return to Login'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Delete Account'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildReasonStep(),
                _buildFeedbackStep(),
                _buildConsequencesStep(),
                _buildConfirmationStep(),
              ],
            ),
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      color: Colors.red[700],
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 3) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildReasonStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why are you leaving?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text('Help us improve by sharing your reason', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          const SizedBox(height: 32),
          ...(_deletionReasons.map((reason) {
            final isSelected = _selectedReason == reason['title'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => setState(() => _selectedReason = reason['title']),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: isSelected ? Colors.red[700]! : Colors.grey[300]!, width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? Colors.red[50] : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.red[700] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(reason['icon'], color: isSelected ? Colors.white : Colors.grey[700], size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reason['title'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isSelected ? Colors.red[900] : Colors.black87)),
                            const SizedBox(height: 4),
                            Text(reason['description'], style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      if (isSelected) Icon(Icons.check_circle, color: Colors.red[700]),
                    ],
                  ),
                ),
              ),
            );
          })),
        ],
      ),
    );
  }

  Widget _buildFeedbackStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What could we improve?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Select all that apply (optional)', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonIssues.map((issue) {
              final isSelected = _selectedIssues.contains(issue);
              return FilterChip(
                label: Text(issue),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedIssues.add(issue);
                    } else {
                      _selectedIssues.remove(issue);
                    }
                  });
                },
                selectedColor: Colors.red[100],
                checkmarkColor: Colors.red[700],
                labelStyle: TextStyle(color: isSelected ? Colors.red[900] : Colors.black87, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text('Additional Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 12),
          TextField(
            controller: _feedbackController,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Tell us more about your experience...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red[700]!, width: 2)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsequencesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Before you go...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Please review what will happen', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          const SizedBox(height: 32),
          _buildConsequenceCard(icon: Icons.delete_forever, title: 'Permanent Deletion', description: 'Your account and all associated data will be permanently deleted and cannot be recovered.', color: Colors.red),
          _buildConsequenceCard(icon: Icons.shopping_bag_outlined, title: 'Order History', description: 'All your past orders, invoices, and purchase history will be erased.', color: Colors.orange),
          _buildConsequenceCard(icon: Icons.credit_card, title: 'Saved Payment Methods', description: 'All saved cards and payment information will be removed.', color: Colors.blue),
          _buildConsequenceCard(icon: Icons.location_on_outlined, title: 'Delivery Addresses', description: 'All saved delivery addresses will be deleted.', color: Colors.green),
          _buildConsequenceCard(icon: Icons.favorite_border, title: 'Wishlist & Cart', description: 'Your wishlist items and cart will be cleared.', color: Colors.pink),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[200]!)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: _agreedToTerms, onChanged: (value) => setState(() => _agreedToTerms = value ?? false), activeColor: Colors.red[700]),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, left: 8),
                    child: Text('I understand that this action is permanent and cannot be undone. All my data will be lost forever.', style: TextStyle(fontSize: 14, color: Colors.red[900], height: 1.4)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsequenceCard({required IconData icon, required String title, required String description, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Final Confirmation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('This is your last chance to cancel', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[300]!, width: 2)),
            child: Column(
              children: [
                Icon(Icons.warning_amber_rounded, size: 64, color: Colors.red[700]),
                const SizedBox(height: 16),
                Text('WARNING', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red[900])),
                const SizedBox(height: 8),
                Text('You are about to permanently delete your account. This action cannot be reversed under any circumstances.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.red[900], height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Type DELETE to confirm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmationController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Type DELETE here',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red[300]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red[700]!, width: 2)),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          if (_confirmationController.text.toLowerCase() != 'delete')
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(child: Text('Please type DELETE (case insensitive) to enable account deletion', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 16),
            Expanded(
              flex: _currentStep == 0 ? 1 : 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _canProceed() ? (_currentStep == 3 ? _deleteAccount : _nextStep) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == 3 ? Colors.red[700] : Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_currentStep == 3 ? 'DELETE ACCOUNT' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
