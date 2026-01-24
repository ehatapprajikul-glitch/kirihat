import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

class CommissionSettings extends StatefulWidget {
  const CommissionSettings({super.key});

  @override
  State<CommissionSettings> createState() => _CommissionSettingsState();
}

class _CommissionSettingsState extends State<CommissionSettings> {
  // Tab 1: Global Rates
  final _baseCommissionController = TextEditingController();
  final _distanceRateController = TextEditingController();
  final _deliveryFeeShareController = TextEditingController();

  // Tab 2: Rider Rules (New)
  final _basePayXController = TextEditingController();
  final _extraPayYController = TextEditingController();
  final _maxOrdersController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    try {
      // Load 'commission' doc
      var commDoc = await FirebaseFirestore.instance
          .collection('platform_settings')
          .doc('commission')
          .get();

      // Load 'rider_rules' doc (new)
      var rulesDoc = await FirebaseFirestore.instance
          .collection('platform_settings')
          .doc('rider_rules')
          .get();

      if (commDoc.exists) {
        var data = commDoc.data()!;
        _baseCommissionController.text = (data['base_commission'] ?? 30).toString();
        _distanceRateController.text = (data['distance_rate'] ?? 10).toString();
        _deliveryFeeShareController.text = (data['delivery_fee_share'] ?? 0.5).toString();
      } else {
        _baseCommissionController.text = '30';
        _distanceRateController.text = '10';
        _deliveryFeeShareController.text = '0.5';
      }

      if (rulesDoc.exists) {
        var data = rulesDoc.data()!;
        _basePayXController.text = (data['base_pay_x'] ?? 40).toString();
        _extraPayYController.text = (data['extra_pay_y'] ?? 20).toString();
        _maxOrdersController.text = (data['max_orders_per_trip'] ?? 5).toString();
      } else {
        _basePayXController.text = '40';
        _extraPayYController.text = '20';
        _maxOrdersController.text = '5';
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading settings: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _baseCommissionController.dispose();
    _distanceRateController.dispose();
    _deliveryFeeShareController.dispose();
    _basePayXController.dispose();
    _extraPayYController.dispose();
    _maxOrdersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commission & Rules',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage rider earnings, batch logic, and vendor overrides',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TabBar(
              labelColor: const Color(0xFF0D9759),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF0D9759),
              tabs: const [
                Tab(text: "Commission Rates"),
                Tab(text: "Rider Rules"),
                Tab(text: "Vendor Overrides"),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: TabBarView(
              children: [
                _buildCommissionRatesTab(),
                _buildRiderRulesTab(),
                _buildVendorOverridesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: COMMISSION RATES (Existing Global Settings) ---
  Widget _buildCommissionRatesTab() {
    return SingleChildScrollView(
      child: Container(
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
            const Text('Global Commission Calculation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _baseCommissionController,
              decoration: const InputDecoration(labelText: 'Base Commission', border: OutlineInputBorder(), helperText: 'Flat earning per delivery'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _distanceRateController,
              decoration: const InputDecoration(labelText: 'Distance Rate (/km)', border: OutlineInputBorder(), helperText: 'Additional earning per km'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deliveryFeeShareController,
              decoration: const InputDecoration(labelText: 'Delivery Fee Share (0-1)', border: OutlineInputBorder(), helperText: '0.5 = 50% of fee goes to rider'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _buildExampleCalculation(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _saveSettings('commission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE RATES'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: RIDER RULES (New - Migrated from Vendor App) ---
  Widget _buildRiderRulesTab() {
    return SingleChildScrollView(
      child: Container(
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
             const Text('Batch Order & Payout Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const Text('Define how much riders earn for single vs batch orders', style: TextStyle(color: Colors.grey)),
             const SizedBox(height: 24),
             
             Row(
               children: [
                 Expanded(
                   child: TextField(
                     controller: _basePayXController,
                     decoration: const InputDecoration(labelText: 'Base Pay X (1st Order)', border: OutlineInputBorder()),
                     keyboardType: TextInputType.number,
                   ),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: TextField(
                     controller: _extraPayYController,
                     decoration: const InputDecoration(labelText: 'Extra Pay Y (Addt\'l Orders)', border: OutlineInputBorder()),
                     keyboardType: TextInputType.number,
                   ),
                 ),
               ],
             ),
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 8.0),
               child: Text('Example: If X=40 and Y=20, a trip with 2 orders pays ₹60 (40+20).', style: TextStyle(fontSize: 12, color: Colors.grey)),
             ),
             
             const SizedBox(height: 24),
             TextField(
               controller: _maxOrdersController,
               decoration: const InputDecoration(labelText: 'Max Orders Per Trip', border: OutlineInputBorder(), helperText: 'Limit batch size for riders'),
               keyboardType: TextInputType.number,
             ),

             const SizedBox(height: 32),
             SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _saveSettings('rider_rules'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE RULES'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 3: VENDOR OVERRIDES (Existing) ---
  Widget _buildVendorOverridesTab() {
     return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vendors').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No vendors yet'));
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: ListView.separated(
            shrinkWrap: true,
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
    );
  }

  Widget _buildVendorCommissionTile(String vendorId, Map<String, dynamic> vendorData) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF0D9759),
        child: Icon(Icons.store, color: Colors.white),
      ),
      title: Text(vendorData['business_name'] ?? vendorData['shop_name'] ?? 'Unknown Vendor'),
      subtitle: Text(vendorData['email'] ?? ''),
      trailing: TextButton(
        onPressed: () => _showVendorCommissionDialog(vendorId, vendorData['business_name'] ?? vendorData['shop_name'] ?? 'Unknown Vendor'),
        child: const Text('Configure'),
      ),
    );
  }

  Widget _buildExampleCalculation() {
     try {
      double base = double.tryParse(_baseCommissionController.text) ?? 0;
      double rate = double.tryParse(_distanceRateController.text) ?? 0;
      double distance = 5.0; 
      double deliveryFee = 40.0;
      double share = double.tryParse(_deliveryFeeShareController.text) ?? 0;
      double total = base + (rate * distance) + (deliveryFee * share);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(
          'Example (5km trip, ${CurrencyHelper.format(deliveryFee)} fee):\n'
          'Base: ${CurrencyHelper.format(base)} + Distance: ${CurrencyHelper.format(rate * distance)} + Share: ${CurrencyHelper.format(deliveryFee * share)}\n'
          '= Total: ${CurrencyHelper.format(total)}',
          style: const TextStyle(fontSize: 13),
        ),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  Future<void> _saveSettings(String docId) async {
    setState(() => _isSaving = true);
    try {
      Map<String, dynamic> data = {};
      
      if (docId == 'commission') {
         data = {
          'base_commission': num.parse(_baseCommissionController.text),
          'distance_rate': num.parse(_distanceRateController.text),
          'delivery_fee_share': num.parse(_deliveryFeeShareController.text),
        };
      } else if (docId == 'rider_rules') {
        data = {
          'base_pay_x': num.parse(_basePayXController.text),
          'extra_pay_y': num.parse(_extraPayYController.text),
          'max_orders_per_trip': int.parse(_maxOrdersController.text),
        };
      }
      
      data['updated_at'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.collection('platform_settings').doc(docId).set(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
        content: const Text('Vendor-specific commission overrides coming in next update!', style: TextStyle(fontSize: 14)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))],
      ),
    );
  }
}
