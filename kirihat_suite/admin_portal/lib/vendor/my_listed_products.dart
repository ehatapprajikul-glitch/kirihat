import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyListedProductsScreen extends StatefulWidget {
  const MyListedProductsScreen({super.key});

  @override
  State<MyListedProductsScreen> createState() => _MyListedProductsScreenState();
}

class _MyListedProductsScreenState extends State<MyListedProductsScreen> {
  bool _showAll = false; // Toggle to show unlisted items

  @override
  Widget build(BuildContext context) {
    final String vendorId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listed Products'),
        backgroundColor: Colors.green[100],
        actions: [
          // Toggle "Show All"
          Row(
            children: [
              const Text('Show All', style: TextStyle(fontSize: 12)),
              Switch(
                value: _showAll,
                onChanged: (val) {
                  setState(() => _showAll = val);
                },
                activeColor: Colors.green,
              ),
            ],
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendor_inventory')
            .where('vendor_id', isEqualTo: vendorId)
            // .where('isAvailable', isEqualTo: true) // Client-side filtering
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             debugPrint("Error loading inventory: ${snapshot.error}");
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            debugPrint("Query returned 0 documents for vendorId: $vendorId");
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No products in your inventory',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vendor ID: ${vendorId.substring(0, 5)}...', // Debug aid
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate back or to catalog
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Go to Dashboard"),
                  )
                ],
              ),
            );
          }

          var allDocs = snapshot.data!.docs;
          debugPrint("Fetched ${allDocs.length} inventory items total.");
          
          // Filter based on toggle
          var displayedDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            bool isAvail = data['isAvailable'] == true;
            
            if (_showAll) return true; // Show everything
            return isAvail;    // Show only listed
          }).toList();

          debugPrint("Showing ${displayedDocs.length} items (ShowAll: $_showAll).");

          if (displayedDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _showAll ? 'Inventory Empty' : 'No visible listed products',
                     style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                   const SizedBox(height: 8),
                   if (!_showAll)
                     TextButton(
                       onPressed: () => setState(() => _showAll = true),
                       child: const Text("Show Hidden/Unlisted Items"),
                     ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayedDocs.length,
            itemBuilder: (context, index) {
              var inventoryDoc = displayedDocs[index];
              var inventoryData = inventoryDoc.data() as Map<String, dynamic>;
              
              return _ListedProductCard(
                inventoryId: inventoryDoc.id,
                inventoryData: inventoryData,
                vendorId: vendorId,
              );
            },
          );
        },
      ),
    );
  }
}

class _ListedProductCard extends StatefulWidget {
  final String inventoryId;
  final Map<String, dynamic> inventoryData;
  final String vendorId;

  const _ListedProductCard({
    required this.inventoryId,
    required this.inventoryData,
    required this.vendorId,
  });

  @override
  State<_ListedProductCard> createState() => _ListedProductCardState();
}

class _ListedProductCardState extends State<_ListedProductCard> {
  Map<String, dynamic>? _productData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  Future<void> _loadProductData() async {
    try {
      var productDoc = await FirebaseFirestore.instance
          .collection('master_products')
          .doc(widget.inventoryData['product_id'])
          .get();

      if (productDoc.exists) {
        if (mounted) {
          setState(() {
            _productData = productDoc.data();
            _isLoading = false;
          });
        }
      } else {
         if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading product: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStock(int newStock) async {
    try {
      await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .doc(widget.inventoryId)
          .update({
        'stock_quantity': newStock,
        'last_updated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showStockDialog() {
    final stockController = TextEditingController(
      text: (widget.inventoryData['stock_quantity'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Stock'),
        content: TextField(
          controller: stockController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Stock Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              int? stock = int.tryParse(stockController.text);
              if (stock != null && stock >= 0) {
                _updateStock(stock);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid stock quantity')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAvailability(bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .doc(widget.inventoryId)
          .update({
        'isAvailable': value,
        'last_updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    }
    
    if (_productData == null) {
      // Handle missing product reference cleanly
      return Card(
        child: ListTile(
             title: const Text("Unknown Product"),
             subtitle: Text("ID: ${widget.inventoryData['product_id']}"),
             leading: const Icon(Icons.broken_image),
             trailing: IconButton(onPressed: (){
               // Optional: Allow deleting orphan inventory
             }, icon: const Icon(Icons.delete_forever)),
        ),
      );
    }

    int stock = widget.inventoryData['stock_quantity'] ?? 0;
    double sellingPrice = widget.inventoryData['selling_price']?.toDouble() ?? 0;
    double mrp = _productData!['mrp']?.toDouble() ?? 0;
    bool isAvailable = widget.inventoryData['isAvailable'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _productData!['imageUrl'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _productData!['imageUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image),
                      ),
                    )
                  : const Icon(Icons.image),
            ),
            const SizedBox(width: 16),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _productData!['name'] ?? 'Unnamed Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_productData!['unit'] ?? ''} • MRP: ₹$mrp',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your Price: ₹$sellingPrice',
                    style: const TextStyle(
                      color: Color(0xFF0D9759),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Stock Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: stock > 10
                          ? Colors.green.shade100
                          : stock > 0
                              ? Colors.orange.shade100
                              : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          stock > 10
                              ? Icons.check_circle
                              : stock > 0
                                  ? Icons.warning
                                  : Icons.error,
                          size: 16,
                          color: stock > 10
                              ? Colors.green
                              : stock > 0
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stock > 0 ? 'Stock: $stock' : 'Out of Stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: stock > 10
                                ? Colors.green
                                : stock > 0
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _showStockDialog,
                  icon: const Icon(Icons.inventory, size: 18),
                  label: const Text('Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(80, 36)
                  ),
                ),
                const SizedBox(height: 8),
                Switch(
                  value: isAvailable,
                  onChanged: _toggleAvailability,
                  activeColor: Colors.green,
                ),
                Text(
                  isAvailable ? 'Listed' : 'Hidden',
                  style: TextStyle(
                    fontSize: 10,
                    color: isAvailable ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
