import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'package:kirihat_core/services/fee_configuration_service.dart';
import 'seller_report_service.dart';
import 'seller_calculations.dart';
import 'package:kirihat_core/utils/currency_helper.dart';
import 'package:fl_chart/fl_chart.dart';

/// Enhanced Professional Analytics Screen
/// Features: Profit/Loss tracking, Charts, Advanced metrics, Comparisons, Export
class EnhancedSellerAnalyticsScreen extends StatefulWidget {
  final SellerModel seller;

  const EnhancedSellerAnalyticsScreen({super.key, required this.seller});

  @override
  State<EnhancedSellerAnalyticsScreen> createState() => _EnhancedSellerAnalyticsScreenState();
}

class _EnhancedSellerAnalyticsScreenState extends State<EnhancedSellerAnalyticsScreen> {
  final SellerService _sellerService = SellerService();
  final SellerReportService _reportService = SellerReportService();
  final FeeConfigurationService _feeService = FeeConfigurationService();
  
  // State
  String _selectedRange = 'Today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  
  // Comprehensive metrics
  SellerDashboardMetrics? _metrics;
  List<Map<String, dynamic>> _orders = [];
  Map<String, double> _dailySales = {}; // For charts
  bool _isLoading = true;
  
  // View options
  bool _showCharts = true;
  String _chartType = 'revenue'; // 'revenue', 'profit', 'orders'

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final dateRange = _getDateRange();
    final start = dateRange['start']!;
    final end = dateRange['end']!;

    try {
      // Fetch dynamic platform fee configuration
      final platformFeePercentage = await _feeService.getPlatformFeePercentage();
      final platformFeeDecimal = platformFeePercentage / 100; // Convert % to decimal
      
      // 1. Fetch Master Products (Real Inventory Source)
      // We do this first to build the Price/Cost Map
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('master_products')
          .where('seller_id', isEqualTo: widget.seller.id)
          .get();

      // Build Price Map: productId -> {cost, mrp, selling}
      Map<String, Map<String, double>> productPriceMap = {};
      
      // Calculate inventory metrics
      int totalProducts = 0;
      int lowStock = 0;
      int outOfStock = 0;
      double inventoryValue = 0;

      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        totalProducts++;
        
        final stock = ((data['stock_quantity'] ?? 0) as num).toDouble();
        
        // Extract pricing info
        final costPrice = ((data['cost_price'] ?? 0) as num).toDouble();
        final mrp = ((data['mrp'] ?? 0) as num).toDouble();
        final sellingPrice = ((data['selling_price'] ?? 0) as num).toDouble();
        
        productPriceMap[doc.id] = {
          'cost_price': costPrice,
          'mrp': mrp,
          'selling_price': sellingPrice,
        };
        
        inventoryValue += SellerCalculations.calculateInventoryValue(
          costPrice: costPrice > 0 ? costPrice : sellingPrice * 0.7, // Fallback estimation for value if cost missing
          stockQuantity: stock,
        );
        
        if (stock <= 0) {
          outOfStock++;
        } else if (stock < 10) {
          lowStock++;
        }
      }

      // 2. Fetch Orders
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('seller_ids', arrayContains: widget.seller.id)
          .orderBy('created_at', descending: true)
          .get();

      // Process data
      List<Map<String, dynamic>> filteredOrders = [];
      double totalRevenue = 0;
      double totalCost = 0;
      double totalProfit = 0;
      double totalDiscounts = 0;
      double cancelledValue = 0;
      int cancelledCount = 0;
      Map<String, double> dailyRevenue = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final created = (data['created_at'] as Timestamp).toDate();
        
