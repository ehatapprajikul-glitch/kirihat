import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// ---------------------------------------------------------------------------
// 1. MAIN LAYOUT (Holds the Bottom Navigation)
// ---------------------------------------------------------------------------
class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  int _currentIndex = 0;

  // The 4 Screens
  final List<Widget> _tabs = [
    const VendorHomeScreen(), // Dashboard Stats
    const VendorInventoryScreen(), // Product Management
    const VendorOrdersScreen(), // Order Management
    const VendorProfileScreen(), // Profile & Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 5,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. TAB 1: HOME (Dashboard Stats)
// ---------------------------------------------------------------------------
class VendorHomeScreen extends StatelessWidget {
  const VendorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // NOTE: In a real app, you would fetch these numbers from a 'stats' collection in Firebase
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.orange[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Overview (Today)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            // STAT CARDS ROW
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  "Total Sales",
                  "₹12,500",
                  Colors.green,
                  Icons.attach_money,
                ),
                _buildStatCard(
                  "New Orders",
                  "12",
                  Colors.blue,
                  Icons.shopping_cart,
                ),
                _buildStatCard(
                  "Pending Ship",
                  "4",
                  Colors.orange,
                  Icons.local_shipping,
                ),
                _buildStatCard(
                  "Returns",
                  "1",
                  Colors.red,
                  Icons.assignment_return,
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Text(
              "Stock Alerts",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // LOW STOCK WARNING CARD
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 40),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Low Stock Warning",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const Text("3 items are below 5 qty."),
                      TextButton(
                        onPressed: () {},
                        child: const Text("View Items"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: TextStyle(color: color.withAlpha(204))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. TAB 2: INVENTORY (Fixed: MRP Restored + Image Upload)
// ---------------------------------------------------------------------------
class VendorInventoryScreen extends StatefulWidget {
  const VendorInventoryScreen({super.key});
  @override
  State<VendorInventoryScreen> createState() => _VendorInventoryScreenState();
}

class _VendorInventoryScreenState extends State<VendorInventoryScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _searchQuery = "";

  // MAIN CONTROLLERS
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController(); // MRP Controller
  final _stockController = TextEditingController();
  final _tagsController = TextEditingController();
  final _descController = TextEditingController();

  // IMAGE DATA
  String _heroImageUrl = "";
  List<String> _galleryUrls = [];
  bool _isUploadingImage = false;

  String _selectedCategory = 'Groceries';
  final List<String> _categories = [
    'Groceries',
    'Vegetables',
    'Snacks',
    'Household',
    'Electronics',
    'Fashion',
    'General',
  ];

  // 1. CLOUDINARY UPLOAD LOGIC
  Future<void> _pickAndUploadImage({bool isHero = true}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      Uint8List imgData = await image.readAsBytes();

      // REPLACE WITH YOUR CLOUD NAME
      var uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/du634o3sf/image/upload",
      );
      var request = http.MultipartRequest("POST", uri);

      // REPLACE WITH YOUR UPLOAD PRESET
      request.fields['upload_preset'] = "ouofgw7n";

      request.files.add(
        http.MultipartFile.fromBytes('file', imgData, filename: "product.jpg"),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var jsonMap = jsonDecode(String.fromCharCodes(responseData));
        String downloadUrl = jsonMap['secure_url'];

        setState(() {
          if (isHero) {
            _heroImageUrl = downloadUrl;
          } else {
            _galleryUrls.add(downloadUrl);
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Uploaded!")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Upload Failed")));
      }
    } catch (e) {
      print(e);
    }
    setState(() => _isUploadingImage = false);
  }

  // 2. DIALOG (Fixed: MRP + Keywords/Tags + Images)
  void _showProductDialog({Map<String, dynamic>? oldData, String? docId}) {
    // Reset Data
    _heroImageUrl = "";
    _galleryUrls = [];
    _isUploadingImage = false;

    // Pre-fill Data
    if (oldData != null) {
      _nameController.text = oldData['name'];
      _priceController.text = oldData['price'].toString();
      _mrpController.text = (oldData['mrp'] ?? oldData['price']).toString();
      _stockController.text = oldData['stock'].toString();
      // Restore Tags
      _tagsController.text = (oldData['tags'] as List<dynamic>? ?? []).join(
        ', ',
      );
      _descController.text = oldData['description'] ?? '';
      _heroImageUrl = oldData['imageUrl'] ?? '';
      _selectedCategory = _categories.contains(oldData['category'])
          ? oldData['category']
          : 'Groceries';

      for (var url in (oldData['gallery'] ?? [])) {
        _galleryUrls.add(url.toString());
      }
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(docId == null ? "Add New Product" : "Edit Product"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- 1. IMAGES ---
                    const Text(
                      "Product Images",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          await _pickAndUploadImage(isHero: true);
                          setDialogState(() {});
                        },
                        child: Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.grey),
                          ),
                          child: _isUploadingImage
                              ? const Center(child: CircularProgressIndicator())
                              : (_heroImageUrl.isNotEmpty)
                              ? Image.network(_heroImageUrl, fit: BoxFit.cover)
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt),
                                    Text("Tap to Upload"),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Gallery
                    Wrap(
                      spacing: 10,
                      children: [
                        ..._galleryUrls.map(
                          (url) => Chip(
                            label: const Text("Img"),
                            avatar: const Icon(Icons.image, size: 16),
                            onDeleted: () =>
                                setDialogState(() => _galleryUrls.remove(url)),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await _pickAndUploadImage(isHero: false);
                            setDialogState(() {});
                          },
                          icon: const Icon(
                            Icons.add_a_photo,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const Divider(thickness: 2),

                    // --- 2. BASIC DETAILS ---
                    const Text(
                      "Basic Info",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Product Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- 3. PRICING (Price + MRP) ---
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Selling ₹",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _mrpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "MRP ₹",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // --- 4. STOCK & CATEGORY ---
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Stock",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField(
                            value: _selectedCategory,
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setDialogState(
                              () => _selectedCategory = v.toString(),
                            ),
                            decoration: const InputDecoration(
                              labelText: "Category",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(thickness: 2),

                    // --- 5. KEYWORDS & SPECS (Restored) ---
                    const Text(
                      "Search & Details",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: "Keywords/Tags",
                        hintText: "rice, basmati, food",
                        border: OutlineInputBorder(),
                        helperText: "Separate with commas",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Product Description",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: _isUploadingImage
                    ? null
                    : () => _saveProduct(docId, ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Save Product"),
              ),
            ],
          );
        },
      ),
    );
  }

  // 3. SAVE LOGIC
  Future<void> _saveProduct(String? docId, BuildContext ctx) async {
    if (_nameController.text.isEmpty) return;

    List<String> keywords = _nameController.text.toLowerCase().split(' ');
    List<String> tags = _tagsController.text
        .toLowerCase()
        .split(',')
        .map((e) => e.trim())
        .toList();
    List<String> searchIndex = [...keywords, ...tags];
    searchIndex.removeWhere((e) => e.isEmpty);

    Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'price': int.tryParse(_priceController.text) ?? 0,
      'mrp': int.tryParse(_mrpController.text) ?? 0, // Saving MRP
      'stock': int.tryParse(_stockController.text) ?? 0,
      'imageUrl': _heroImageUrl,
      'gallery': _galleryUrls,
      'description': _descController.text.trim(),
      'tags': tags,
      'search_keywords': searchIndex,
      'vendor_id': currentUser?.email,
      'isActive': true,
      if (docId == null) 'created_at': FieldValue.serverTimestamp(),
    };

    if (docId == null) {
      await FirebaseFirestore.instance.collection('products').add(data);
    } else {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(docId)
          .update(data);
    }
    if (mounted) Navigator.pop(ctx);
  }

  void _clearForm() {
    _nameController.clear();
    _priceController.clear();
    _mrpController.clear();
    _stockController.clear();
    _tagsController.clear();
    _descController.clear();
    _heroImageUrl = "";
    _galleryUrls = [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory"),
        backgroundColor: Colors.orange[100],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('vendor_id', isEqualTo: currentUser?.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs
              .where(
                (d) =>
                    d['name'].toString().toLowerCase().contains(_searchQuery),
              )
              .toList();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading:
                      (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                      ? Image.network(
                          data['imageUrl'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image),
                  title: Text(data['name']),
                  subtitle: Text(
                    "₹${data['price']} (MRP: ${data['mrp'] ?? 0})",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showProductDialog(
                      oldData: data,
                      docId: docs[index].id,
                    ),
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

// ---------------------------------------------------------------------------
// 4. TAB 3: ORDERS (Vendor Restricted to "Shipped" Only)
// ---------------------------------------------------------------------------
class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Function to update Order Status (Only to "Shipped")
  void _markAsShipped(String docId) {
    FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': 'Shipped',
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Order Management"),
          backgroundColor: Colors.orange[100],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Active (Pending)"),
              Tab(text: "History (Shipped/Done)"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('vendor_id', isEqualTo: currentUser?.email)
              // .orderBy('created_at', descending: true) // Uncomment after creating Index
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            var docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text("No orders found."));
            }

            // TAB 1: Pending Orders (Needs Action)
            var activeOrders = docs.where((d) {
              String s = d['status'] ?? 'Pending';
              return s == 'Pending'; // Only show items waiting for the Vendor
            }).toList();

            // TAB 2: History (Shipped, Delivered, Cancelled)
            var historyOrders = docs.where((d) {
              String s = d['status'] ?? 'Pending';
              return s != 'Pending'; // Everything else goes to history
            }).toList();

            return TabBarView(
              children: [
                _buildOrderList(activeOrders, showActionButton: true),
                _buildOrderList(historyOrders, showActionButton: false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderList(
    List<QueryDocumentSnapshot> orders, {
    required bool showActionButton,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showActionButton ? Icons.inbox : Icons.history,
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 10),
            Text(showActionButton ? "No pending orders." : "No history found."),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        var doc = orders[index];
        var data = doc.data() as Map<String, dynamic>;

        List<dynamic> items = data['items'] ?? [];
        String status = data['status'] ?? 'Pending';
        double total = (data['total_amount'] ?? 0).toDouble();

        // Color code based on status
        Color statusColor = Colors.orange;
        if (status == 'Shipped') statusColor = Colors.blue;
        if (status == 'Delivered') statusColor = Colors.green;
        if (status == 'Cancelled') statusColor = Colors.red;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER: ID and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Order #${doc.id.substring(0, 5).toUpperCase()}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),

                // CUSTOMER INFO
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(
                      data['customer_phone'] ?? "Unknown Customer",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ITEMS LIST
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${item['qty']}x ${item['name']}",
                          style: const TextStyle(fontSize: 15),
                        ),
                        Text(
                          "₹${item['price'] * item['qty']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(),

                // FOOTER: Total & Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total: ₹$total",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),

                    // ONLY SHOW BUTTON IF STATUS IS PENDING
                    if (showActionButton && status == 'Pending')
                      ElevatedButton(
                        onPressed: () => _markAsShipped(doc.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Mark Shipped"),
                      ),

                    // IF SHIPPED, SHOW TEXT INSTEAD
                    if (!showActionButton && status == 'Shipped')
                      const Text(
                        "Wait for Rider",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 5. TAB 4: ME (Profile & Settings)
// ---------------------------------------------------------------------------
class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.orange[100],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // PROFILE PIC & NAME
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.orange,
              child: Icon(Icons.store, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              "My Shop Name",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              user?.email ?? "Vendor",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Verified Vendor",
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ),

            const SizedBox(height: 30),

            // SETTINGS LIST
            _buildSectionHeader("Account Settings"),
            _buildListTile(Icons.edit, "Edit Profile Name", () {}),
            _buildListTile(Icons.storefront, "Change Vendor Type", () {}),
            _buildListTile(Icons.lock, "Change PIN", () {}),

            _buildSectionHeader("Rider Management"),
            _buildListTile(Icons.moped, "My Riders", () {}),
            _buildListTile(Icons.person_add, "Request New Rider", () {}),

            _buildSectionHeader("Danger Zone"),
            _buildListTile(
              Icons.power_settings_new,
              "Disable Account (Holiday Mode)",
              () {},
              isDanger: true,
            ),
            _buildListTile(
              Icons.logout,
              "Logout",
              () => FirebaseAuth.instance.signOut(),
              isDanger: true,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDanger = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDanger ? Colors.red : Colors.black87),
      title: Text(
        title,
        style: TextStyle(color: isDanger ? Colors.red : Colors.black87),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
