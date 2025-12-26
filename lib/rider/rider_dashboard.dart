
// Import necessary Flutter material components.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart'; // Import for date formatting

// -------------------------------------------------------------------
// Main Rider Dashboard Widget (Stateful)
// -------------------------------------------------------------------
class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});

  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  // This integer will keep track of the currently selected tab index.
  int _currentIndex = 0;

  // A list of the widgets (screens) that correspond to each tab.
  final List<Widget> _tabs = [
    const NewTasksScreen(),   // Tab 0: New Tasks
    const RiderHistoryScreen(), // Tab 1: History
    const RiderProfileScreen(), // Tab 2: Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body of the scaffold will display the widget from the _tabs list
      // that corresponds to the currently selected index.
      body: _tabs[_currentIndex],
      
      // The BottomNavigationBar allows switching between the main screens.
      bottomNavigationBar: NavigationBar(
        // The selectedIndex determines which destination is currently highlighted.
        selectedIndex: _currentIndex,
        
        // This callback is triggered when a user taps on a navigation destination.
        // We update the state to change the _currentIndex, which rebuilds the
        // widget with the new screen in the body.
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        
        // Define the appearance of the navigation bar.
        backgroundColor: Colors.white,
        elevation: 5,
        indicatorColor: Colors.green[100], // Color of the selection indicator

        // These are the individual tabs (destinations) in the navigation bar.
        destinations: const [
          // TAB 1: NEW TASKS
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping, color: Colors.green),
            label: 'New Tasks',
          ),
          
          // TAB 2: HISTORY
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Colors.orange),
            label: 'History',
          ),
          
          // TAB 3: PROFILE
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.blue),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// Screen for "New Tasks" - Now with Firestore Logic
// -------------------------------------------------------------------
class NewTasksScreen extends StatelessWidget {
  const NewTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Delivery Tasks"),
        backgroundColor: Colors.orange[100],
      ),
      // Use a StreamBuilder to listen for real-time updates from Firestore.
      body: StreamBuilder<QuerySnapshot>(
        // Set up the stream to listen to the 'orders' collection.
        // The .where() clause is the key to filtering.
        // It tells Firestore to only return documents where the 'status' field
        // is exactly equal to 'Shipped'.
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('status', isEqualTo: 'Shipped')
            .snapshots(),
        
        builder: (context, snapshot) {
          // Show a loading indicator while waiting for data.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Show an error message if something goes wrong.
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          // If there's no data or the query returns no documents, show a message.
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "No new tasks available.",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text("Orders ready for pickup will appear here."),
                ],
              ),
            );
          }

          // If we have data, build a list of cards for each order.
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              // Get the specific order document from the snapshot.
              final orderDoc = snapshot.data!.docs[index];
              // Extract the data from the document into a more usable Map.
              final orderData = orderDoc.data() as Map<String, dynamic>;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display Order ID
                      Text(
                        "Order ID: ${orderDoc.id}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Divider(),
                      // Display Customer Phone Number
                      Text("Customer Phone: ${orderData['customer_phone'] ?? 'N/A'}"),
                      const SizedBox(height: 5),
                      // Display Total Amount
                      Text(
                        "Total: ₹${orderData['total_amount'] ?? 0}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      // Button to mark the order as delivered
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text("Mark Delivered"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            // This is the logic to update the order status.
                            // We get a reference to the specific document using its ID
                            // and then call .update() to change the 'status' field.
                            FirebaseFirestore.instance
                                .collection('orders')
                                .doc(orderDoc.id)
                                .update({'status': 'Delivered'});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


// -------------------------------------------------------------------
// Screen for "History" - Now with Firestore Logic
// -------------------------------------------------------------------
class RiderHistoryScreen extends StatelessWidget {
  const RiderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery History"),
        backgroundColor: Colors.orange[100],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. Set up the stream to listen to the 'orders' collection.
        stream: FirebaseFirestore.instance
            .collection('orders')
            // 2. Filter for documents where 'status' is 'Delivered'.
            .where('status', isEqualTo: 'Delivered')
            // 3. Sort by the 'created_at' field in descending order (newest first).
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "No completed deliveries yet.",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // If we have data, build the list.
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final orderDoc = snapshot.data!.docs[index];
              final orderData = orderDoc.data() as Map<String, dynamic>;

              // Safely get the timestamp and format it.
              final Timestamp? timestamp = orderData['created_at'];
              String deliveredAt = "Date not available";
              if (timestamp != null) {
                // Using the intl package for clean date formatting.
                deliveredAt = DateFormat.yMMMd().add_jm().format(timestamp.toDate());
              }

              return ListTile(
                // Green check icon to indicate success.
                leading: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                // Display the Order ID.
                title: Text(
                  "Order ID: ${orderDoc.id}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                // Display the formatted delivery date and time.
                subtitle: Text("Delivered on: $deliveredAt"),
              );
            },
          );
        },
      ),
    );
  }
}


// -------------------------------------------------------------------
// Screen for "Profile" - With UI and Logout Logic
// -------------------------------------------------------------------
class RiderProfileScreen extends StatelessWidget {
  const RiderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current user from FirebaseAuth to display their email.
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.orange[100],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // A large circular avatar with a generic motorcycle icon.
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.green,
              child: Icon(Icons.motorcycle, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 15),
            
            // Display the current user's email.
            Text(
              user?.email ?? "rider@kirihat.com",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            // A simple status indicator for the rider.
            const Text(
              "Status: Verified Rider",
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
            
            // Use a Spacer to push the logout button to the bottom.
            const Spacer(),
            
            // A large, red logout button.
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  "Logout",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Red background for emphasis
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // When pressed, this calls the signOut method from FirebaseAuth.
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ),
            const SizedBox(height: 20), // Some padding at the bottom
          ],
        ),
      ),
    );
  }
}
