import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

class ProductRequestsScreen extends StatelessWidget {
  const ProductRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Requests',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D9759),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Review and approve product requests from vendors',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('seller_product_requests')
                .orderBy('submitted_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No product requests yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return _ProductRequestCard(
                    requestId: doc.id,
                    data: data,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductRequestCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const _ProductRequestCard({
    required this.requestId,
    required this.data,
  });

  @override
  State<_ProductRequestCard> createState() => _ProductRequestCardState();
}

class _ProductRequestCardState extends State<_ProductRequestCard> {
  bool _isProcessing = false;

  String get status => widget.data['status'] ?? 'pending';

  Color get statusColor {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);

    try {
      final productData = widget.data['product_data'] as Map<String, dynamic>;
      final sellerId = widget.data['seller_id'];
      
      // Merge specs from both root and product_data to be safe
      // Root specifications take precedence as they might have been updated
      final rootSpecs = widget.data['specifications'] as Map<String, dynamic>? ?? {};
      final nestedSpecs = productData['specifications'] as Map<String, dynamic>? ?? {};
      final specifications = {...nestedSpecs, ...rootSpecs}; 

      // Improved Keywords Logic: Check root 'keywords', then nested 'keywords', then map 'tags'
      // This ensures we catch them wherever they are stuck.
      final rootKeywords = widget.data['keywords'] as List<dynamic>?;
      final nestedKeywords = productData['keywords'] as List<dynamic>?;
      final keywords = rootKeywords ?? nestedKeywords ?? productData['tags'] ?? [];

      // 1. Create product in master_products
      var masterProductRef = await FirebaseFirestore.instance.collection('master_products').add({
        'name': productData['name'],
        'description': productData['description'] ?? '',
        'mrp': productData['mrp'],
        'cost_price': productData['cost_price'],
        'price': productData['selling_price'] ?? productData['price'], 
        'stock_quantity': productData['quantity'] ?? productData['stock_quantity'] ?? 0,
        
        // Save Category Names
        'category': productData['category'],
        'subcategory': productData['subcategory'], // might be null if not used
        
        // Save IDs
        'category_id': productData['category_id'] ?? productData['categoryId'],
        'subcategory_id': productData['subcategory_id'] ?? productData['subcategoryId'],
        
        'unit': productData['unit'] ?? '',
        'imageUrl': productData['image_url'] ?? '',
        'images': productData['images'] ?? [],
        'brand': productData['brand'] ?? '',
        'seller_id': sellerId,
        'specifications': specifications,
        'keywords': List<String>.from(keywords),
        'template_version': widget.data['template_version'],
        'tags': List<String>.from(keywords), // Save as tags too for search
        'isActive': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        
        // New Fields
        'barcode': productData['barcode'],
        'unit_value': productData['unit_value'],
        'unit_type': productData['unit_type'],
        'dimensions': productData['dimensions'],
        'gst': productData['gst'],
      });

      // 2. Update request status
      await FirebaseFirestore.instance
          .collection('seller_product_requests')
          .doc(widget.requestId)
          .update({
        'status': 'approved',
        'reviewed_at': FieldValue.serverTimestamp(),
        'master_product_id': masterProductRef.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product approved and added to catalog!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject(String reason) async {
    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance
          .collection('seller_product_requests')
          .doc(widget.requestId)
          .update({
        'status': 'rejected',
        'admin_notes': reason,
        'reviewed_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            hintText: 'Explain why so the seller can fix it',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _reject(reasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productData = widget.data['product_data'] as Map<String, dynamic>;
    final businessName = widget.data['product_data']['business_name'] ?? 'Unknown Seller';
    
    // Correctly resolve specifications
    final rootSpecs = widget.data['specifications'] as Map<String, dynamic>? ?? {};
    final nestedSpecs = productData['specifications'] as Map<String, dynamic>? ?? {};
    final specifications = {...nestedSpecs, ...rootSpecs};

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      surfaceTintColor: Colors.white,
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: productData['image_url'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    productData['image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image, size: 32),
                  ),
                )
              : const Icon(Icons.image, size: 32),
        ),
        title: Text(
          productData['name'] ?? 'Unnamed Product',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${productData['brand'] ?? 'No Brand'}', style: TextStyle(color: Colors.grey[700])),
             const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Seller: $businessName',
                   style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildSectionHeader('Description'),
                Text(productData['description'] ?? 'No description provided.', style: TextStyle(color: Colors.grey[800])),
                
                const SizedBox(height: 16),
                _buildSectionHeader('Pricing & Stock'),
                _buildDetailRow('MRP', CurrencyHelper.format(productData['mrp'])),
                _buildDetailRow('Selling Price', CurrencyHelper.format(productData['selling_price'] ?? productData['price'])),
                _buildDetailRow('Cost Price', CurrencyHelper.format(productData['cost_price'])),
                _buildDetailRow('Quantity', '${productData['quantity'] ?? productData['stock_quantity'] ?? '-'}'),

                const SizedBox(height: 16),
                 _buildSectionHeader('Product Details'),
                 _buildDetailRow('Category', '${productData['category'] ?? '-'}'),
                 _buildDetailRow('Brand', '${productData['brand'] ?? '-'}'),
                 _buildDetailRow('Unit', '${productData['unit'] ?? '-'}'),
                 _buildDetailRow('Barcode', '${productData['barcode'] ?? '-'}'),
                 
                 // GST
                 if (productData['gst'] != null) ...[
                   const SizedBox(height: 8),
                   const Text('GST Info:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                   if (productData['gst']['available'] == true) ...[
                      _buildDetailRow('IGST', '${productData['gst']['igst']}%'),
                      _buildDetailRow('CGST', '${productData['gst']['cgst']}%'),
                   ] else 
                      const Text('Exempted', style: TextStyle(color: Colors.grey)),
                 ],

                 // Dimensions
                 if (productData['dimensions'] != null) ...[
                   const SizedBox(height: 16),
                   _buildSectionHeader('Dimensions'),
                   if (productData['dimensions']['product'] != null)
                      _buildDimensionBlock('Product', productData['dimensions']['product']),
                   if (productData['dimensions']['package'] != null)
                      _buildDimensionBlock('Package', productData['dimensions']['package']),
                 ],

                 // Specifications
                 if (specifications.isNotEmpty) ...[
                   const SizedBox(height: 16),
                   _buildSectionHeader('Specifications'),
                   Container(
                     width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: specifications.entries.map((e) => Padding(
                         padding: const EdgeInsets.only(bottom: 4),
                         child: Row(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             SizedBox(
                               width: 120,
                               child: Text(
                                 '${e.key}:',
                                 style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                               ),
                             ),
                             Expanded(child: Text('${e.value}')),
                           ],
                         ),
                       )).toList(),
                     ),
                   ),
                 ],

                  // Keywords
                  if (widget.data['keywords'] != null) ...[
                    const SizedBox(height: 16),
                    _buildSectionHeader('Keywords'),
                    Wrap(
                      spacing: 8,
                      children: (widget.data['keywords'] as List).map((k) => Chip(
                        label: Text(k.toString(), style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.grey[100],
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ],

                 const SizedBox(height: 24),
                 if (status == 'pending' && !_isProcessing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showRejectDialog,
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _approve,
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    
                 if (_isProcessing)
                    const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D9759),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionBlock(String type, Map<String, dynamic> dims) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$type Dimensions:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '${dims['length']} x ${dims['breadth']} x ${dims['height']} cm',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'Weight: ${dims['net_weight'] ?? dims['gross_weight']} g',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
