import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kirihat_core/kirihat_core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String _dutyStatus = 'offline'; // online, busy, offline
  String? _realRiderId;
  RiderModel? _riderData;

  @override
  void initState() {
    super.initState();
    _findRiderProfile();
  }

  bool _isLoadingProfile = true;

  Future<void> _findRiderProfile() async {
    if (user?.email == null) return;
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('riders')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        setState(() { 
          _realRiderId = doc.id;
          _riderData = RiderModel.fromFirestore(doc);
          _dutyStatus = _riderData?.dutyStatus ?? 'offline';
          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const statusColors = <String, MaterialColor>{
      'online': Colors.green,
      'busy': Colors.orange,
      'offline': Colors.grey,
    };
    final MaterialColor statusColor = statusColors[_dutyStatus] ?? Colors.grey;

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: statusColor[700],
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rider Dashboard",
                style: TextStyle(fontSize: 14, color: Colors.white70)),
            Text(user?.displayName ?? "Duty Mode",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        actions: [
          _buildDutyStatusToggle(),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // STATUS BANNER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(
                        _dutyStatus == 'online' ? Icons.power_settings_new : 
                        (_dutyStatus == 'busy' ? Icons.notifications_active : Icons.power_off),
                        color: statusColor,
                        size: 30),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Status",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14)),
                      Text(_dutyStatus.toUpperCase(),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // LIVE METRICS STREAM
            if (_realRiderId != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('rider_id', isEqualTo: _realRiderId)
                    .where('status', isEqualTo: 'Delivered')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();

                  var docs = snapshot.data!.docs;

                  // --- SYNCED MATH WITH HISTORY TAB ---
                  double lifetimeEarnings = 0;
                  double currentDebt = 0;
                  int trips = docs.length;

                  for (var doc in docs) {
                    var data = doc.data() as Map<String, dynamic>;

                    // 1. Earnings (Commission Only, as per History Tab)
                    double commission =
                        (data['rider_commission'] ?? 0).toDouble();
                    double deliveryFee = (data['delivery_fee'] ?? 0).toDouble();

                    lifetimeEarnings += commission;

                    // 2. Debt Calculation (Include Delivery Fee logic)
                    if (data['is_settled'] != true) {
                      double cashCollected = (data['payment_method'] == 'COD')
                          ? (data['total_amount'] ?? 0).toDouble()
                          : 0;
                      double paidSoFar =
                          (data['amount_paid_so_far'] ?? 0).toDouble();

                      // Debt = Cash - (Commission + DeliveryFee) - Paid
                      double orderDebt =
                          (cashCollected - (commission + deliveryFee)) -
                              paidSoFar;

                      if (orderDebt > 0) currentDebt += orderDebt;
                    }
                  }

                  return Column(
                    children: [
                      // ROW 1: Earnings & Trips
                      Row(
                        children: [
                          _buildStatCard(
                              "Total Earnings",
                              CurrencyHelper.format(lifetimeEarnings),
                              Icons.account_balance_wallet,
                              Colors.purple),
                          const SizedBox(width: 15),
                          _buildStatCard("Trips Done", "$trips",
                              Icons.check_circle, Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // ROW 2: CASH TO DEPOSIT (Cleaned Up)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.redAccent.shade700,
                            Colors.redAccent.shade400
                          ]),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text("CASH TO DEPOSIT",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                            const SizedBox(height: 5),
                            Text(CurrencyHelper.format(currentDebt),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            const Text("Return this amount to Vendor",
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              Center(
                  child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _isLoadingProfile 
                    ? const Text("Loading Profile...")
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text("Rider Profile Not Found", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text("Please contact admin to initialize your account.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _findRiderProfile,
                            child: const Text("Retry"),
                          )
                        ],
                      ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyStatusToggle() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'online' && _dutyStatus != 'online') {
          _verifyPresenceAtVendor();
        } else if (value != _dutyStatus) {
          _updateDutyStatus(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'online', child: Text('Go Online')),
        const PopupMenuItem(value: 'busy', child: Text('Mark Busy')),
        const PopupMenuItem(value: 'offline', child: Text('Go Offline')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _dutyStatus == 'online' ? Colors.greenAccent 
                      : (_dutyStatus == 'busy' ? Colors.orangeAccent : Colors.grey),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _dutyStatus.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Future<void> _updateDutyStatus(String status) async {
    if (_realRiderId == null) return;
    try {
      await FirebaseFirestore.instance.collection('riders').doc(_realRiderId).update({
        'duty_status': status,
        'is_online': status == 'online',
        'last_active': FieldValue.serverTimestamp(),
      });
      setState(() => _dutyStatus = status);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _verifyPresenceAtVendor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Presence'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              const Text('Scan the QR code at the vendor location to go online.'),
              const SizedBox(height: 20),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final rawValue = barcode.rawValue;
                      debugPrint("Scanned QR: $rawValue");
                      if (rawValue == null) continue;

                      // Parse dynamic QR: vendorId|timestamp
                      final parts = rawValue.split('|');
                      final scannedVendorId = parts[0];
                      debugPrint("Parsed VendorID: $scannedVendorId, Target: ${_riderData?.vendorId}");
                      
                      if (scannedVendorId == _riderData?.vendorId) {
                        // Validate timestamp if present
                        if (parts.length > 1) {
                          try {
                            final qrTime = DateTime.parse(parts[1]);
                            final diff = DateTime.now().difference(qrTime).inMinutes.abs();
                            debugPrint("QR Time: $qrTime, Diff: $diff mins");
                            
                            if (diff > 65) {
                              debugPrint("QR Expired");
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('QR Code expired! Please scan a fresh code.'), backgroundColor: Colors.red),
                              );
                              return;
                            }
                          } catch (e) {
                            debugPrint("Error parsing QR timestamp: $e");
                          }
                        }

                        debugPrint("Verification Successful!");
                        Navigator.pop(context);
                        _updateDutyStatus('online');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verified! You are now online.'), backgroundColor: Colors.green),
                        );
                        return;
                      } else {
                        debugPrint("VendorID Mismatch!");
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Mismatch! Correct Vendor ID: ${_riderData?.vendorId?.substring(0,5)}...'),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 20,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 15),
            Text(value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
