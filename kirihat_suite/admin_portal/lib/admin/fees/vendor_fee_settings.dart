import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendorFeeSettings extends StatefulWidget {
  const VendorFeeSettings({super.key});

  @override
  State<VendorFeeSettings> createState() => _VendorFeeSettingsState();
}

class _VendorFeeSettingsState extends State<VendorFeeSettings> {
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fee Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure delivery, low cart, and platform fees per vendor',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('vendors').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading vendors'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('No vendors registered yet')),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    var vendor = snapshot.data!.docs[index];
                    return _buildVendorCard(vendor);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorCard(DocumentSnapshot vendor) {
    var data = vendor.data() as Map<String, dynamic>;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0D9759).withOpacity(0.1),
          foregroundColor: const Color(0xFF0D9759),
          child: const Icon(Icons.store),
        ),
        title: Text(
          data['business_name'] ?? data['shop_name'] ?? 'Unknown Vendor',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          data['address'] ?? 'No address',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _showConfigurationDialog(vendor.id, data['business_name'] ?? data['shop_name']),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Configure Fees'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9759),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  void _showConfigurationDialog(String vendorId, String vendorName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FeeConfigurationDialog(
        vendorId: vendorId,
        vendorName: vendorName,
      ),
    );
  }
}

class _FeeConfigurationDialog extends StatefulWidget {
  final String vendorId;
  final String vendorName;

  const _FeeConfigurationDialog({
    required this.vendorId,
    required this.vendorName,
  });

  @override
  State<_FeeConfigurationDialog> createState() => _FeeConfigurationDialogState();
}

