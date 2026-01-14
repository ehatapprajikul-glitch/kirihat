import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kirihat_suite/firebase_options.dart'; // Adjust path if needed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    // 1. Fetch latest order
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      print('--- Latest Order Dump ---');
      print('Order ID: ${data['order_id']}');
      print('Vendor ID: ${data['vendor_id']} (Type: ${data['vendor_id'].runtimeType})');
      print('Status: ${data['status']}');
      print('Doc ID: ${snapshot.docs.first.id}');
      print('-------------------------');
      
      if (data['vendor_id'] == null) {
        print('CRITICAL: vendor_id is NULL');
      }
    } else {
      print('No orders found.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
