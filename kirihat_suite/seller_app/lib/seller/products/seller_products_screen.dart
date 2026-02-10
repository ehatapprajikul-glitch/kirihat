import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'package:kirihat_core/models/seller_product_request.dart';
import 'package:kirihat_core/utils/currency_helper.dart';
import 'enhanced_add_product_screen.dart';
import 'widgets/draft_manager_widget.dart';
import 'widgets/barcode_quantity_dialog.dart';

class SellerProductsScreen extends StatefulWidget {
  final SellerModel seller;

  const SellerProductsScreen({super.key, required this.seller});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedProductIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _isSelectionMode = false;
          _selectedProductIds.clear();
        });
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;
          
          return Column(
            children: [
              // Header
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(isSmall ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Actions Row
                    if (isSmall) ...[
                      // Mobile: Stack layout
                      Text(
                        'Products',
                        style: TextStyle(
                          fontSize: isSmall ? 22 : 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isSelectionMode) ...[
                        Row(
                          children: [
                            Text(
                              '${_selectedProductIds.length} selected',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                setState(() => _isSelectionMode = false);
                                _selectedProductIds.clear();
                              },
                              icon: const Icon(Icons.close),
                              tooltip: 'Cancel',
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                              ),
                            ),
                            IconButton(
                              onPressed: _selectedProductIds.isEmpty
                                  ? null
                                  : _showBarcodeDialog,
                              icon: const Icon(Icons.print),
                              tooltip: 'Print Barcodes',
                              style: IconButton.styleFrom(
                                foregroundColor: const Color(0xFF0D9759),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EnhancedAddProductScreen(seller: widget.seller),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9759),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Desktop: Row layout
                      Row(
                        children: [
                          const Text(
                            'Products',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_isSelectionMode) ...[
                            Text(
                              '${_selectedProductIds.length} selected',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _isSelectionMode = false);
                                _selectedProductIds.clear();
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _selectedProductIds.isEmpty
                                  ? null
                                  : _showBarcodeDialog,
                              icon: const Icon(Icons.print),
                              label: const Text('Print Barcodes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9759),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EnhancedAddProductScreen(seller: widget.seller),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9759),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF0D9759),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF0D9759),
                      tabs: const [
                        Tab(text: 'My Products'),
                        Tab(text: 'Requests'),
                        Tab(text: 'Drafts'),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyProductsTab(),
                    _buildRequestsTab(),
                    DraftManagerWidget(seller: widget.seller),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildMyProductsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('master_products')
          .where('seller_id', isEqualTo: widget.seller.id)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0D9759)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  'No products yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your first product to get started',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnhancedAddProductScreen(seller: widget.seller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9759),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final productId = snapshot.data!.docs[index].id;
            final isSelected = _selectedProductIds.contains(productId);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              surfaceTintColor: Colors.white,
              color: isSelected ? const Color(0xFF0D9759).withOpacity(0.1) : Colors.white,
              child: InkWell(
                onTap: _isSelectionMode
                    ? () {
                        setState(() {
                          if (isSelected) {
                            _selectedProductIds.remove(productId);
                          } else {
                            _selectedProductIds.add(productId);
                          }
                        });
                      }
                    : null,
                onLongPress: () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedProductIds.add(productId);
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selection Checkbox
                      if (_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedProductIds.add(productId);
                                } else {
                                  _selectedProductIds.remove(productId);
                                }
                              });
                            },
                            activeColor: const Color(0xFF0D9759),
                          ),
                        ),
                      
                      // Image
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          image: data['imageUrl'] != null
                              ? DecorationImage(
                                  image: NetworkImage(data['imageUrl']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: data['imageUrl'] == null
                            ? const Icon(Icons.image, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name'] ?? 'Unnamed',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data['category'] ?? 'Uncategorized'} • ${data['subcategory'] ?? ''}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  CurrencyHelper.format(data['mrp']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D9759),
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                if (!_isSelectionMode) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Edit Button
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                    tooltip: "Edit Product",
                                    onPressed: () {
                                         Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => EnhancedAddProductScreen(
                                                  seller: widget.seller,
                                                  productToEdit: {
                                                    'id': productId,
                                                    ...data,
                                                  },
                                              ),
                                            ),
                                          );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<List<SellerProductRequest>>(
      stream: SellerService().getSellerProductRequests(widget.seller.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.error_outline, color: Colors.red, size: 48),
                   const SizedBox(height: 16),
                   Text('Error loading requests: ${snapshot.error}'),
                   if (snapshot.error.toString().contains('index'))
                     const Padding(
                       padding: EdgeInsets.only(top: 8.0),
                       child: Text(
                         'A required database index is missing. Please check the console for the index creation link.',
                         textAlign: TextAlign.center,
                         style: TextStyle(color: Colors.red),
                       ),
                     ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0D9759)));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pending_actions, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  'No pending requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Submit products for admin approval',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final request = snapshot.data![index];
            final product = request.productData;
            
            Color statusColor;
            IconData statusIcon;
            
            switch (request.status) {
              case 'approved':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              case 'rejected':
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
                break;
              case 'revision_needed':
                statusColor = Colors.orange;
                statusIcon = Icons.edit;
                break;
              default:
                statusColor = Colors.blue;
                statusIcon = Icons.hourglass_top;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              surfaceTintColor: Colors.white,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(12),
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    image: product['image_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(product['image_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product['image_url'] == null
                      ? const Icon(Icons.image, color: Colors.grey)
                      : null,
                ),
                title: Text(
                  product['name'] ?? 'Unnamed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Submitted: ${_formatDate(request.submittedAt)}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          request.status.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                children: [
                  if (request.adminNotes != null && request.adminNotes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Notes:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(request.adminNotes!),
                          ],
                        ),
                      ),
                    ),
                  
                  if (request.status == 'rejected' || request.status == 'revision_needed')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EnhancedAddProductScreen(
                                  seller: widget.seller,
                                  productToEdit: request.productData,
                                  requestToResubmitId: request.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Edit & Resubmit Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: statusColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBarcodeDialog() async {
    // Fetch the full product data for selected IDs
    final selectedProducts = <Map<String, dynamic>>[];
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('master_products')
          .where('seller_id', isEqualTo: widget.seller.id)
          .where('isActive', isEqualTo: true)
          .get();
      
      for (var doc in snapshot.docs) {
        if (_selectedProductIds.contains(doc.id)) {
          selectedProducts.add({
            'id': doc.id,
            ...doc.data(),
          });
        }
      }
      
      if (selectedProducts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No products selected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => BarcodeQuantityDialog(
            selectedProducts: selectedProducts,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildQuickAddTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flash_on, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Quick Add from Catalog',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Browse existing products and add to your inventory',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Show master products catalog
            },
            icon: const Icon(Icons.search),
            label: const Text('Browse Catalog'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9759),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
