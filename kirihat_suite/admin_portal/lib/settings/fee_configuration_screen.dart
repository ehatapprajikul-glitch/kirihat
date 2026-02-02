import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/models/fee_configuration_model.dart';
import 'package:kirihat_core/services/fee_configuration_service.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

/// Professional fee configuration screen for admins
/// Allows customization of all platform fees
class FeeConfigurationScreen extends StatefulWidget {
  const FeeConfigurationScreen({super.key});

  @override
  State<FeeConfigurationScreen> createState() => _FeeConfigurationScreenState();
}

class _FeeConfigurationScreenState extends State<FeeConfigurationScreen> {
  final FeeConfigurationService _feeService = FeeConfigurationService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;
  FeeConfigurationModel? _currentConfig;
  
  // Controllers
  late TextEditingController _platformFeeCtrl;
  late TextEditingController _deliveryFeeCtrl;
  late TextEditingController _rushDeliveryCtrl;
  late TextEditingController _freeDeliveryThresholdCtrl;
  late TextEditingController _returnFeeCtrl;
  late TextEditingController _restockingFeeCtrl;
  late TextEditingController _paymentGatewayPercentCtrl;
  late TextEditingController _paymentGatewayFixedCtrl;
  late TextEditingController _cancellationFeeCtrl;
  late TextEditingController _packagingFeeCtrl;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadConfiguration();
  }

  void _initializeControllers() {
    _platformFeeCtrl = TextEditingController();
    _deliveryFeeCtrl = TextEditingController();
    _rushDeliveryCtrl = TextEditingController();
    _freeDeliveryThresholdCtrl = TextEditingController();
    _returnFeeCtrl = TextEditingController();
    _restockingFeeCtrl = TextEditingController();
    _paymentGatewayPercentCtrl = TextEditingController();
    _paymentGatewayFixedCtrl = TextEditingController();
    _cancellationFeeCtrl = TextEditingController();
    _packagingFeeCtrl = TextEditingController();
  }

  Future<void> _loadConfiguration() async {
    setState(() => _isLoading = true);
    
    try {
      final config = await _feeService.getFeeConfiguration();
      
      if (mounted) {
        setState(() {
          _currentConfig = config;
          _populateFields(config);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading configuration: $e')),
        );
      }
    }
  }

  void _populateFields(FeeConfigurationModel config) {
    _platformFeeCtrl.text = config.platformFeePercentage.toString();
    _deliveryFeeCtrl.text = config.deliveryFeeDefault.toString();
    _rushDeliveryCtrl.text = config.rushDeliveryFee.toString();
    _freeDeliveryThresholdCtrl.text = config.freeDeliveryThreshold.toString();
    _returnFeeCtrl.text = config.returnProcessingFee.toString();
    _restockingFeeCtrl.text = config.restockingFeePercentage.toString();
    _paymentGatewayPercentCtrl.text = config.paymentGatewayFeePercentage.toString();
    _paymentGatewayFixedCtrl.text = config.paymentGatewayFixedFee.toString();
    _cancellationFeeCtrl.text = config.cancellationFee.toString();
    _packagingFeeCtrl.text = config.packagingFee.toString();
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final updatedConfig = FeeConfigurationModel(
        id: 'default',
        platformFeePercentage: double.parse(_platformFeeCtrl.text),
        deliveryFeeDefault: double.parse(_deliveryFeeCtrl.text),
        rushDeliveryFee: double.parse(_rushDeliveryCtrl.text),
        freeDeliveryThreshold: double.parse(_freeDeliveryThresholdCtrl.text),
        returnProcessingFee: double.parse(_returnFeeCtrl.text),
        restockingFeePercentage: double.parse(_restockingFeeCtrl.text),
        paymentGatewayFeePercentage: double.parse(_paymentGatewayPercentCtrl.text),
        paymentGatewayFixedFee: double.parse(_paymentGatewayFixedCtrl.text),
        cancellationFee: double.parse(_cancellationFeeCtrl.text),
        packagingFee: double.parse(_packagingFeeCtrl.text),
        lastUpdatedAt: DateTime.now(),
        lastUpdatedBy: FirebaseAuth.instance.currentUser?.uid,
      );

      final success = await _feeService.updateFeeConfiguration(
        updatedConfig,
        FirebaseAuth.instance.currentUser?.uid ?? 'admin',
      );

      if (mounted) {
        setState(() => _isSaving = false);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fee configuration updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadConfiguration(); // Refresh
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update configuration'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default'),
        content: const Text('Are you sure you want to reset all fees to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    
    final success = await _feeService.resetToDefault(
      FirebaseAuth.instance.currentUser?.uid ?? 'admin',
    );

    if (mounted) {
      setState(() => _isSaving = false);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset to default configuration')),
        );
        _loadConfiguration();
      }
    }
  }

  @override
  void dispose() {
    _platformFeeCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _rushDeliveryCtrl.dispose();
    _freeDeliveryThresholdCtrl.dispose();
    _returnFeeCtrl.dispose();
    _restockingFeeCtrl.dispose();
    _paymentGatewayPercentCtrl.dispose();
    _paymentGatewayFixedCtrl.dispose();
    _cancellationFeeCtrl.dispose();
    _packagingFeeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Fee Configuration'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfiguration,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefault,
            tooltip: 'Reset to Default',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBanner(),
                    const SizedBox(height: 24),
                    _buildCommissionSection(),
                    const SizedBox(height: 24),
                    _buildDeliverySection(),
                    const SizedBox(height: 24),
                    _buildReturnSection(),
                    const SizedBox(height: 24),
                    _buildPaymentSection(),
                    const SizedBox(height: 24),
                    _buildOtherFeesSection(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    if (_currentConfig != null) _buildPreview(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'These fees will be applied across the entire platform. Changes take effect immediately.',
              style: TextStyle(color: Colors.blue[900], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionSection() {
    return _buildSection(
      title: 'Platform Commission',
      icon: Icons.percent,
      color: Colors.green,
      children: [
        _buildPercentageField(
          controller: _platformFeeCtrl,
          label: 'Platform Fee (%)',
          hint: 'Commission charged to sellers',
          helperText: 'Percentage of order value charged as commission',
        ),
      ],
    );
  }

  Widget _buildDeliverySection() {
    return _buildSection(
      title: 'Delivery Fees',
      icon: Icons.local_shipping,
      color: Colors.blue,
      children: [
        _buildCurrencyField(
          controller: _deliveryFeeCtrl,
          label: 'Standard Delivery Fee',
          hint: 'Default delivery charge',
        ),
        const SizedBox(height: 16),
        _buildCurrencyField(
          controller: _rushDeliveryCtrl,
          label: 'Rush/Express Delivery Fee',
          hint: 'Express delivery charge',
        ),
        const SizedBox(height: 16),
        _buildCurrencyField(
          controller: _freeDeliveryThresholdCtrl,
          label: 'Free Delivery Threshold',
          hint: 'Min order value for free delivery',
          helperText: 'Orders above this value get free delivery',
        ),
      ],
    );
  }

  Widget _buildReturnSection() {
    return _buildSection(
      title: 'Return & Refund',
      icon: Icons.assignment_return,
      color: Colors.orange,
      children: [
        _buildCurrencyField(
          controller: _returnFeeCtrl,
          label: 'Return Processing Fee',
          hint: 'Fee for processing returns',
        ),
        const SizedBox(height: 16),
        _buildPercentageField(
          controller: _restockingFeeCtrl,
          label: 'Restocking Fee (%)',
          hint: 'Percentage charged on returned items',
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return _buildSection(
      title: 'Payment Gateway',
      icon: Icons.payment,
      color: Colors.purple,
      children: [
        _buildPercentageField(
          controller: _paymentGatewayPercentCtrl,
          label: 'Gateway Fee (%)',
          hint: 'Percentage charged by payment processor',
        ),
        const SizedBox(height: 16),
        _buildCurrencyField(
          controller: _paymentGatewayFixedCtrl,
          label: 'Fixed Transaction Fee',
          hint: 'Fixed fee per transaction',
        ),
      ],
    );
  }

  Widget _buildOtherFeesSection() {
    return _buildSection(
      title: 'Other Fees',
      icon: Icons.more_horiz,
      color: Colors.teal,
      children: [
        _buildCurrencyField(
          controller: _cancellationFeeCtrl,
          label: 'Cancellation Fee',
          hint: 'Fee for order cancellation',
        ),
        const SizedBox(height: 16),
        _buildCurrencyField(
          controller: _packagingFeeCtrl,
          label: 'Packaging Fee',
          hint: 'Additional packaging charge',
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCurrencyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixText: '₹ ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        if (double.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        if (double.parse(value) < 0) {
          return 'Value cannot be negative';
        }
        return null;
      },
    );
  }

  Widget _buildPercentageField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        suffixText: '%',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        final num = double.tryParse(value);
        if (num == null) {
          return 'Please enter a valid number';
        }
        if (num < 0 || num > 100) {
          return 'Percentage must be between 0 and 100';
        }
        return null;
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _resetToDefault,
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Default'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveConfiguration,
            icon: _isSaving 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9759),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final config = _currentConfig!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fee Preview Example',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          const Text('Order Value: ₹1,000', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          _buildPreviewRow(
            'Platform Fee',
            config.calculatePlatformFee(1000),
          ),
          _buildPreviewRow(
            'Delivery Fee',
            config.getDeliveryFee(orderValue: 1000),
          ),
          _buildPreviewRow(
            'Payment Gateway Fee',
            config.calculatePaymentGatewayFee(1000),
          ),
          _buildPreviewRow(
            'Packaging Fee',
            config.packagingFee,
          ),
          const Divider(height: 16),
          _buildPreviewRow(
            'Total Fees',
            config.calculatePlatformFee(1000) +
                config.getDeliveryFee(orderValue: 1000) +
                config.calculatePaymentGatewayFee(1000) +
                config.packagingFee,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            CurrencyHelper.format(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF0D9759),
            ),
          ),
        ],
      ),
    );
  }
}
