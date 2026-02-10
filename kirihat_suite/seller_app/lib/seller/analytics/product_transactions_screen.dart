import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kirihat_core/utils/currency_helper.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:fl_chart/fl_chart.dart';

/// Enhanced Product-wise transaction screen
/// Professional analytics with charts, filters, and insights
class EnhancedProductTransactionsScreen extends StatefulWidget {
  final SellerModel seller;

  const EnhancedProductTransactionsScreen({super.key, required this.seller});

  @override
  State<EnhancedProductTransactionsScreen> createState() => _EnhancedProductTransactionsScreenState();
}

class _EnhancedProductTransactionsScreenState extends State<EnhancedProductTransactionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _productTransactions = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  
  // Filters
  String _searchQuery = '';
  String _sortBy = 'transactions'; // transactions, revenue, profit, units
  bool _sortAscending = false;
  String _timeRange = 'All Time';
  
  // View options
  bool _isGridView = false;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProductTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProductTransactions() async {
    setState(() => _isLoading = true);

    try {
      // Get date range
      final dateRange = _getDateRange();
      
      // 1. Fetch all master products for this seller
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('master_products')
          .where('seller_id', isEqualTo: widget.seller.id)
          .get();

      // 2. Fetch all orders containing seller's products
      QuerySnapshot ordersSnapshot;
      if (_timeRange == 'All Time') {
        ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('seller_ids', arrayContains: widget.seller.id)
            .get();
      } else {
        ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('seller_ids', arrayContains: widget.seller.id)
            .where('created_at', isGreaterThan: Timestamp.fromDate(dateRange['start']!))
            .get();
      }

      // 3. Aggregate transaction data per product
      Map<String, Map<String, dynamic>> productData = {};

      for (var productDoc in productsSnapshot.docs) {
        final productId = productDoc.id;
        final productInfo = productDoc.data();

        productData[productId] = {
          'product_id': productId,
          'name': productInfo['name'] ?? 'Unknown Product',
          'image_url': productInfo['image_url'] ?? 
              ((productInfo['images'] as List?)?.isNotEmpty == true ? productInfo['images'][0] : null) ??
              ((productInfo['image_urls'] as List?)?.isNotEmpty == true ? productInfo['image_urls'][0] : null),
          'category': productInfo['category'] ?? 'Uncategorized',
          'sku': productInfo['sku'] ?? '',
          'transactions': 0,
          'total_units_sold': 0,
          'total_revenue': 0.0,
          'total_cost': 0.0,
          'total_profit': 0.0,
          'avg_selling_price': 0.0,
          'profit_margin': 0.0,
          'cancelled_count': 0,
          'pending_count': 0,
        };
      }

      // 4. Process orders to count transactions
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
        final myItems = items.where((i) => i['seller_id'] == widget.seller.id);
        final status = orderData['status'] ?? 'Pending';
        
        // Extract fee snapshot (if available)
        final feeSnapshot = orderData['fees_snapshot'] as Map<String, dynamic>?;
        final platformFeePercent = feeSnapshot != null 
            ? (feeSnapshot['platform_fee_percentage'] as num?)?.toDouble() ?? 10.0
            : 10.0;

        for (var item in myItems) {
          String? productId = item['product_id'] ?? item['id'];
          if (productId == null || !productData.containsKey(productId)) continue;

          final quantity = (item['quantity'] ?? 1) as int;
          final sellingPrice = ((item['seller_base_price'] ?? item['selling_price'] ?? item['price'] ?? 0) as num).toDouble();
          final costPrice = ((item['cost_price'] ?? 0) as num).toDouble();

          final revenue = sellingPrice * quantity;
          final cost = costPrice * quantity;
          final platformFee = revenue * (platformFeePercent / 100);
          final profit = revenue - cost - platformFee;

          // Count all transactions
          productData[productId]!['transactions'] = (productData[productId]!['transactions'] as int) + 1;
          
          if (status == 'Delivered') {
            productData[productId]!['total_units_sold'] = (productData[productId]!['total_units_sold'] as int) + quantity;
            productData[productId]!['total_revenue'] = (productData[productId]!['total_revenue'] as double) + revenue;
            productData[productId]!['total_cost'] = (productData[productId]!['total_cost'] as double) + cost;
            productData[productId]!['total_profit'] = (productData[productId]!['total_profit'] as double) + profit;
          } else if (status == 'Cancelled') {
            productData[productId]!['cancelled_count'] = (productData[productId]!['cancelled_count'] as int) + 1;
          } else if (status == 'Pending') {
            productData[productId]!['pending_count'] = (productData[productId]!['pending_count'] as int) + 1;
          }
        }
      }

      // Calculate averages and margins
      productData.forEach((key, value) {
        final unitsSold = value['total_units_sold'] as int;
        final revenue = value['total_revenue'] as double;
        final profit = value['total_profit'] as double;
        
        if (unitsSold > 0) {
          value['avg_selling_price'] = revenue / unitsSold;
        }
        if (revenue > 0) {
          value['profit_margin'] = (profit / revenue) * 100;
        }
      });

      if (mounted) {
        setState(() {
          _productTransactions = productData.values.toList();
          _applyFiltersAndSort();
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      
      // Only print index creation links when they appear
      if (errorMessage.contains('console.firebase.google.com') || 
          errorMessage.contains('requires an index')) {
        print('═══════════════════════════════════════════════════════════════');
        print('🔥 FIREBASE INDEX REQUIRED:');
        print('$e');
        print('───────────────────────────────────────────────────────────────');
        print('Click the link above to create the index. Wait 1-5 mins after.');
        print('═══════════════════════════════════════════════════════════════');
      } else {
        debugPrint('Error loading transactions: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage.contains('index') 
                ? 'Index building... wait 1-5 mins, then refresh.'
                : 'Error loading transactions: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Map<String, DateTime> _getDateRange() {
    DateTime now = DateTime.now();
    DateTime start;

    switch (_timeRange) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
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
      default:
        start = DateTime(2020); // All time
    }

    return {'start': start, 'end': now};
  }

  void _applyFiltersAndSort() {
    // Filter by search
    var filtered = _productTransactions.where((product) {
      if (_searchQuery.isEmpty) return true;
      final name = (product['name'] as String).toLowerCase();
      final sku = (product['sku'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || sku.contains(query);
    }).toList();

    // Sort
    filtered.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'revenue':
          result = (a['total_revenue'] as double).compareTo(b['total_revenue'] as double);
          break;
        case 'profit':
          result = (a['total_profit'] as double).compareTo(b['total_profit'] as double);
          break;
        case 'units':
          result = (a['total_units_sold'] as int).compareTo(b['total_units_sold'] as int);
          break;
        case 'margin':
          result = (a['profit_margin'] as double).compareTo(b['profit_margin'] as double);
          break;
        case 'transactions':
        default:
          result = (a['transactions'] as int).compareTo(b['transactions'] as int);
      }
      return _sortAscending ? result : -result;
    });

    setState(() {
      _filteredProducts = filtered;
    });
  }

  Map<String, dynamic> _calculateSummary() {
    final totalTransactions = _filteredProducts.fold<int>(
      0, (sum, p) => sum + (p['transactions'] as int)
    );
    final totalRevenue = _filteredProducts.fold<double>(
      0, (sum, p) => sum + (p['total_revenue'] as double)
    );
    final totalProfit = _filteredProducts.fold<double>(
      0, (sum, p) => sum + (p['total_profit'] as double)
    );
    final totalUnits = _filteredProducts.fold<int>(
      0, (sum, p) => sum + (p['total_units_sold'] as int)
    );
    final avgMargin = _filteredProducts.isNotEmpty
        ? _filteredProducts.fold<double>(0, (sum, p) => sum + (p['profit_margin'] as double)) / _filteredProducts.length
        : 0.0;

    return {
      'transactions': totalTransactions,
      'revenue': totalRevenue,
      'profit': totalProfit,
      'units': totalUnits,
      'margin': avgMargin,
      'products': _filteredProducts.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final summary = _calculateSummary();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;
          
          return CustomScrollView(
            slivers: [
              _buildAppBar(summary, isSmall),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.all(isSmall ? 16 : 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Summary Cards
                      _buildSummaryCards(summary, isSmall),
                      const SizedBox(height: 20),
                      
                      // Top Products Chart
                      _buildTopProductsChart(isSmall),
                      const SizedBox(height: 20),
                      
                      // Products List/Grid
                      _buildProductsList(isSmall),
                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(Map<String, dynamic> summary, bool isSmall) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: isSmall ? 160 : 200,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D9759), Color(0xFF075E3B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.fromLTRB(isSmall ? 16 : 20, 80, isSmall ? 16 : 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product Performance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmall ? 22 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${summary['products']} products • ${summary['transactions']} transactions',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: isSmall ? 12 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(isSmall ? 110 : 120),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Search and filters
              Row(
                children: [
                  Expanded(child: _buildSearchBar()),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, size: isSmall ? 20 : 24),
                    onPressed: () => setState(() => _isGridView = !_isGridView),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, size: isSmall ? 20 : 24),
                    onPressed: _loadProductTransactions,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Time range and sort
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTimeRangeChip('All Time'),
                    const SizedBox(width: 8),
                    _buildTimeRangeChip('Today'),
                    const SizedBox(width: 8),
                    _buildTimeRangeChip('Week'),
                    const SizedBox(width: 8),
                    _buildTimeRangeChip('Month'),
                    const SizedBox(width: 8),
                    _buildTimeRangeChip('Quarter'),
                    const SizedBox(width: 16),
                    const Text('Sort by:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    _buildSortChip('Transactions', 'transactions'),
                    const SizedBox(width: 8),
                    _buildSortChip('Revenue', 'revenue'),
                    const SizedBox(width: 8),
                    _buildSortChip('Profit', 'profit'),
                    const SizedBox(width: 8),
                    _buildSortChip('Units', 'units'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
          _applyFiltersAndSort();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search products...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _applyFiltersAndSort();
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildTimeRangeChip(String label) {
    final isSelected = _timeRange == label;
    return GestureDetector(
      onTap: () {
        setState(() => _timeRange = label);
        _loadProductTransactions();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9759) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = false;
          }
          _applyFiltersAndSort();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: Colors.blue,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary, bool isSmall) {
    return GridView.count(
      crossAxisCount: isSmall ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: isSmall ? 12 : 16,
      mainAxisSpacing: isSmall ? 12 : 16,
      childAspectRatio: isSmall ? 1.4 : 1.3,
      children: [
        _buildSummaryCard(
          'Total Revenue',
          CurrencyHelper.format(summary['revenue']),
          Icons.currency_rupee,
          Colors.green,
          isSmall,
        ),
        _buildSummaryCard(
          'Total Profit',
          CurrencyHelper.format(summary['profit']),
          Icons.trending_up,
          summary['profit'] >= 0 ? Colors.green : Colors.red,
          isSmall,
        ),
        _buildSummaryCard(
          'Units Sold',
          '${summary['units']}',
          Icons.inventory_2,
          Colors.blue,
          isSmall,
        ),
        _buildSummaryCard(
          'Avg Margin',
          '${summary['margin'].toStringAsFixed(1)}%',
          Icons.percent,
          Colors.purple,
          isSmall,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 6 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: isSmall ? 16 : 20, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmall ? 14 : 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmall ? 10 : 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsChart(bool isSmall) {
    if (_filteredProducts.isEmpty) return const SizedBox.shrink();

    // Get top 5 products by revenue
    final topProducts = List<Map<String, dynamic>>.from(_filteredProducts)
      ..sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
    final top5 = topProducts.take(5).toList();

    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 5 Products by Revenue',
            style: TextStyle(fontSize: isSmall ? 14 : 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: isSmall ? 180 : 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: top5.isNotEmpty 
                    ? (top5.first['total_revenue'] as double) * 1.2
                    : 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${top5[groupIndex]['name']}\n${CurrencyHelper.format(rod.toY)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < top5.length) {
                          final name = top5[index]['name'] as String;
                          final maxLen = isSmall ? 6 : 10;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              name.length > maxLen ? '${name.substring(0, maxLen)}...' : name,
                              style: TextStyle(fontSize: isSmall ? 8 : 10, color: Colors.grey[600]),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: !isSmall,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          CurrencyHelper.format(value),
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  // Ensure horizontalInterval is never 0 to avoid assertion error
                  horizontalInterval: top5.isNotEmpty && (top5.first['total_revenue'] as double) > 0
                      ? (top5.first['total_revenue'] as double) / 4
                      : 1,  // Default to 1 when no revenue data
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(top5.length, (index) {
                  final revenue = top5[index]['total_revenue'] as double;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: revenue,
                        color: const Color(0xFF0D9759),
                        width: isSmall ? 24 : 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(bool isSmall) {
    if (_filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    if (_isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isSmall ? 2 : 3,
          childAspectRatio: isSmall ? 0.75 : 0.8,
          crossAxisSpacing: isSmall ? 12 : 16,
          mainAxisSpacing: isSmall ? 12 : 16,
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) => _buildProductGridCard(_filteredProducts[index], isSmall),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Products',
          style: TextStyle(fontSize: isSmall ? 14 : 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index], isSmall),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isSmall) {
    final transactions = product['transactions'] as int;
    final unitsSold = product['total_units_sold'] as int;
    final revenue = product['total_revenue'] as double;
    final profit = product['total_profit'] as double;
    final margin = product['profit_margin'] as double;
    final cancelled = product['cancelled_count'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetail(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isSmall ? 12 : 16),
          child: isSmall
              // Mobile: Stack vertically
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: product['image_url'] != null
                              ? Image.network(
                                  product['image_url'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildPlaceholder(60),
                                )
                              : _buildPlaceholder(60),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SKU: ${product['sku']}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Financial row - using Wrap to prevent overflow on very small screens
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CurrencyHelper.format(revenue),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Profit: ${CurrencyHelper.format(profit)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: profit >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMetricBadge('$transactions', 'Txns', Icons.receipt, Colors.blue),
                            const SizedBox(width: 8),
                            _buildMetricBadge('$unitsSold', 'Units', Icons.inventory_2, Colors.purple),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              // Desktop: Original horizontal layout
              : Row(
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: product['image_url'] != null
                          ? Image.network(
                              product['image_url'],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(80),
                            )
                          : _buildPlaceholder(80),
                    ),
                    const SizedBox(width: 16),
                    
                    // Product Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${product['sku']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 12),
                          
                          // Metrics
                          Row(
                            children: [
                              _buildMetricBadge(
                                '$transactions',
                                'Transactions',
                                Icons.receipt,
                                Colors.blue,
                              ),
                              const SizedBox(width: 12),
                              _buildMetricBadge(
                                '$unitsSold',
                                'Units',
                                Icons.inventory_2,
                                Colors.purple,
                              ),
                              if (cancelled > 0) ...[
                                const SizedBox(width: 12),
                                _buildMetricBadge(
                                  '$cancelled',
                                  'Cancelled',
                                  Icons.cancel,
                                  Colors.red,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Financial Info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyHelper.format(revenue),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Profit: ${CurrencyHelper.format(profit)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: profit >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getMarginColor(margin).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${margin.toStringAsFixed(1)}% margin',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getMarginColor(margin),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildProductGridCard(Map<String, dynamic> product, bool isSmall) {
    final revenue = product['total_revenue'] as double;
    final profit = product['total_profit'] as double;
    final margin = product['profit_margin'] as double;
    final transactions = product['transactions'] as int;

    return Card(
      child: InkWell(
        onTap: () => _navigateToDetail(product),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: product['image_url'] != null
                    ? Image.network(
                        product['image_url'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(double.infinity),
                      )
                    : _buildPlaceholder(double.infinity),
              ),
            ),
            
            // Info
            Padding(
              padding: EdgeInsets.all(isSmall ? 8 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmall ? 11 : 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isSmall ? 4 : 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$transactions txns',
                        style: TextStyle(fontSize: isSmall ? 9 : 11, color: Colors.grey[600]),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getMarginColor(margin).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${margin.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: isSmall ? 8 : 10,
                            fontWeight: FontWeight.bold,
                            color: _getMarginColor(margin),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmall ? 2 : 4),
                  Text(
                    CurrencyHelper.format(revenue),
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Profit: ${CurrencyHelper.format(profit)}',
                    style: TextStyle(
                      fontSize: isSmall ? 9 : 11,
                      color: profit >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBadge(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 9, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size == double.infinity ? null : size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(size == double.infinity ? 0 : 8),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No products match your search'
                  : 'No transactions yet',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _applyFiltersAndSort();
                  });
                },
                child: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getMarginColor(double margin) {
    if (margin < 0) return Colors.red;
    if (margin < 10) return Colors.orange;
    if (margin < 20) return Colors.blue;
    return Colors.green;
  }

  void _navigateToDetail(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedProductTransactionDetailScreen(
          seller: widget.seller,
          productId: product['product_id'],
          productName: product['name'],
          productImage: product['image_url'],
        ),
      ),
    );
  }
}

/// Enhanced detailed transaction view for a single product
class EnhancedProductTransactionDetailScreen extends StatefulWidget {
  final SellerModel seller;
  final String productId;
  final String productName;
  final String? productImage;

  const EnhancedProductTransactionDetailScreen({
    super.key,
    required this.seller,
    required this.productId,
    required this.productName,
    this.productImage,
  });

  @override
  State<EnhancedProductTransactionDetailScreen> createState() => 
      _EnhancedProductTransactionDetailScreenState();
}

class _EnhancedProductTransactionDetailScreenState 
    extends State<EnhancedProductTransactionDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  String _filterStatus = 'All'; // All, Delivered, Pending, Cancelled

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('seller_ids', arrayContains: widget.seller.id)
          .orderBy('created_at', descending: true)
          .get();

      List<Map<String, dynamic>> transactions = [];

      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
        final status = orderData['status'] ?? 'Pending';
        final createdAt = (orderData['created_at'] as Timestamp?)?.toDate();
        
        // Extract fee snapshot
        final feeSnapshot = orderData['fees_snapshot'] as Map<String, dynamic>?;
        final platformFeePercent = feeSnapshot != null 
            ? (feeSnapshot['platform_fee_percentage'] as num?)?.toDouble() ?? 10.0
            : 10.0;

        for (var item in items) {
          String? itemProductId = item['product_id'] ?? item['id'];
          if (itemProductId == widget.productId && 
              item['seller_id'] == widget.seller.id) {
            final quantity = (item['quantity'] ?? 1) as int;
            final sellingPrice = ((item['seller_base_price'] ?? 
                item['selling_price'] ?? item['price'] ?? 0) as num).toDouble();
            final costPrice = ((item['cost_price'] ?? 0) as num).toDouble();

            final revenue = sellingPrice * quantity;
            final cost = costPrice * quantity;
            final platformFee = status == 'Delivered' 
                ? revenue * (platformFeePercent / 100) 
                : 0;
            final profit = status == 'Delivered' 
                ? revenue - cost - platformFee 
                : 0;

            transactions.add({
              'order_id': orderData['order_id'] ?? orderDoc.id,
              'created_at': createdAt,
              'status': status,
              'quantity': quantity,
              'selling_price': sellingPrice,
              'revenue': revenue,
              'cost': cost,
              'platform_fee': platformFee,
              'platform_fee_percent': platformFeePercent,
              'profit': profit,
              'profit_margin': revenue > 0 ? (profit / revenue * 100) : 0,
              'has_fee_snapshot': feeSnapshot != null,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_filterStatus == 'All') return _transactions;
    return _transactions.where((t) => t['status'] == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    
    // Calculate summary metrics
    final totalUnits = filtered.fold<int>(0, (sum, t) => sum + (t['quantity'] as int));
    final totalRevenue = filtered.where((t) => t['status'] == 'Delivered')
        .fold<double>(0, (sum, t) => sum + (t['revenue'] as double));
    final totalProfit = filtered.where((t) => t['status'] == 'Delivered')
        .fold<double>(0, (sum, t) => sum + (t['profit'] as double));
    final avgMargin = filtered.where((t) => t['status'] == 'Delivered').isNotEmpty
        ? filtered.where((t) => t['status'] == 'Delivered')
            .fold<double>(0, (sum, t) => sum + (t['profit_margin'] as double)) /
            filtered.where((t) => t['status'] == 'Delivered').length
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.productName),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Product Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                if (widget.productImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.productImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    ),
                  )
                else
                  _buildPlaceholder(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_transactions.length} total transactions',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Summary Metrics
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSummaryMetric(
                    'Units Sold',
                    totalUnits.toString(),
                    Icons.inventory_2,
                    Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryMetric(
                    'Revenue',
                    CurrencyHelper.format(totalRevenue),
                    Icons.currency_rupee,
                    Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryMetric(
                    'Profit',
                    CurrencyHelper.format(totalProfit),
                    Icons.trending_up,
                    totalProfit >= 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryMetric(
                    'Avg Margin',
                    '${avgMargin.toStringAsFixed(1)}%',
                    Icons.percent,
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Delivered'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cancelled'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          
          // Transaction List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _filterStatus == 'All'
                              ? 'No transactions found'
                              : 'No $_filterStatus transactions',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildTransactionCard(filtered[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterStatus == label;
    final count = label == 'All' 
        ? _transactions.length
        : _transactions.where((t) => t['status'] == label).length;
    
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9759) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final orderId = transaction['order_id'] as String;
    final createdAt = transaction['created_at'] as DateTime?;
    final status = transaction['status'] as String;
    final quantity = transaction['quantity'] as int;
    final sellingPrice = transaction['selling_price'] as double;
    final revenue = transaction['revenue'] as double;
    final profit = transaction['profit'] as double;
    final margin = transaction['profit_margin'] as double;
    final platformFeePercent = transaction['platform_fee_percent'] as double;
    final hasFeeSnapshot = transaction['has_fee_snapshot'] as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    orderId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const Divider(height: 20),
            
            // Transaction Details
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow('Quantity', '$quantity units'),
                ),
                Expanded(
                  child: _buildDetailRow(
                    'Unit Price',
                    CurrencyHelper.format(sellingPrice),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow('Revenue', CurrencyHelper.format(revenue)),
                ),
                Expanded(
                  child: _buildDetailRow(
                    'Platform Fee',
                    '$platformFeePercent%${!hasFeeSnapshot ? ' ⚠️' : ''}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(
                    'Profit',
                    CurrencyHelper.format(profit),
                    color: profit >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildDetailRow(
                    'Margin',
                    '${margin.toStringAsFixed(1)}%',
                    color: _getMarginColor(margin),
                  ),
                ),
              ],
            ),
            if (!hasFeeSnapshot) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using current fee rate (order placed before fee tracking)',
                        style: TextStyle(fontSize: 11, color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Delivered':
        color = Colors.green;
        break;
      case 'Pending':
        color = Colors.orange;
        break;
      case 'Cancelled':
      case 'Rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getMarginColor(double margin) {
    if (margin < 0) return Colors.red;
    if (margin < 10) return Colors.orange;
    if (margin < 20) return Colors.blue;
    return Colors.green;
  }
}