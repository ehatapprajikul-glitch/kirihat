import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Services
import 'services/order_service.dart';
import 'services/rider_service.dart';
import 'services/pdf_service.dart';
import 'services/order_enrichment_service.dart';

import 'package:kirihat_core/kirihat_core.dart';
import 'models/order_model.dart';

// Widgets
import 'widgets/order_card.dart';
import 'widgets/order_search_bar.dart';
import 'widgets/rider_selection_sheet.dart';
import 'widgets/order_stats_card.dart';
import 'widgets/order_filter_chips.dart';

class VendorOrdersScreen extends StatefulWidget {
  final String? initialOrderId;
  const VendorOrdersScreen({super.key, this.initialOrderId});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final OrderService _orderService = OrderService();
  final RiderService _riderService = RiderService();
  final PDFService _pdfService = PDFService();
  final OrderEnrichmentService _enrichmentService = OrderEnrichmentService();
  
  // Controllers
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // State
  String _searchQuery = "";
  String _selectedFilter = 'all'; // all, today, standard, instant, cod, online
  bool _showStats = true;
  
  // Selection State
  bool _isSelectionMode = false;
  final Set<String> _selectedOrderIds = {};
  List<OrderModel>? _cachedOrders; // Cache for immediate display
  Stream<QuerySnapshot>? _ordersStream;

