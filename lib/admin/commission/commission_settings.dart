import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommissionSettings extends StatefulWidget {
  const CommissionSettings({super.key});

  @override
  State<CommissionSettings> createState() => _CommissionSettingsState();
}

class _CommissionSettingsState extends State<CommissionSettings> {
  final _baseCommissionController = TextEditingController();
  final _distanceRateController = TextEditingController();
  final _deliveryFeeShareController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGlobalSettings();
  }

  Future<void> _loadGlobalSettings() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('platform_settings')
          .doc('commission')
          .get();

      if (doc.exists) {
        var data = doc.data()!;
        _baseCommissionController.text = (data['base_commission'] ?? 30).toString();
        _distanceRateController.text = (data['distance_rate'] ?? 10).toString();
        _deliveryFeeShareController.text = (data['delivery_fee_share'] ?? 0.5).toString();
      } else {
        // Set defaults
        _baseCommissionController.text = '30';
        _distanceRateController.text = '10';
        _deliveryFeeShareController.text = '0.5';
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _baseCommissionController.dispose();
    _distanceRateController.dispose();
    _deliveryFeeShareController.dispose();
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
            'Commission Configuration',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure how riders earn commissions from deliveries',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 32),

          // Global Settings Card
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
                Row(
                  children: [
                    const Icon(Icons.settings, color: Color(0xFF0D9759)),
                    const SizedBox(width: 12),
                    const Text(
                      'Global Commission Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Base Commission
                TextField(
                  controller: _baseCommissionController,
                  decoration: const InputDecoration(
                    labelText: 'Base Commission (₹)',
                    hintText: 'Fixed amount per delivery',
                    border: OutlineInputBorder(),
                    helperText: 'Flat rate given to rider for every delivery',
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 16),

                // Distance Rate
                TextField(
                  controller: _distanceRateController,
                  decoration: const InputDecoration(
                    labelText: 'Distance Rate (₹/km)',
                    hintText: 'Per kilometer rate',
                    border: OutlineInputBorder(),
                    helperText: 'Additional earning per kilometer traveled',
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 16),

                // Delivery Fee Share
                TextField(
                  controller: _deliveryFeeShareController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Fee Share (0-1)',
                    hintText: '0.5 = 50% of delivery fee',
                    border: OutlineInputBorder(),
                    helperText: 'Portion of delivery fee shared with rider',
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 24),

                // Example Calculation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Example Calculation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _calculateExample(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

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
                        : const Text('SAVE GLOBAL SETTINGS', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Vendor-Specific Overrides
          const Text(
            'Vendor-Specific Commission',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Override global settings for specific vendors',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('vendors').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('No vendors yet')),
                );
              }

              return Container(
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
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildVendorCommissionTile(doc.id, data);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCommissionTile(String vendorId, Map<String, dynamic> vendorData) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF0D9759),
        child: Icon(Icons.store, color: Colors.white),
      ),
      title: Text(vendorData['name'] ?? 'Unknown Vendor'),
      subtitle: Text(vendorData['email'] ?? ''),
      trailing: TextButton(
        onPressed: () => _showVendorCommissionDialog(vendorId, vendorData['name']),
        child: const Text('Configure'),
      ),
    );
  }

  String _calculateExample() {
    try {
      double base = double.parse(_baseCommissionController.text);
      double rate = double.parse(_distanceRateController.text);
      double distance = 5.0; // Example 5km
      double deliveryFee = 40.0; // Example delivery fee
      double share = double.parse(_deliveryFeeShareController.text);

      double total = base + (rate * distance) + (deliveryFee * share);

      return 'For a 5km delivery with ₹40 delivery fee:\n'
          'Base: ₹$base + Distance: ₹${rate * distance} (₹$rate × 5km) + '
          'Delivery Fee Share: ₹${(deliveryFee * share).toStringAsFixed(2)} (${(share * 100).toInt()}% of ₹$deliveryFee)\n'
          '= Rider Earns: ₹${total.toStringAsFixed(2)}';
    } catch (e) {
      return 'Enter valid numbers to see example';
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('platform_settings')
          .doc('commission')
          .set({
        'base_commission': num.parse(_baseCommissionController.text),
        'distance_rate': num.parse(_distanceRateController.text),
        'delivery_fee_share': num.parse(_deliveryFeeShareController.text),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission settings saved successfully!'),
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

  void _showVendorCommissionDialog(String vendorId, String vendorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commission for $vendorName'),
        content: const Text(
          'Vendor-specific commission overrides coming in next update!',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
