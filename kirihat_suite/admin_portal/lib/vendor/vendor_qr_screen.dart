import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorQRScreen extends StatefulWidget {
  const VendorQRScreen({super.key});

  @override
  State<VendorQRScreen> createState() => _VendorQRScreenState();
}

class _VendorQRScreenState extends State<VendorQRScreen> {
  Timer? _timer;
  late String _vendorId;
  String _qrData = '';

  @override
  void initState() {
    super.initState();
    _vendorId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _generateQrData();
    // Refresh QR data every 1 hour
    _timer = Timer.periodic(const Duration(hours: 1), (timer) {
      if (mounted) {
        setState(() {
          _generateQrData();
        });
      }
    });
  }

  void _generateQrData() {
    final now = DateTime.now();
    // Round to the start of the hour for consistency
    final roundedTime = DateTime(now.year, now.month, now.day, now.hour);
    _qrData = '$_vendorId|${roundedTime.toIso8601String()}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Authentication QR'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Rider Check-in QR',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Riders must scan this QR to switch their status to "Online".\n'
                'This QR is valid for 1 hour. Please reprint if needed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 280.0,
                  gapless: false,
                  embeddedImage: const AssetImage('assets/favicon.png'),
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(40, 40),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Vendor ID: $_vendorId',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  // Print functionality could be added here
                },
                icon: const Icon(Icons.print),
                label: const Text('Print QR Label'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