  // Current User
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {}); // Refresh AppBar actions on tab change
    });

    if (currentUser != null) {
      _ordersStream = _orderService.getVendorOrdersStream(currentUser!.uid);
    }
    
    if (widget.initialOrderId != null) {
      _searchQuery = widget.initialOrderId!;
      _searchController.text = widget.initialOrderId!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- ASSIGN RIDER ---
  Future<void> _assignRiderToOrder(OrderModel order, RiderModel rider) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      await _orderService.assignRiderToOrder(
        orderId: order.id,
        riderId: rider.id,
        riderName: rider.name,
        riderPhone: rider.phone,
      );
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close rider selection
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Order assigned to ${rider.name}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- SHOW RIDER SELECTION ---
  void _showRiderSelection(OrderModel? order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RiderSelectionSheet(
        vendorId: currentUser!.uid,
        orderCount: order != null ? 1 : _selectedOrderIds.length,
        onRiderSelected: (rider) {
          if (order != null) {
            _assignRiderToOrder(order, rider);
          } else {
            _handleBulkAssignRider(rider);
          }
        },
      ),
    );
  }

  // --- BULK ASSIGN RIDER ---
  Future<void> _handleBulkAssignRider(RiderModel rider) async {
    if (_selectedOrderIds.isEmpty) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _orderService.bulkAssignRiderToOrders(
        orderIds: _selectedOrderIds.toList(),
        riderId: rider.id,
        riderName: rider.name,
        riderPhone: rider.phone,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close sheet
        
        setState(() {
          _isSelectionMode = false;
          _selectedOrderIds.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Orders assigned to ${rider.name}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- BULK ACCEPT ---
  Future<void> _bulkAcceptOrders() async {
    if (_selectedOrderIds.isEmpty) return;
    try {
      showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
      await _orderService.bulkAcceptOrders(_selectedOrderIds.toList());
      if (mounted) {
        Navigator.pop(context);
        setState(() { _isSelectionMode = false; _selectedOrderIds.clear(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orders accepted in bulk'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    }
  }

  // --- BULK PACK ---
  Future<void> _bulkMarkAsPacked() async {
    if (_selectedOrderIds.isEmpty) return;
    try {
      showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
      await _orderService.bulkMarkAsPacked(_selectedOrderIds.toList());
      if (mounted) {
        Navigator.pop(context);
        setState(() { _isSelectionMode = false; _selectedOrderIds.clear(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orders marked as packed'), backgroundColor: Colors.blue));
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    }
  }

  // --- BULK CANCEL ---
  Future<void> _bulkCancelOrders() async {
    if (_selectedOrderIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Selected Orders?'),
        content: Text('Are you sure you want to cancel ${_selectedOrderIds.length} orders?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Yes, Cancel')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
        await _orderService.bulkCancelOrders(_selectedOrderIds.toList());
        if (mounted) {
          Navigator.pop(context);
          setState(() { _isSelectionMode = false; _selectedOrderIds.clear(); });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orders cancelled in bulk'), backgroundColor: Colors.orange));
        }
      } catch (e) {
        if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
      }
    }
  }

  // --- BULK LABELS ---
  Future<void> _bulkGenerateLabels() async {
    if (_selectedOrderIds.isEmpty) return;
    try {
      showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
      
      final List<OrderModel> enrichedOrders = [];
      for (String id in _selectedOrderIds) {
        final doc = await FirebaseFirestore.instance.collection('orders').doc(id).get();
        if (doc.exists) {
          final order = OrderModel.fromFirestore(doc);
          enrichedOrders.add(await _enrichmentService.enrichOrderForShippingLabel(order));
        }
      }

      await _pdfService.generateBulkShippingLabels(enrichedOrders);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulk labels generated')));
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    }
  }

  // --- GENERATE SHIPPING LABEL ---
  Future<void> _generateLabel(OrderModel order) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Enrich order with vendor and product barcodes first
      final enrichedOrder = await _enrichmentService.enrichOrderForShippingLabel(order);

      // Generate PDF with enriched order
      await _pdfService.generateShippingLabel(enrichedOrder);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shipping label generated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- CANCEL ORDER ---
  Future<void> _cancelOrder(OrderModel order) async {
    String selectedReason = "";
    final customController = TextEditingController();
    final reasons = ["Out of Stock", "Item Unavailable", "Shop Closed", "Price Error", "Other"];

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order #${order.orderId}?'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text("Select cancellation reason:", style: TextStyle(fontWeight: FontWeight.bold)),
                   ...reasons.map((r) => RadioListTile<String>(
                     title: Text(r),
                     value: r,
                     groupValue: selectedReason,
                     contentPadding: EdgeInsets.zero,
                     onChanged: (val) => setDialogState(() => selectedReason = val!),
                   )),
                   if (selectedReason == 'Other')
                     TextField(
                       controller: customController,
                       decoration: const InputDecoration(
                         labelText: "Enter Reason",
                         border: OutlineInputBorder(),
                       ),
                     )
                ],
              ),
            );
          }
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
               String finalReason = selectedReason == 'Other' ? customController.text : selectedReason;
               if (finalReason.trim().isEmpty) return;
               Navigator.pop(context, finalReason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _orderService.cancelOrder(order.id, reason: result);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // --- ACCEPT ORDER ---
  Future<void> _acceptOrder(OrderModel order) async {
    try {
      await _orderService.markAsProcessing(order.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- MARK AS PACKED ---
  Future<void> _markAsPacked(OrderModel order) async {
    try {
      await _orderService.markAsPacked(order.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as packed'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view orders')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Search Bar
          OrderSearchBar(
            controller: _searchController,
            onChanged: (query) => setState(() => _searchQuery = query.trim().toUpperCase()),
            onClear: () => setState(() {
              _searchController.clear();
              _searchQuery = "";
            }),
          ),
          
          // Stats Card (collapsible)
          if (_showStats)
            StreamBuilder<QuerySnapshot>(
              stream: _orderService.getVendorOrdersStream(currentUser!.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                return OrderStatsCard(
                  orders: snapshot.data!.docs
                      .map((doc) => OrderModel.fromFirestore(doc))
                      .toList(),
                  onDismiss: () => setState(() => _showStats = false),
                );
              },
            ),
          
          // Filter Chips
          OrderFilterChips(
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
          ),
          
          // Order List
          Expanded(
            child: _buildOrdersList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: _isSelectionMode 
          ? Text('${_selectedOrderIds.length} Selected')
          : const Text('Order Management'),
      backgroundColor: _isSelectionMode ? Colors.blueGrey[800] : Colors.deepOrange,
      elevation: 0,
      leading: _isSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedOrderIds.clear();
              }),
            )
          : null,
      actions: [
        if (_isSelectionMode && _selectedOrderIds.isNotEmpty) ...[
          // CONTEXTUAL ACTIONS
          if (_tabController.index == 0) ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
              onPressed: _bulkAcceptOrders,
              tooltip: 'Bulk Accept',
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              onPressed: _bulkCancelOrders,
              tooltip: 'Bulk Cancel',
            ),
          ],
          if (_tabController.index == 1) ...[
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent),
              onPressed: _bulkMarkAsPacked,
              tooltip: 'Bulk Pack',
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined, color: Colors.white),
              onPressed: _bulkGenerateLabels,
              tooltip: 'Bulk Labels',
            ),
          ],
          if (_tabController.index == 2) ...[
            IconButton(
              icon: const Icon(Icons.delivery_dining, color: Colors.white),
              onPressed: () => _showRiderSelection(null),
              tooltip: 'Bulk Assign',
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined, color: Colors.white),
              onPressed: _bulkGenerateLabels,
              tooltip: 'Bulk Labels',
            ),
          ],
          if (_tabController.index == 3) ...[
             IconButton(
              icon: const Icon(Icons.print_outlined, color: Colors.white),
              onPressed: _bulkGenerateLabels,
              tooltip: 'Bulk Labels',
            ),
          ],
        ],
        
        IconButton(
          icon: Icon(_isSelectionMode ? Icons.check_box : Icons.library_add_check),
          onPressed: () => setState(() => _isSelectionMode = !_isSelectionMode),
          tooltip: 'Selection Mode',
        ),
        if (!_isSelectionMode) ...[
          IconButton(
            icon: Icon(_showStats ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showStats = !_showStats),
            tooltip: 'Toggle Stats',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Pending'),
          Tab(text: 'Processing'),
          Tab(text: 'Packed'),
          Tab(text: 'Shipped'),
          Tab(text: 'Out for Delivery'),
          Tab(text: 'Delivered'),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedOrders == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError && _cachedOrders == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No orders yet', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        // Update cache on new data
        if (snapshot.hasData) {
          _cachedOrders = snapshot.data!.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();
        }

        List<OrderModel> allOrders = _cachedOrders ?? [];

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          allOrders = allOrders
              .where((order) => order.orderId.toUpperCase().contains(_searchQuery))
              .toList();
        }

        // Apply date/type filters
        allOrders = _applyFilters(allOrders);

        // Sort by date (newest first)
        allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Split by status for tabs
        final pendingOrders = allOrders.where((o) => o.status == 'Pending').toList();
        final processingOrders = allOrders.where((o) => o.status == 'Processing').toList();
        final packedOrders = allOrders.where((o) => o.status == 'Packed').toList();
        final shippedOrders = allOrders.where((o) => o.status == 'Shipped').toList();
        final outForDeliveryOrders = allOrders.where((o) => o.status == 'Out for Delivery').toList();
        final deliveredOrders = allOrders.where((o) => 
            o.status == 'Delivered' || o.status == 'Completed' || o.status == 'Cancelled'
        ).toList();

        return TabBarView(
          controller: _tabController,
          children: [
            _buildOrderList(pendingOrders, 'Pending'),
            _buildOrderList(processingOrders, 'Processing'),
            _buildOrderList(packedOrders, 'Packed'),
            _buildOrderList(shippedOrders, 'Shipped'),
            _buildOrderList(outForDeliveryOrders, 'Out for Delivery'),
            _buildOrderList(deliveredOrders, 'Delivered'),
          ],
        );
      },
    );
  }

  Widget _buildOrderList(List<OrderModel> orders, String status) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No $status orders', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedOrderIds.contains(order.id),
          onSelected: (val) {
            setState(() {
              if (val == true) {
                if (_selectedOrderIds.length < 10) {
                  _selectedOrderIds.add(order.id);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Maximum 10 orders can be selected')),
                  );
                }
              } else {
                _selectedOrderIds.remove(order.id);
              }
            });
          },
          onAssignRider: () => _showRiderSelection(order),
          onGenerateLabel: () => _generateLabel(order),
          onCancelOrder: () => _cancelOrder(order),
          onAcceptOrder: () => _acceptOrder(order),
          onMarkAsPacked: () => _markAsPacked(order),
          onViewDetails: () {
            // Navigate to order details
            // Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)));
          },
        );
      },
    );
  }

  List<OrderModel> _applyFilters(List<OrderModel> orders) {
    switch (_selectedFilter) {
      case 'today':
        final today = DateTime.now();
        return orders.where((o) {
          final orderDate = o.createdAt;
          return orderDate.year == today.year &&
              orderDate.month == today.month &&
              orderDate.day == today.day;
        }).toList();
      
      case 'standard':
        return orders.where((o) => o.deliveryMode == 'Standard').toList();
      
      case 'instant':
        return orders.where((o) => 
            o.deliveryMode == 'Instant' || o.deliveryMode == 'Express'
        ).toList();
      
      case 'cod':
        return orders.where((o) => o.paymentMethod == 'COD').toList();
      
      case 'online':
        return orders.where((o) => o.paymentMethod != 'COD').toList();
      
      default:
        return orders;
    }
  }
}