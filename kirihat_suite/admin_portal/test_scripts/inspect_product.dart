import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  String productId = "gOQUkJOgVfDesXbE3EBO";

  print("Inspecting Product: $productId");

  try {
    var doc = await FirebaseFirestore.instance.collection('master_products').doc(productId).get();
    if (doc.exists) {
      print("Found Product!");
      print("Data: ${doc.data()}");
      if (doc.data()!.containsKey('seller_id')) {
        print("✅ seller_id matches: ${doc.data()!['seller_id']}");
      } else {
        print("❌ seller_id MSSING from document!");
      }
    } else {
      print("Product not found.");
    }
  } catch (e) {
    print("Error: $e");
  }
  
  // Also check if any products have seller_id
  print("\nChecking random products...");
  var snap = await FirebaseFirestore.instance.collection('master_products').limit(3).get();
  for(var d in snap.docs) {
     print("ID: ${d.id}, Has seller_id: ${d.data().containsKey('seller_id')}");
  }
}
