import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'widgets/request_product_dialog.dart';
import 'widgets/product_card.dart';

class MasterCatalogScreen extends StatefulWidget {
  const MasterCatalogScreen({super.key});

  @override
  State<MasterCatalogScreen> createState() => _MasterCatalogScreenState();
}

class _MasterCatalogScreenState extends State<MasterCatalogScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String vendorId = FirebaseAuth.instance.currentUser!.uid;

  // Search & Filter State
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _searchBy = 'Name'; // Name, Barcode, SEO Title
  String _filterType = 'All'; // All, My Listed, Not Listed, New Arrival, Under 199, Custom Price
  double? _customPriceLimit;

  // Pagination & Data State
  final List<DocumentSnapshot> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  // Cache
  final Map<String, bool> _inventoryCache = {};
  
  final Set<String> _vendorInventoryIds = {};
  bool _inventoryLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadVendorInventoryIds();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _fetchProducts();
      }
    }
  }

  Future<void> _loadVendorInventoryIds() async {
    if (_inventoryLoaded) return;
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId)
          .get();
      
      _vendorInventoryIds.clear();
      for (var doc in snapshot.docs) {
        if (doc.data().containsKey('product_id')) {
          _vendorInventoryIds.add(doc['product_id']);
          _inventoryCache[doc['product_id']] = true;
        }
      }
      setState(() => _inventoryLoaded = true);
      _fetchProducts(refresh: true);
    } catch (e) {
      debugPrint("Error loading inventory IDs: $e");
      setState(() => _inventoryLoaded = true);
      _fetchProducts(refresh: true);
    }
  }

  Future<void> _fetchProducts({bool refresh = false}) async {
    if (_isLoading) return;
    
    if (_filterType == 'My Listed') {
      await _fetchMyListedProducts(refresh: refresh);
      return;
    }

    setState(() {
      _isLoading = true;
      if (refresh) {
        _products.clear();
        _lastDocument = null;
        _hasMore = true;
      }
    });

    try {
      Query query = FirebaseFirestore.instance.collection('master_products');
      query = query.where('isActive', isEqualTo: true);

      if (_selectedCategory != 'All') {
        query = query.where('category', isEqualTo: _selectedCategory);
      }

      if (_searchQuery.isNotEmpty) {
        if (_searchBy == 'Barcode') {
          query = query.where('barcode', isEqualTo: _searchQuery);
        } else if (_searchBy == 'SEO Title') {
           query = query.where('seo_title', isGreaterThanOrEqualTo: _searchQuery)
                        .where('seo_title', isLessThan: '$_searchQuery\uf8ff');
        } else {
           query = query.where('name', isGreaterThanOrEqualTo: _searchQuery)
                        .where('name', isLessThan: '$_searchQuery\uf8ff');
        }
      }

      if (_searchQuery.isEmpty) {
        if (_filterType == 'New Arrival') {
          query = query.orderBy('created_at', descending: true);
        } else if (_filterType == 'Under 199') {
          query = query.where('mrp', isLessThan: 199).orderBy('mrp');
        } else if (_filterType == 'Under custom price' && _customPriceLimit != null) {
          query = query.where('mrp', isLessThan: _customPriceLimit).orderBy('mrp');
        }
      }

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      query = query.limit(_pageSize);
      var snapshot = await query.get();
      List<DocumentSnapshot> newDocs = [];
      
      for (var doc in snapshot.docs) {
        if (_filterType == 'Not Listed') {
           if (!_vendorInventoryIds.contains(doc.id)) {
             newDocs.add(doc);
           }
        } else {
           newDocs.add(doc);
        }
      }

      if (mounted) {
        setState(() {
          _products.addAll(newDocs);
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
            _hasMore = snapshot.docs.length == _pageSize;
            
            if (newDocs.isEmpty && _hasMore) {
               Future.microtask(() => _fetchProducts());
            }
          } else {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMyListedProducts({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      if (refresh) {
         _products.clear();
         _lastDocument = null;
         _hasMore = true;
      }
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('vendor_inventory')
          .where('vendor_id', isEqualTo: vendorId);
      
      if (_selectedCategory != 'All') {
         query = query.where('category', isEqualTo: _selectedCategory);
      }

      if (_lastDocument != null) {
         query = query.startAfterDocument(_lastDocument!);
      }
      query = query.limit(_pageSize);

      var snapshot = await query.get();
      
      if (mounted) {
         setState(() {
           _products.addAll(snapshot.docs);
           _hasMore = snapshot.docs.length == _pageSize;
           if (snapshot.docs.isNotEmpty) {
             _lastDocument = snapshot.docs.last;
           }
           _isLoading = false;
         });
      }
    } catch (e) {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategoryChanged(String? val) {
    if (val != null && val != _selectedCategory) {
      setState(() => _selectedCategory = val);
      _fetchProducts(refresh: true);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Filter By", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12, runSpacing: 12,
                  children: [
                    'All', 'My Listed', 'Not Listed', 'New Arrival', 'Under 199', 'Under custom price'
                  ].map((filter) {
                    bool isSelected = _filterType == filter;
                    return FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setSheetState(() => _filterType = filter);
                      },
                      selectedColor: const Color(0xFF0D9759).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF0D9759),
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF0D9759) : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      ),
                    );
                  }).toList(),
                ),
                if (_filterType == 'Under custom price') ...[
                   const SizedBox(height: 16),
                   TextField(
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(labelText: 'Enter Maximum Price (₹)', border: OutlineInputBorder()),
                     onChanged: (val) => _customPriceLimit = double.tryParse(val),
                   )
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _fetchProducts(refresh: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)
                    ),
                    child: const Text("Apply Filters"),
                  ),
                )
              ],
            ),
          );
        }
      )
    );
  }

  void _showRequestProductDialog() {
    showDialog(
      context: context,
      builder: (context) => const RequestProductDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Column(
      children: [
        // Controls Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _fetchProducts(refresh: true),
                      decoration: InputDecoration(
                        hintText: 'Search by $_searchBy...',
                        isDense: true,
                        prefixIcon: PopupMenuButton<String>(
                          icon: const Icon(Icons.search),
                          tooltip: 'Search By',
                          onSelected: (val) => setState(() => _searchBy = val),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'Name', child: Text('Name')),
                            const PopupMenuItem(value: 'Barcode', child: Text('Barcode')),
                            const PopupMenuItem(value: 'SEO Title', child: Text('SEO Title')),
                          ],
                        ),
                        suffixIcon: IconButton(
                           icon: const Icon(Icons.arrow_forward),
                           onPressed: () => _fetchProducts(refresh: true),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                      builder: (context, snapshot) {
                        List<String> categories = ['All'];
                        if (snapshot.hasData) {
                          categories.addAll(snapshot.data!.docs.map((doc) => doc['name'] as String));
                        }
                        return Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: _onCategoryChanged,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _showFilterSheet,
                    icon: const Icon(Icons.tune),
                    isSelected: _filterType != 'All',
                    style: IconButton.styleFrom(
                       backgroundColor: _filterType != 'All' ? const Color(0xFF0D9759) : Colors.grey[200],
                       foregroundColor: _filterType != 'All' ? Colors.white : Colors.black87,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _showRequestProductDialog,
                    icon: const Icon(Icons.add),
                    tooltip: "Request Product",
                    style: IconButton.styleFrom(
                       backgroundColor: Colors.blue,
                       foregroundColor: Colors.white,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const Divider(height: 1),
        
        if (_filterType != 'All')
           Container(
             width: double.infinity,
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             color: Colors.grey[50],
             child: Wrap(
               spacing: 8,
               crossAxisAlignment: WrapCrossAlignment.center,
               children: [
                 const Text("Active Filter:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                 Chip(
                   label: Text(_filterType + (_filterType.contains('custom') ? ' (${_customPriceLimit?.toStringAsFixed(0)})' : '')),
                   onDeleted: () {
                      setState(() { 
                        _filterType = 'All';
                        _customPriceLimit = null;
                      });
                      _fetchProducts(refresh: true);
                   },
                   visualDensity: VisualDensity.compact,
                   backgroundColor: const Color(0xFFE8F5E9),
                   labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF0D9759)),
                   deleteIconColor: const Color(0xFF0D9759),
                 )
               ],
             ),
           ),

        Expanded(
          child: _products.isEmpty && !_isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text("No products found", style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              )
            : GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.60,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _products.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _products.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  DocumentSnapshot doc = _products[index];
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  String docId = doc.id;
                  
                  if (_filterType == 'My Listed') {
                     docId = data['product_id'] ?? docId; 
                  }
                  
                  bool isAvailable = _inventoryCache.containsKey(docId);
                  if (_filterType == 'My Listed') isAvailable = true;

                  return ProductCard(
                    productId: docId,
                    productData: data,
                    vendorId: vendorId,
                    initialAvailability: isAvailable, 
                    compact: true,
                    onInventoryChanged: (available) {
                       setState(() {
                          if (available) {
                            _inventoryCache[docId] = true;
                            _vendorInventoryIds.add(docId);
                          } else {
                            _inventoryCache.remove(docId);
                            _vendorInventoryIds.remove(docId);
                          }
                          if (_filterType == 'Not Listed' && available) {
                             _products.removeAt(index);
                          } else if (_filterType == 'My Listed' && !available) {
                             _products.removeAt(index);
                          }
                       });
                    },
                  );
                },
              ),
        ),
      ],
    );
  }
}
