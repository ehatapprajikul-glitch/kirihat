/// Comprehensive calculation utilities for seller financials
/// Handles profit, loss, discount, and inventory calculations
class SellerCalculations {
  /// Calculate profit for a single order item
  /// Profit = Selling Price - Cost Price - Platform Fee
  static double calculateItemProfit({
    required double sellingPrice,
    required double costPrice,
    required int quantity,
    double platformFeePercentage = 0.10, // 10% default
  }) {
    final revenue = sellingPrice * quantity;
    final cost = costPrice * quantity;
    final platformFee = revenue * platformFeePercentage;
    return revenue - cost - platformFee;
  }

  /// Calculate discount given on a product
  /// Discount = MRP - Selling Price
  static double calculateDiscount({
    required double mrp,
    required double sellingPrice,
    required int quantity,
  }) {
    return (mrp - sellingPrice) * quantity;
  }

  /// Calculate discount percentage
  static double calculateDiscountPercentage({
    required double mrp,
    required double sellingPrice,
  }) {
    if (mrp <= 0) return 0.0;
    return ((mrp - sellingPrice) / mrp) * 100;
  }

  /// Calculate profit margin percentage
  /// Profit Margin = (Selling Price - Cost Price) / Selling Price * 100
  static double calculateProfitMargin({
    required double sellingPrice,
    required double costPrice,
  }) {
    if (sellingPrice <= 0) return 0.0;
    return ((sellingPrice - costPrice) / sellingPrice) * 100;
  }

  /// Calculate inventory value for a product
  /// Inventory Value = Cost Price × Stock Quantity
  static double calculateInventoryValue({
    required double costPrice,
    required double stockQuantity,
  }) {
    return costPrice * stockQuantity;
  }

  /// Calculate platform fee for a transaction
  static double calculatePlatformFee({
    required double revenue,
    double feePercentage = 0.10, // 10% default
  }) {
    return revenue * feePercentage;
  }

  /// Calculate net earnings after fees
  /// Net = Gross Revenue - Platform Fee
  static double calculateNetEarnings({
    required double grossRevenue,
    double platformFeePercentage = 0.10,
  }) {
    final fee = calculatePlatformFee(
      revenue: grossRevenue,
      feePercentage: platformFeePercentage,
    );
    return grossRevenue - fee;
  }

  /// Calculate comprehensive order financials
  static OrderFinancials calculateOrderFinancials({
    required double sellingPrice,
    required double costPrice,
    required double mrp,
    required int quantity,
    double platformFeePercentage = 0.10,
  }) {
    final revenue = sellingPrice * quantity;
    final cost = costPrice * quantity;
    final platformFee = revenue * platformFeePercentage;
    final profit = revenue - cost - platformFee;
    final discount = (mrp - sellingPrice) * quantity;
    final profitMargin = sellingPrice > 0
        ? ((sellingPrice - costPrice) / sellingPrice) * 100
        : 0.0;

    return OrderFinancials(
      revenue: revenue,
      cost: cost,
      platformFee: platformFee,
      profit: profit,
      discount: discount,
      profitMargin: profitMargin,
    );
  }

  /// Calculate average order value
  static double calculateAverageOrderValue({
    required double totalRevenue,
    required int orderCount,
  }) {
    if (orderCount == 0) return 0.0;
    return totalRevenue / orderCount;
  }

  /// Calculate return on investment (ROI)
  /// ROI = (Net Profit / Cost) * 100
  static double calculateROI({
    required double netProfit,
    required double totalCost,
  }) {
    if (totalCost == 0) return 0.0;
    return (netProfit / totalCost) * 100;
  }

  /// Get safe values with fallback for null/missing cost price
  /// Returns selling price if cost price is missing (conservative estimate)
  static double getSafeCostPrice({
    required double? costPrice,
    required double sellingPrice,
  }) {
    // If cost price not available, assume cost = selling price (0% profit)
    // This is conservative and prevents showing inflated profits
    return costPrice ?? sellingPrice;
  }

  /// Get safe selling price with fallback
  static double getSafeSellingPrice({
    required double? sellingPrice,
    required double? mrp,
    double defaultPrice = 0.0,
  }) {
    return sellingPrice ?? mrp ?? defaultPrice;
  }
}

/// Data class for comprehensive order financial breakdown
class OrderFinancials {
  final double revenue;
  final double cost;
  final double platformFee;
  final double profit;
  final double discount;
  final double profitMargin;

  OrderFinancials({
    required this.revenue,
    required this.cost,
    required this.platformFee,
    required this.profit,
    required this.discount,
    required this.profitMargin,
  });

  /// Calculate net profit (profit after all deductions)
  double get netProfit => profit;

  /// Check if this is profitable
  bool get isProfitable => profit > 0;

  /// Generate a map representation
  Map<String, dynamic> toMap() {
    return {
      'revenue': revenue,
      'cost': cost,
      'platformFee': platformFee,
      'profit': profit,
      'discount': discount,
      'profitMargin': profitMargin,
    };
  }
}

/// Comprehensive seller dashboard analytics
class SellerDashboardMetrics {
  // Revenue Metrics
  final double totalRevenue;
  final double averageOrderValue;
  final int totalOrders;

  // Profit Metrics
  final double totalProfit;
  final double totalCost;
  final double averageProfitMarginPercentage;
  final double roi;

  // Discount Metrics
  final double totalDiscountsGiven;
  final double averageDiscountPercentage;

  // Loss Tracking
  final double cancelledOrdersValue;
  final double platformFeesTotal;
  final int cancelledOrdersCount;

  // Inventory Metrics
  final double totalInventoryValue;
  final int totalProductsCount;
  final int lowStockCount;
  final int outOfStockCount;

  SellerDashboardMetrics({
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.totalOrders,
    required this.totalProfit,
    required this.totalCost,
    required this.averageProfitMarginPercentage,
    required this.roi,
    required this.totalDiscountsGiven,
    required this.averageDiscountPercentage,
    required this.cancelledOrdersValue,
    required this.platformFeesTotal,
    required this.cancelledOrdersCount,
    required this.totalInventoryValue,
    required this.totalProductsCount,
    required this.lowStockCount,
    required this.outOfStockCount,
  });

  /// Net earnings after all fees
  double get netEarnings => totalRevenue - platformFeesTotal;

  /// Total loss (cancellations + fees)
  double get totalLoss => cancelledOrdersValue + platformFeesTotal;

  /// Gross profit before platform fees
  double get grossProfit => totalRevenue - totalCost;

  Map<String, dynamic> toMap() {
    return {
      'totalRevenue': totalRevenue,
      'averageOrderValue': averageOrderValue,
      'totalOrders': totalOrders,
      'totalProfit': totalProfit,
      'totalCost': totalCost,
      'averageProfitMarginPercentage': averageProfitMarginPercentage,
      'roi': roi,
      'totalDiscountsGiven': totalDiscountsGiven,
      'averageDiscountPercentage': averageDiscountPercentage,
      'cancelledOrdersValue': cancelledOrdersValue,
      'platformFeesTotal': platformFeesTotal,
      'cancelledOrdersCount': cancelledOrdersCount,
      'totalInventoryValue': totalInventoryValue,
      'totalProductsCount': totalProductsCount,
      'lowStockCount': lowStockCount,
      'outOfStockCount': outOfStockCount,
      'netEarnings': netEarnings,
      'totalLoss': totalLoss,
      'grossProfit': grossProfit,
    };
  }
}
