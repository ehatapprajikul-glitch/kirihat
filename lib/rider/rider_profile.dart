import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_screen.dart';
import 'rider_earnings.dart';
import 'rider_history.dart';

class RiderProfileScreen extends StatelessWidget {
  const RiderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar:
          AppBar(title: const Text("My Profile"), backgroundColor: Colors.blue),
      body: SingleChildScrollView(
        child: FutureBuilder<QuerySnapshot>(
          // Look up rider by Email
          future: FirebaseFirestore.instance
              .collection('riders')
              .where('email', isEqualTo: user?.email)
              .limit(1)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(50.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // Default data from Auth if Rider doc not linked yet
            String name = user?.displayName ?? "Rider";
            String phone = "N/A";
            String bike = "Not Registered";

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              var data =
                  snapshot.data!.docs.first.data() as Map<String, dynamic>;
              name = data['name'] ?? name;
              phone = data['phone'] ?? phone;
              bike = data['vehicle_no'] ?? bike;
            }

            return Column(
              children: [
                const SizedBox(height: 30),
                const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 60, color: Colors.white)),
                const SizedBox(height: 10),
                Text(name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                Text(user?.email ?? "",
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text("Phone"),
                    subtitle: Text(phone)),
                ListTile(
                    leading: const Icon(Icons.motorcycle),
                    title: const Text("Vehicle Details"),
                    subtitle: Text(bike)),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet,
                      color: Colors.blue),
                  title: const Text("My Earnings & Wallet"),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RiderEarningsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: const Text("Delivery History"),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RiderHistoryScreen()));
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text("Logout",
                          style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (r) => false);
                      },
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}
