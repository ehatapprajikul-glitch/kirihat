import 'package:cloud_firestore/cloud_firestore.dart';

class CouponService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Validates a coupon code and returns the discount details if valid.
  /// Throws an exception string if invalid.
  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required String userId,
    required double cartTotal,
    required List<Map<String, dynamic>> cartItems,
  }) async {
    try {
      // 1. Fetch Coupon
      final querySnapshot = await _firestore
          .collection('coupons')
          .where('code', isEqualTo: code.trim().toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw "Invalid coupon code";
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      // 2. Check Active
      if (data['is_active'] != true) {
        throw "This coupon is inactive";
      }

      // 3. Check Expiry
      if (data['valid_until'] != null) {
        DateTime expiry = (data['valid_until'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiry)) {
          throw "This coupon has expired";
        }
      }
      
      if (data['valid_from'] != null) {
         DateTime start = (data['valid_from'] as Timestamp).toDate();
         if (DateTime.now().isBefore(start)) {
           throw "This coupon is not valid yet";
         }
      }

      // 4. Check Global Usage Limit
      int usedCount = data['used_count'] ?? 0;
      int? globalLimit = data['usage_limit'];
      if (globalLimit != null && usedCount >= globalLimit) {
        throw "This coupon has reached its usage limit";
      }

      // 5. Check Min Order Value
      num? minOrder = data['min_order_value'];
      if (minOrder != null && cartTotal < minOrder) {
        throw "Minimum order value of ₹$minOrder required";
      }

      // 6. Check Specific Rules (Category/Product)
      String type = data['type'] ?? 'general';
      List<dynamic>? applicableCategories = data['applicable_categories'];
      // List<dynamic>? applicableProducts = data['applicable_products'];

      if (type == 'new_user') {
         // Check if user has orders
         final orderCheck = await _firestore
             .collection('orders')
             .where('customer_id', isEqualTo: userId)
             .limit(1)
             .get();
         if (orderCheck.docs.isNotEmpty) {
           throw "This coupon is for new users only";
         }
      } else if (type == 'category' && applicableCategories != null) {
         // Check if cart has ANY item from allowed categories
         bool hasCategory = false;
         for (var item in cartItems) {
            String? cat = item['category']; // Need to ensure category is in cart items
            // If category is not directly in cart item, we might need to rely on product data if available
            // Assuming simplified check: cart items should have category or we trust 'general' type coupons mostly.
            // For now, let's assume if 'category' field exists in cart items.
            if (cat != null && applicableCategories.contains(cat)) {
              hasCategory = true;
              break;
            }
         }
         if (!hasCategory) {
           throw "This coupon is only valid for: ${applicableCategories.join(', ')}";
         }
      }

      // 7. Check Per User Limit
      int userLimit = data['per_user_limit'] ?? 1;
      
      // We check the specific counter for this user if we had a subcollection, 
      // or we query orders. Querying orders is safer but slightly slower/costlier.
      final userUsageQuery = await _firestore
          .collection('orders')
          .where('customer_id', isEqualTo: userId)
          .where('coupon_code', isEqualTo: code.trim().toUpperCase())
          .count()
          .get();
      
      int userUsage = userUsageQuery.count ?? 0;
      
      if (userUsage >= userLimit) {
        throw "You have already used this coupon";
      }

      // 8. Calculate Discount
      String discountType = data['discount_type'] ?? 'percentage';
      num discountValue = data['discount_value'] ?? 0;
      double calculatedDiscount = 0;

      if (discountType == 'percentage') {
        calculatedDiscount = (cartTotal * discountValue) / 100;
        // Apply Max Discount Cap
        num? maxDiscount = data['max_discount'];
        if (maxDiscount != null && calculatedDiscount > maxDiscount) {
          calculatedDiscount = maxDiscount.toDouble();
        }
      } else {
        calculatedDiscount = discountValue.toDouble();
      }
      
      // Ensure discount doesn't exceed total
      if (calculatedDiscount > cartTotal) {
        calculatedDiscount = cartTotal;
      }

      return {
        'code': data['code'],
        'coupon_id': doc.id,
        'discount_amount': calculatedDiscount,
        'description': discountType == 'percentage' 
            ? '${discountValue}% OFF' 
            : '₹$discountValue OFF',
      };

    } catch (e) {
      if (e is String) rethrow; // Pass simplified message
      throw "Error validating coupon";
    }
  }
}