class _FeeConfigurationDialogState extends State<_FeeConfigurationDialog> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Standard Delivery Fees
  bool _freeDeliveryEnabled = true;
  final _freeDeliveryThresholdCtrl = TextEditingController();
  final _standardDeliveryFeeCtrl = TextEditingController();

  // Instant Delivery Fees (New)
  bool _freeInstantDeliveryEnabled = false;
  final _freeInstantDeliveryThresholdCtrl = TextEditingController();
  final _instantDeliveryFeeCtrl = TextEditingController();

  // Low Cart Fees
  bool _lowCartEnabled = true;
  final _lowCartThresholdCtrl = TextEditingController();
  final _lowCartFeeCtrl = TextEditingController();

  // Platform Fees
  bool _platformFeeEnabled = false;
  String _platformFeeType = 'fixed'; // 'fixed' or 'percent'
  final _platformFeeValueCtrl = TextEditingController();

  // First Order Offers
  bool _firstOrderFreeDelivery = true;
  bool _firstOrderDetailedWaiver = true; // Use more descriptive name in map

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('vendor_settings')
          .doc(widget.vendorId)
          .get();

      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          // Delivery
          _freeDeliveryEnabled = data['free_delivery_enabled'] ?? true;
          _freeDeliveryThresholdCtrl.text = (data['min_order_value_free_delivery'] ?? 249).toString();
          _standardDeliveryFeeCtrl.text = (data['standard_delivery_fee'] ?? 25).toString();

          // Instant Delivery
          _freeInstantDeliveryEnabled = data['free_instant_delivery_enabled'] ?? false;
          _freeInstantDeliveryThresholdCtrl.text = (data['min_order_value_free_instant'] ?? 1000).toString();
          _instantDeliveryFeeCtrl.text = (data['instant_delivery_fee'] ?? 50).toString();

          // Low Cart
          _lowCartEnabled = data['low_cart_enabled'] ?? true;
          _lowCartThresholdCtrl.text = (data['low_cart_threshold'] ?? 199).toString();
          _lowCartFeeCtrl.text = (data['low_cart_fee'] ?? 15).toString();

          // Platform
          _platformFeeEnabled = data['platform_fee_enabled'] ?? false;
          _platformFeeType = data['platform_fee_type'] ?? 'fixed';
          _platformFeeValueCtrl.text = (data['platform_fee_value'] ?? 0).toString();

          // First Order
          _firstOrderFreeDelivery = data['first_order_free_delivery_enabled'] ?? true;
          _firstOrderDetailedWaiver = data['first_order_low_cart_waived'] ?? true;
        });
      } else {
        // Defaults
        _freeDeliveryThresholdCtrl.text = '249';
        _standardDeliveryFeeCtrl.text = '25';
        _freeInstantDeliveryThresholdCtrl.text = '1000';
        _instantDeliveryFeeCtrl.text = '50';
        _lowCartThresholdCtrl.text = '199';
        _lowCartFeeCtrl.text = '15';
        _platformFeeValueCtrl.text = '0';
      }
    } catch (e) {
      debugPrint('Error loading fees: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_validateInputs()) return;
    
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('vendor_settings').doc(widget.vendorId).set({
        // Standard Delivery
        'free_delivery_enabled': _freeDeliveryEnabled,
        'min_order_value_free_delivery': double.tryParse(_freeDeliveryThresholdCtrl.text) ?? 0,
        'standard_delivery_fee': double.tryParse(_standardDeliveryFeeCtrl.text) ?? 0,

        // Instant Delivery
        'free_instant_delivery_enabled': _freeInstantDeliveryEnabled,
        'min_order_value_free_instant': double.tryParse(_freeInstantDeliveryThresholdCtrl.text) ?? 0,
        'instant_delivery_fee': double.tryParse(_instantDeliveryFeeCtrl.text) ?? 0,

        // Low Cart
        'low_cart_enabled': _lowCartEnabled,
        'low_cart_threshold': double.tryParse(_lowCartThresholdCtrl.text) ?? 0,
        'low_cart_fee': double.tryParse(_lowCartFeeCtrl.text) ?? 0,

        // Platform
        'platform_fee_enabled': _platformFeeEnabled,
        'platform_fee_type': _platformFeeType,
        'platform_fee_value': double.tryParse(_platformFeeValueCtrl.text) ?? 0,

        // First Order
        'first_order_free_delivery_enabled': _firstOrderFreeDelivery,
        'first_order_low_cart_waived': _firstOrderDetailedWaiver,
        
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee settings saved successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateInputs() {
    // Add simple validation
    return true; 
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configure Fees',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.vendorName,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSectionCard(
                      title: 'Delivery Rules',
                      icon: Icons.local_shipping_outlined,
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            'Enable Free Delivery Threshold',
                            'Waive delivery fee above certain amount',
                            _freeDeliveryEnabled,
                            (val) => setState(() => _freeDeliveryEnabled = val),
                          ),
                          if (_freeDeliveryEnabled) ...[
                            const SizedBox(height: 16),
                            _buildTextField(_freeDeliveryThresholdCtrl, 'Free Delivery Above', 'e.g., 249'),
                          ],
                          const SizedBox(height: 16),
                          _buildTextField(_standardDeliveryFeeCtrl, 'Fallback Standard Fee', 'Used if no zone found'),
                          
                          const Divider(height: 32),
                          const Text("Instant Delivery Rules", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),

                          _buildSwitchTile(
                            'Enable Free Instant Delivery',
                            'Waive instant fee above threshold',
                            _freeInstantDeliveryEnabled,
                            (val) => setState(() => _freeInstantDeliveryEnabled = val),
                          ),
                          if (_freeInstantDeliveryEnabled) ...[
                            const SizedBox(height: 16),
                            _buildTextField(_freeInstantDeliveryThresholdCtrl, 'Free Instant Above', 'e.g., 1000'),
                          ],
                          const SizedBox(height: 16),
                          _buildTextField(_instantDeliveryFeeCtrl, 'Fallback Instant Fee', 'Used if no zone found'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Low Cart Fee',
                      icon: Icons.shopping_basket_outlined,
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            'Enable Low Cart Fee',
                            'Charge extra for small orders',
                            _lowCartEnabled,
                            (val) => setState(() => _lowCartEnabled = val),
                          ),
                          if (_lowCartEnabled) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildTextField(_lowCartThresholdCtrl, 'Below Amount', 'e.g., 199')),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTextField(_lowCartFeeCtrl, 'Add Fee', 'e.g., 15')),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Platform Fee',
                      icon: Icons.dns_outlined,
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            'Enable Platform Fee',
                            'Small fee for app usage',
                            _platformFeeEnabled,
                            (val) => setState(() => _platformFeeEnabled = val),
                          ),
                          if (_platformFeeEnabled) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _platformFeeType,
                                    decoration: const InputDecoration(
                                      labelText: 'Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                                      DropdownMenuItem(value: 'percent', child: Text('Percentage (%)')),
                                    ],
                                    onChanged: (val) => setState(() => _platformFeeType = val!),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    _platformFeeValueCtrl, 
                                    'Value', 
                                    _platformFeeType == 'fixed' ? 'Amount' : 'Percentage',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'First Order offers',
                      icon: Icons.card_giftcard,
                      color: Colors.purple.shade50,
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            'First Order Free Delivery',
                            'Waive delivery fee for new customers',
                            _firstOrderFreeDelivery,
                            (val) => setState(() => _firstOrderFreeDelivery = val),
                          ),
                          _buildSwitchTile(
                            'Waive Low Cart Fee',
                            'Also waive low cart fee for first order',
                            _firstOrderDetailedWaiver,
                            (val) => setState(() => _firstOrderDetailedWaiver = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[800]),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF0D9759),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
    );
  }
}
