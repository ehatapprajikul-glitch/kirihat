import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataMonitoring extends StatefulWidget {
  const DataMonitoring({super.key});

  @override
  State<DataMonitoring> createState() => _DataMonitoringState();
}

class _DataMonitoringState extends State<DataMonitoring> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Access & Monitoring',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Access detailed customer and vendor data',
          style: TextStyle(color: Colors.grey[600]),
        ),

        const SizedBox(height: 24),

        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D9759),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0D9759),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Wishlists'),
            Tab(text: 'Active Carts'),
            Tab(text: 'All Products'),
            Tab(text: 'Earnings & Settlements'),
          ],
        ),

        const SizedBox(height: 16),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWishlistsView(),
              _buildCartsView(),
              _buildInventoryView(),
              _buildEarningsView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWishlistsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('wishlist').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No wishlist items'));
        }

        // Group by user
        Map<String, List<DocumentSnapshot>> wishlistsByUser = {};
        for (var doc in snapshot.data!.docs) {
          String userId = doc.reference.parent.parent!.id;
          if (!wishlistsByUser.containsKey(userId)) {
            wishlistsByUser[userId] = [];
          }
          wishlistsByUser[userId]!.add(doc);
        }

        return ListView.builder(
          itemCount: wishlistsByUser.length,
          itemBuilder: (context, index) {
            String userId = wishlistsByUser.keys.elementAt(index);
            List<DocumentSnapshot> items = wishlistsByUser[userId]!;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
              builder: (context, userDoc) {
                String userName = 'Unknown User';
                if (userDoc.hasData && userDoc.data!.exists) {
                  userName = (userDoc.data!.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.pink,
                      child: Text(userName[0].toUpperCase()),
                    ),
                    title: Text(userName),
                    subtitle: Text('${items.length} items in wishlist'),
                    children: items.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        dense: true,
                        leading: data['imageUrl'] != null
                            ? Image.network(data['imageUrl'], width: 40, height: 40, fit: BoxFit.cover)
                            : const Icon(Icons.image),
                        title: Text(data['name'] ?? 'Unknown'),
                        trailing: Text('₹${data['price'] ?? 0}'),
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCartsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('cart').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No active carts'));
        }

        // Group by user
        Map<String, List<DocumentSnapshot>> cartsByUser = {};
        for (var doc in snapshot.data!.docs) {
          String userId = doc.reference.parent.parent!.id;
          if (!cartsByUser.containsKey(userId)) {
            cartsByUser[userId] = [];
          }
          cartsByUser[userId]!.add(doc);
        }

        return ListView.builder(
          itemCount: cartsByUser.length,
          itemBuilder: (context, index) {
            String userId = cartsByUser.keys.elementAt(index);
            List<DocumentSnapshot> items = cartsByUser[userId]!;

            double cartValue = items.fold(0.0, (sum, doc) {
              var data = doc.data() as Map<String, dynamic>;
              int qty = (data['quantity'] ?? 0) as int;
              double price = ((data['price'] ?? 0) as num).toDouble();
              return sum + (qty * price);
            });

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
              builder: (context, userDoc) {
                String userName = 'Unknown User';
                String phone = '';
                if (userDoc.hasData && userDoc.data!.exists) {
                  var userData = userDoc.data!.data() as Map<String, dynamic>;
                  userName = userData['name'] ?? 'Unknown';
                  phone = userData['phone'] ?? '';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0D9759),
                      child: Text(userName[0].toUpperCase()),
                    ),
                    title: Text(userName),
                    subtitle: Text('${items.length} items • ₹${cartValue.toStringAsFixed(2)} • $phone'),
                    children: items.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      int qty = (data['quantity'] ?? 0) as int;
                      double price = ((data['price'] ?? 0) as num).toDouble();

                      return ListTile(
                        dense: true,
                        leading: data['imageUrl'] != null
                            ? Image.network(data['imageUrl'], width: 40, height: 40, fit: BoxFit.cover)
                            : const Icon(Icons.image),
                        title: Text(data['name'] ?? 'Unknown'),
                        subtitle: Text('Quantity: $qty'),
                        trailing: Text('₹${(price * qty).toStringAsFixed(2)}'),
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInventoryView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No products'));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Image')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Stock')),
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Status')),
            ],
            rows: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              int stock = (data['stock_quantity'] ?? 0) as int;
              bool isActive = data['isActive'] ?? true;

              return DataRow(
                cells: [
                  DataCell(
                    data['imageUrl'] != null
                        ? Image.network(data['imageUrl'], width: 40, height: 40, fit: BoxFit.cover)
                        : const Icon(Icons.image),
                  ),
                  DataCell(Text(data['name'] ?? 'N/A')),
                  DataCell(Text(data['category'] ?? 'N/A')),
                  DataCell(Text('₹${data['price'] ?? 0}')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stock > 10 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        stock.toString(),
                        style: TextStyle(
                          color: stock > 10 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('vendors')
                          .doc(data['vendor_id'])
                          .get(),
                      builder: (context, vendorDoc) {
                        if (vendorDoc.hasData && vendorDoc.data!.exists) {
                          return Text((vendorDoc.data!.data() as Map<String, dynamic>)['name'] ?? 'N/A');
                        }
                        return const Text('N/A');
                      },
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEarningsView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor Earnings
          const Text(
            'Vendor Earnings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('vendors').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No vendors')),
                  ),
                );
              }

              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String vendorId = doc.id;

                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('orders')
                          .where('vendor_id', isEqualTo: vendorId)
                          .where('status', isEqualTo: 'Delivered')
                          .get(),
                      builder: (context, orderSnapshot) {
                        double totalEarnings = 0;
                        int orderCount = 0;

                        if (orderSnapshot.hasData) {
                          orderCount = orderSnapshot.data!.docs.length;
                          totalEarnings = orderSnapshot.data!.docs.fold(0.0, (sum, doc) {
                            var orderData = doc.data() as Map<String, dynamic>;
                            return sum + ((orderData['total_amount'] ?? 0) as num).toDouble();
                          });
                        }

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.store, color: Colors.white),
                          ),
                          title: Text(data['name'] ?? 'Unknown'),
                          subtitle: Text('$orderCount orders completed'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${totalEarnings.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'Total Earnings',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Rider Earnings
          const Text(
            'Rider Earnings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('riders').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No riders')),
                  ),
                );
              }

              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String riderId = doc.id;

                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('orders')
                          .where('rider_id', isEqualTo: riderId)
                          .where('status', isEqualTo: 'Delivered')
                          .get(),
                      builder: (context, orderSnapshot) {
                        double totalCommission = 0;
                        int deliveryCount = 0;

                        if (orderSnapshot.hasData) {
                          deliveryCount = orderSnapshot.data!.docs.length;
                          totalCommission = orderSnapshot.data!.docs.fold(0.0, (sum, doc) {
                            var orderData = doc.data() as Map<String, dynamic>;
                            return sum + ((orderData['rider_commission'] ?? 0) as num).toDouble();
                          });
                        }

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.delivery_dining, color: Colors.white),
                          ),
                          title: Text(data['name'] ?? 'Unknown'),
                          subtitle: Text('$deliveryCount deliveries completed'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${totalCommission.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0D9759),
                                ),
                              ),
                              const Text(
                                'Commission Earned',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