        if (created.isAfter(start) && created.isBefore(end.add(const Duration(days: 1)))) {
          final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
          final myItems = items.where((i) => i['seller_id'] == widget.seller.id).toList();
          
          if (myItems.isNotEmpty) {
            // Extract fee snapshot from order (for historical accuracy)
            // If snapshot exists, use it; otherwise fall back to current fees
            final feeSnapshot = data['fees_snapshot'] as Map<String, dynamic>?;
            final orderPlatformFeePercent = feeSnapshot != null 
                ? (feeSnapshot['platform_fee_percentage'] as num?)?.toDouble() ?? platformFeePercentage
                : platformFeePercentage;
            final orderPlatformFeeDecimal = orderPlatformFeePercent / 100;
            
            double orderRevenue = 0;
            double orderCost = 0;
            double orderDiscount = 0;
            
            for (var item in myItems) {
              final quantity = (item['quantity'] ?? 1) as int;
              
              // 1. Seller Base Price (Revenue) - CRITICAL: Use seller's price, not vendor's!
              // Priority: seller_base_price > selling_price (old orders) > master_products fallback
              double sellingPrice = ((item['seller_base_price'] ?? item['selling_price'] ?? item['price'] ?? 0) as num).toDouble();
              
              // If still missing, recover from master_products (for old orders)
              if (sellingPrice == 0 || item['seller_base_price'] == null) {
                String? productId = item['product_id'] ?? item['id'];
                if (productId != null && productPriceMap.containsKey(productId)) {
                  sellingPrice = productPriceMap[productId]!['selling_price'] ?? 0;
                }
              }
              
              // 2. Cost Price (Priority: Order Item > Master Product Map > Fallback)
              double? costPrice = (item['cost_price'] as num?)?.toDouble();
              
              // If missing in order item (old orders), look up in master product map
              if (costPrice == null || costPrice == 0) {
                String? productId = item['product_id'] ?? item['id'];
                if (productId != null && productPriceMap.containsKey(productId)) {
                  costPrice = productPriceMap[productId]!['cost_price'];
                }
              }
              
              // Safety fallback using helper
              final safeCostPrice = SellerCalculations.getSafeCostPrice(
                costPrice: costPrice,
                sellingPrice: sellingPrice,
              );

              // 3. MRP (For discount calc) - Try item first, then product map
              double mrp = ((item['mrp'] ?? 0) as num).toDouble();
              if (mrp == 0) {
                String? productId = item['product_id'] ?? item['id'];
                if (productId != null && productPriceMap.containsKey(productId)) {
                  mrp = productPriceMap[productId]!['mrp'] ?? sellingPrice;
                }
              }
              if (mrp < sellingPrice) mrp = sellingPrice;

              final financials = SellerCalculations.calculateOrderFinancials(
                sellingPrice: sellingPrice,
                costPrice: safeCostPrice,
                mrp: mrp,
                quantity: quantity,
                platformFeePercentage: orderPlatformFeeDecimal, // Use order's snapshot fee
              );
              
              orderRevenue += financials.revenue;
              orderCost += financials.cost;
              orderDiscount += financials.discount;
            }
            
            final status = data['status'] ?? 'Pending';
            
            // Track daily revenue for charts
            final dayKey = DateFormat('yyyy-MM-dd').format(created);
            dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + orderRevenue;
            
            if (status == 'Cancelled' || status == 'Rejected') {
              cancelledValue += orderRevenue;
              cancelledCount++;
            } else if (status == 'Delivered') {
              totalRevenue += orderRevenue;
              totalCost += orderCost;
              totalDiscounts += orderDiscount;
            }
            
            // Calculate profit for display - zero out for cancelled/rejected orders
            final displayProfit = (status == 'Cancelled' || status == 'Rejected') 
                ? 0.0 
                : (orderRevenue - orderCost - (orderRevenue * orderPlatformFeeDecimal)); // Use order's snapshot fee
            
            filteredOrders.add({
              'order_id': data['order_id'] ?? doc.id,
              'created_at': created,
              'status': status,
              'revenue': orderRevenue,
              'cost': orderCost,
              'discount': orderDiscount,
              'profit': displayProfit,
              'items': myItems,
              'has_fee_snapshot': feeSnapshot != null, // Track if using historical fees
              'platform_fee_used': orderPlatformFeePercent, // Show which fee was used
            });
          }
        }
      }

      // Calculate platform fees using dynamic rate
      final platformFees = totalRevenue * platformFeeDecimal;
      totalProfit = totalRevenue - totalCost - platformFees;

      // Calculate aggregated metrics
      final deliveredOrders = filteredOrders.where((o) => o['status'] == 'Delivered').length;
      final avgOrderValue = deliveredOrders > 0 ? totalRevenue / deliveredOrders : 0.0;
      final avgProfitMargin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
      final roi = totalCost > 0 ? (totalProfit / totalCost) * 100 : 0.0;
      final avgDiscountPercent = (totalDiscounts + totalRevenue) > 0 
          ? (totalDiscounts / (totalRevenue + totalDiscounts)) * 100 
          : 0.0;

      if (mounted) {
        setState(() {
          _metrics = SellerDashboardMetrics(
            totalRevenue: totalRevenue,
            averageOrderValue: avgOrderValue,
            totalOrders: deliveredOrders,
            totalProfit: totalProfit,
            totalCost: totalCost,
            averageProfitMarginPercentage: avgProfitMargin,
            roi: roi,
            totalDiscountsGiven: totalDiscounts,
            averageDiscountPercentage: avgDiscountPercent,
            cancelledOrdersValue: cancelledValue,
            platformFeesTotal: platformFees,
            cancelledOrdersCount: cancelledCount,
            totalInventoryValue: inventoryValue,
            totalProductsCount: totalProducts,
            lowStockCount: lowStock,
            outOfStockCount: outOfStock,
          );
          _orders = filteredOrders;
          _dailySales = dailyRevenue;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading analytics: $e\n$stack');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, DateTime> _getDateRange() {
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (_selectedRange) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Yesterday':
        start = DateTime(now.year, now.month, now.day - 1);
        end = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        start = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        start = now.subtract(const Duration(days: 30));
        break;
      case 'Quarter':
        start = now.subtract(const Duration(days: 90));
        break;
      case 'Year':
        start = now.subtract(const Duration(days: 365));
        break;
      case 'Custom':
        start = _customStartDate ?? now.subtract(const Duration(days: 30));
        end = _customEndDate ?? now;
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }

    return {'start': start, 'end': end};
  }

  Future<void> _generateReport() async {
    if (_metrics == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating detailed report...')),
    );
    
    final dateRange = _getDateRange();
    
    await _reportService.generatePdfReport(
      seller: widget.seller,
      orders: _orders,
      startDate: dateRange['start']!,
      endDate: dateRange['end']!,
      totalRevenue: _metrics!.totalRevenue,
      platformFees: _metrics!.platformFeesTotal,
      netEarnings: _metrics!.netEarnings,
    );
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _customEndDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedRange = 'Custom';
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_metrics == null)
            SliverFillRemaining(child: _buildErrorState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Key Metrics Cards
                  _buildKeyMetricsSection(),
                  const SizedBox(height: 20),
                  
                  // Financial Overview
                  _buildFinancialOverview(),
                  const SizedBox(height: 20),
                  
                  // Charts
                  if (_showCharts) ...[
                    _buildChartsSection(),
                    const SizedBox(height: 20),
                  ],
                  
                  // Performance Indicators
                  _buildPerformanceIndicators(),
                  const SizedBox(height: 20),
                  
                  // Inventory Summary
                  _buildInventorySummary(),
                  const SizedBox(height: 20),
                  
                  // Recent Orders
                  _buildRecentOrders(),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D9759), Color(0xFF075E3B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales Analytics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getDateRangeText(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Time range selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRangeChip('Today'),
                    const SizedBox(width: 8),
                    _buildRangeChip('Yesterday'),
                    const SizedBox(width: 8),
                    _buildRangeChip('Week'),
                    const SizedBox(width: 8),
                    _buildRangeChip('Month'),
                    const SizedBox(width: 8),
                    _buildRangeChip('Quarter'),
                    const SizedBox(width: 8),
                    _buildRangeChip('Year'),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _selectCustomDateRange,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(_selectedRange == 'Custom' ? 'Custom Range' : 'Custom'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _selectedRange == 'Custom' 
                            ? Colors.white 
                            : Colors.grey[700],
                        backgroundColor: _selectedRange == 'Custom' 
                            ? const Color(0xFF0D9759) 
                            : null,
                        side: BorderSide(
                          color: _selectedRange == 'Custom' 
                              ? const Color(0xFF0D9759) 
                              : Colors.grey[300]!,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() => _showCharts = !_showCharts);
                    },
                    icon: Icon(
                      _showCharts ? Icons.table_chart : Icons.bar_chart,
                      color: const Color(0xFF0D9759),
                    ),
                    tooltip: _showCharts ? 'Hide Charts' : 'Show Charts',
                  ),
                  IconButton(
                    onPressed: _fetchData,
                    icon: const Icon(Icons.refresh, color: Color(0xFF0D9759)),
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: _generateReport,
                    icon: const Icon(Icons.download, color: Color(0xFF0D9759)),
                    tooltip: 'Export Report',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDateRangeText() {
    final dateRange = _getDateRange();
    final formatter = DateFormat('MMM dd, yyyy');
    
    if (_selectedRange == 'Today') {
      return 'Today - ${formatter.format(DateTime.now())}';
    } else if (_selectedRange == 'Yesterday') {
      return 'Yesterday - ${formatter.format(DateTime.now().subtract(const Duration(days: 1)))}';
    }
    
    return '${formatter.format(dateRange['start']!)} - ${formatter.format(dateRange['end']!)}';
  }

  Widget _buildRangeChip(String label) {
    final isSelected = _selectedRange == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedRange = label);
        _fetchData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9759) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9759) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildKeyMetricsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns: 1 for very small, 2 for mobile, 4 for desktop
        int crossAxisCount = 4;
        double childAspectRatio = 1.5;
        
        if (constraints.maxWidth < 400) {
          crossAxisCount = 1;
          childAspectRatio = 2.0; // Changed from 2.5 to prevent bottom overflow
        } else if (constraints.maxWidth < 700) {
          crossAxisCount = 2;
          childAspectRatio = 1.6; // Changed from 1.8 for better fit
        } else if (constraints.maxWidth < 1000) {
          crossAxisCount = 2;
          childAspectRatio = 1.4; // Changed from 1.5
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Key Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: constraints.maxWidth < 600 ? 8 : 16,
              mainAxisSpacing: constraints.maxWidth < 600 ? 8 : 16,
              childAspectRatio: childAspectRatio,
              children: [
                _buildMetricCard(
                  'Total Revenue',
                  CurrencyHelper.format(_metrics!.totalRevenue),
                  Icons.currency_rupee,
                  Colors.green,
                  subtitle: '${_metrics!.totalOrders} orders',
                ),
                _buildMetricCard(
                  'Net Profit',
                  CurrencyHelper.format(_metrics!.totalProfit),
                  Icons.trending_up,
                  _metrics!.totalProfit >= 0 ? Colors.green : Colors.red,
                  subtitle: '${_metrics!.averageProfitMarginPercentage.toStringAsFixed(1)}% margin',
                ),
                _buildMetricCard(
                  'Avg Order Value',
                  CurrencyHelper.format(_metrics!.averageOrderValue),
                  Icons.shopping_cart,
                  Colors.blue,
                  subtitle: 'per order',
                ),
                _buildMetricCard(
                  'ROI',
                  '${_metrics!.roi.toStringAsFixed(1)}%',
                  Icons.percent,
                  _metrics!.roi >= 0 ? Colors.green : Colors.red,
                  subtitle: 'return on investment',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isVerySmall = constraints.maxWidth < 400;
              
              if (isVerySmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Financial Breakdown',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _metrics!.totalProfit >= 0 
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _metrics!.totalProfit >= 0 
                                ? Icons.trending_up 
                                : Icons.trending_down,
                            size: 16,
                            color: _metrics!.totalProfit >= 0 ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _metrics!.totalProfit >= 0 ? 'Profitable' : 'Loss',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _metrics!.totalProfit >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Financial Breakdown',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _metrics!.totalProfit >= 0 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _metrics!.totalProfit >= 0 
                              ? Icons.trending_up 
                              : Icons.trending_down,
                          size: 16,
                          color: _metrics!.totalProfit >= 0 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _metrics!.totalProfit >= 0 ? 'Profitable' : 'Loss',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _metrics!.totalProfit >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 30),
          _buildFinanceRow('Gross Revenue', _metrics!.totalRevenue, Colors.black),
          const SizedBox(height: 12),
          _buildFinanceRow('Cost of Goods', -_metrics!.totalCost, Colors.orange),
          const SizedBox(height: 12),
          _buildFinanceRow('Platform Fees (10%)', -_metrics!.platformFeesTotal, Colors.red[300]!),
          const SizedBox(height: 12),
          _buildFinanceRow('Discounts Given', -_metrics!.totalDiscountsGiven, Colors.purple[300]!),
          const Divider(height: 30),
          _buildFinanceRow(
            'Gross Profit',
            _metrics!.grossProfit,
            _metrics!.grossProfit >= 0 ? Colors.green : Colors.red,
            isBold: true,
          ),
          const SizedBox(height: 12),
          _buildFinanceRow(
            'Net Profit (After Fees)',
            _metrics!.totalProfit,
            _metrics!.totalProfit >= 0 ? const Color(0xFF0D9759) : Colors.red,
            isBold: true,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(
    String label,
    double amount,
    Color color, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    final formatted = CurrencyHelper.format(amount.abs());
    final display = amount < 0 ? '- $formatted' : formatted;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: isLarge ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          display,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isLarge ? 18 : (isBold ? 16 : 14),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isVerySmall = constraints.maxWidth < 400;
              
              if (isVerySmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sales Trend',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'revenue', label: Text('Revenue'), icon: Icon(Icons.currency_rupee, size: 16)),
                          ButtonSegment(value: 'orders', label: Text('Orders'), icon: Icon(Icons.shopping_bag, size: 16)),
                        ],
                        selected: {_chartType},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() => _chartType = selection.first);
                        },
                      ),
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sales Trend',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'revenue', label: Text('Revenue'), icon: Icon(Icons.currency_rupee, size: 16)),
                      ButtonSegment(value: 'orders', label: Text('Orders'), icon: Icon(Icons.shopping_bag, size: 16)),
                    ],
                    selected: {_chartType},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() => _chartType = selection.first);
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: _buildLineChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    if (_dailySales.isEmpty) {
      return const Center(child: Text('No data available for chart'));
    }

    // Prepare data points
    final sortedDates = _dailySales.keys.toList()..sort();
    final spots = <FlSpot>[];
    
    for (int i = 0; i < sortedDates.length; i++) {
      final value = _dailySales[sortedDates[i]] ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getChartInterval(),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  CurrencyHelper.format(value),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (sortedDates.length / 7).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedDates.length) {
                  final date = DateTime.parse(sortedDates[index]);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MMM dd').format(date),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF0D9759),
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0D9759).withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = DateTime.parse(sortedDates[spot.x.toInt()]);
                return LineTooltipItem(
                  '${DateFormat('MMM dd').format(date)}\n${CurrencyHelper.format(spot.y)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _getChartInterval() {
    if (_dailySales.isEmpty) return 1000;
    final maxValue = _dailySales.values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return 10; // Default interval if all values are 0
    double interval = (maxValue / 5).ceilToDouble();
    return interval > 0 ? interval : 10; // Ensure strictly positive
  }

  Widget _buildPerformanceIndicators() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Indicators',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              
              if (isSmall) {
                return Column(
                  children: [
                    _buildPerformanceBar(
                      'Profit Margin',
                      _metrics!.averageProfitMarginPercentage,
                      100,
                      _metrics!.averageProfitMarginPercentage >= 20 ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildPerformanceBar(
                      'Avg Discount',
                      _metrics!.averageDiscountPercentage,
                      50,
                      Colors.purple,
                    ),
                    const SizedBox(height: 16),
                    _buildPerformanceBar(
                      'ROI',
                      _metrics!.roi,
                      100,
                      _metrics!.roi >= 50 ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildPerformanceBar(
                      'Order Success Rate',
                      _metrics!.totalOrders > 0 
                          ? ((_metrics!.totalOrders / (_metrics!.totalOrders + _metrics!.cancelledOrdersCount)) * 100)
                          : 0,
                      100,
                      Colors.blue,
                    ),
                  ],
                );
              }
              
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPerformanceBar(
                          'Profit Margin',
                          _metrics!.averageProfitMarginPercentage,
                          100,
                          _metrics!.averageProfitMarginPercentage >= 20 ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildPerformanceBar(
                          'Avg Discount',
                          _metrics!.averageDiscountPercentage,
                          50,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPerformanceBar(
                          'ROI',
                          _metrics!.roi,
                          100,
                          _metrics!.roi >= 50 ? Colors.green : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildPerformanceBar(
                          'Order Success Rate',
                          _metrics!.totalOrders > 0 
                              ? ((_metrics!.totalOrders / (_metrics!.totalOrders + _metrics!.cancelledOrdersCount)) * 100)
                              : 0,
                          100,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBar(String label, double value, double maxValue, Color color) {
    final percentage = (value / maxValue * 100).clamp(0, 100);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildInventorySummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventory Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              
              if (isSmall) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInventoryMetric(
                            'Total Products',
                            '${_metrics!.totalProductsCount}',
                            Icons.inventory_2,
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildInventoryMetric(
                            'Inventory Value',
                            CurrencyHelper.format(_metrics!.totalInventoryValue),
                            Icons.currency_rupee,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInventoryMetric(
                            'Low Stock',
                            '${_metrics!.lowStockCount}',
                            Icons.warning_amber,
                            Colors.orange,
                          ),
                        ),
                        Expanded(
                          child: _buildInventoryMetric(
                            'Out of Stock',
                            '${_metrics!.outOfStockCount}',
                            Icons.error_outline,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildInventoryMetric(
                      'Total Products',
                      '${_metrics!.totalProductsCount}',
                      Icons.inventory_2,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildInventoryMetric(
                      'Inventory Value',
                      CurrencyHelper.format(_metrics!.totalInventoryValue),
                      Icons.currency_rupee,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildInventoryMetric(
                      'Low Stock',
                      '${_metrics!.lowStockCount}',
                      Icons.warning_amber,
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildInventoryMetric(
                      'Out of Stock',
                      '${_metrics!.outOfStockCount}',
                      Icons.error_outline,
                      Colors.red,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full orders list
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_orders.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orders.take(5).length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final order = _orders[index];
                return _buildOrderTile(order);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(Map<String, dynamic> order) {
    final status = order['status'];
    Color statusColor = Colors.grey;
    if (status == 'Delivered') {
      statusColor = Colors.green;
    } else if (status == 'Pending') {
      statusColor = Colors.orange;
    } else if (status == 'Cancelled') {
      statusColor = Colors.red;
    }

    final profit = (order['profit'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 20,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          
          // Main Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order['order_id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      CurrencyHelper.format(order['revenue']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(order['created_at']),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    Text(
                      '${(order['items'] as List).length} items',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Profit: ${CurrencyHelper.format(profit)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: profit >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No data available for $_selectedRange',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Failed to load analytics'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}