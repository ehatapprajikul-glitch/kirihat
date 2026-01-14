import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/vendor_price_exception_dialog.dart';

class ProductCard extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final String vendorId;
  final bool initialAvailability;
  final bool compact;
  final Function(bool) onInventoryChanged;

  const ProductCard({
    super.key,
    required this.productId,
    required this.productData,
    required this.vendorId,
    required this.initialAvailability,
    this.compact = false,
    required this.onInventoryChanged,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late bool _isAvailable;
  
  @override
  void initState() {
    super.initState();
    _isAvailable = widget.initialAvailability;
  }
  
  @override
  void didUpdateWidget(ProductCard oldWidget) {
     super.didUpdateWidget(oldWidget);
     if (oldWidget.initialAvailability != widget.initialAvailability) {
       _isAvailable = widget.initialAvailability;
     }
  }

  Future<void> _requestPriceException() async {
    double currentPrice = (widget.productData['mrp'] ?? 0).toDouble();
    
    try {
      bool? submitted = await showDialog<bool>(
        context: context,
        builder: (context) => VendorPriceExceptionDialog(
          vendorId: widget.vendorId,
          productId: widget.productId,
          productName: widget.productData['name'] ?? 'Product',
          currentPrice: currentPrice,
        ),
      );

      if (submitted == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your request has been submitted for admin review'),
            backgroundColor: Color(0xFF34A853),
          ),
        );
      }
    } catch (e) {
      debugPrint("Price Exception Dialog Error: $e");
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isAvailable = value);
    widget.onInventoryChanged(value);

    try {
      if (value) {
        double defaultPrice = (widget.productData['selling_price'] ?? widget.productData['price'] ?? widget.productData['mrp'] ?? 0).toDouble();
        int defaultQty = (widget.productData['quantity'] ?? widget.productData['stock_quantity'] ?? 0).toInt();
        
        Map<String, dynamic>? result = await _showAddToInventoryDialog(defaultPrice, defaultQty);
        
        if (result != null && result['confirmed'] == true) {
           await _updateInventory(
             true, 
             defaultPrice, 
             result['qty'], 
             result['policyType'], 
             result['returnWindow']
           );
        } else {
           setState(() => _isAvailable = !value);
           widget.onInventoryChanged(!value);
        }
      } else {
        await _updateInventory(false, null, 0, null, 0);
      }
    } catch (e) {
       setState(() => _isAvailable = !value);
       widget.onInventoryChanged(!value);
       if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
    }
  }

  Future<void> _updateInventory(
      bool isAvailable, 
      double? price, 
      int quantity, 
      String? returnPolicyType, 
      int returnWindowDays
  ) async {
      var querySnapshot = await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: widget.vendorId)
          .where('product_id', isEqualTo: widget.productId)
          .limit(1)
          .get();

      var data = {
        'vendor_id': widget.vendorId,
        'product_id': widget.productId,
        'isAvailable': isAvailable,
        'selling_price': price,
        'stock_quantity': quantity,
        'return_policy_type': returnPolicyType,
        'return_window_days': returnWindowDays,
        'price_synced': true,
        'last_updated': FieldValue.serverTimestamp(),
        'name': widget.productData['name'], 
        'category': widget.productData['category'],
        'imageUrl': widget.productData['imageUrl'],
      };

      if (querySnapshot.docs.isEmpty) {
        if (isAvailable) {
           await FirebaseFirestore.instance.collection('vendor_inventory').add(data);
        }
      } else {
        if (isAvailable) {
          await querySnapshot.docs.first.reference.update(data);
        } else {
          await querySnapshot.docs.first.reference.delete();
        }
      }
  }

  Future<Map<String, dynamic>?> _showAddToInventoryDialog(double defaultPrice, int defaultQty) async {
    final quantityController = TextEditingController(text: defaultQty.toString());
    String policyType = 'No Return';
    String durationOption = '7 Days';
    
    final List<String> policyTypes = ['No Return', 'Return & Replace', 'Replace Only'];
    final List<String> durationOptions = ['Same Day', '2 Days', '3 Days', '4 Days', '5 Days', '6 Days', '7 Days', 'Custom'];

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add to Inventory'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(widget.productData['name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),
                   TextField(
                     controller: quantityController,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(labelText: 'Stock Qty', border: OutlineInputBorder()),
                   ),
                   const SizedBox(height: 16),
                   DropdownButtonFormField<String>(
                     value: policyType,
                     decoration: const InputDecoration(labelText: 'Policy', border: OutlineInputBorder()),
                     items: policyTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                     onChanged: (val) => setState(() => policyType = val!),
                   ),
                   if (policyType != 'No Return') ...[
                     const SizedBox(height: 8),
                     DropdownButtonFormField<String>(
                       value: durationOption,
                       items: durationOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                       onChanged: (val) => setState(() => durationOption = val!),
                     )
                   ]
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                   int qty = int.tryParse(quantityController.text) ?? 0;
                   Navigator.pop(context, {
                     'confirmed': true,
                     'qty': qty,
                     'policyType': policyType,
                     'returnWindow': 7
                   });
                },
                child: const Text('Add'),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double mrp = (widget.productData['mrp'] ?? 0).toDouble();
    double sellingPrice = (widget.productData['selling_price'] ?? mrp).toDouble();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: widget.productData['imageUrl'] != null
                      ? Image.network(
                          widget.productData['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48),
                        )
                      : const Icon(Icons.image, size: 48),
                ),
                if (_isAvailable)
                  Positioned(
                    top: 4, left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                      child: const Text("LISTED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productData['name'] ?? 'No Name', 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                ),
                const SizedBox(height: 2),
                Text(
                  widget.productData['category'] ?? '-',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                     Text("₹$sellingPrice", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                     const SizedBox(width: 4),
                     if (mrp > sellingPrice)
                       Text("₹$mrp", style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  width: double.infinity,
                  child: _isAvailable 
                    ? OutlinedButton(
                        onPressed: () => _toggleAvailability(false),
                        style: OutlinedButton.styleFrom(
                           padding: EdgeInsets.zero,
                           side: const BorderSide(color: Colors.red),
                           foregroundColor: Colors.red,
                        ),
                        child: const Text("Remove", style: TextStyle(fontSize: 12)),
                      )
                    : ElevatedButton(
                        onPressed: () => _toggleAvailability(true),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xFF0D9759),
                          foregroundColor: Colors.white
                        ),
                        child: const Text("Add to List", style: TextStyle(fontSize: 12)),
                      ),
                ),
                // Request Exception - Only if listed
                if (_isAvailable)
                  Center(
                    child: TextButton(
                      onPressed: _requestPriceException,
                      style: TextButton.styleFrom(
                         padding: EdgeInsets.zero, 
                         visualDensity: VisualDensity.compact,
                         foregroundColor: Colors.orange
                      ),
                      child: const Text("Request Exception", style: TextStyle(fontSize: 10)),
                    ),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }
}
