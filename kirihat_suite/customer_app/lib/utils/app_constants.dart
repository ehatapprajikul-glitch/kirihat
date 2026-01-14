import 'package:flutter/material.dart';

/// Application-wide constants for colors, dimensions, and configuration values
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // ==================== COLORS ====================
  static const Color primaryGreen = Color(0xFF0D9759);
  static const Color errorRed = Colors.red;
  static const Color textGrey = Colors.grey;
  static const Color backgroundGrey = Color(0xFFF5F5F5);
  
  // ==================== DIMENSIONS ====================
  // Banner & Hero
  static const double bannerHeight = 180.0;
  static const double heroSectionHeight = 200.0;
  
  // Product Cards
  static const double productCardWidth = 160.0;
  static const double productCardHeight = 240.0;
  static const double productImageHeight = 160.0;
  
  // Border Radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  
  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  // Icon Sizes
  static const double iconSizeSmall = 20.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  
  // ==================== IMAGE CACHE ====================
  // Banner images
  static const int bannerCacheWidth = 1080;
  static const int bannerCacheHeight = 400;
  
  // Product images
  static const int productImageCacheWidth = 500;
  static const int productImageCacheHeight = 500;
  
  // Thumbnail images
  static const int thumbnailCacheWidth = 200;
  static const int thumbnailCacheHeight = 200;
  
  // ==================== SEARCH ====================
  static const int searchDebounceMs = 500;
  static const int minSearchLength = 2;
  static const int maxSearchResults = 20;
  static const String searchPlaceholder = 'Search for products, brands, categories...';
  
  // ==================== CART & WISHLIST ====================
  static const int maxRecentlyViewed = 20;
  static const Duration cacheDuration = Duration(minutes: 5);
  
  // ==================== DELIVERY ====================
  static const String deliveryTimeStandard = 'Delivery in 20 minutes';
  static const String deliveryTimeInstant = 'Instant Delivery';
  
  // ==================== ANIMATION ====================
  static const Duration animationDurationShort = Duration(milliseconds: 200);
  static const Duration animationDurationMedium = Duration(milliseconds: 350);
  static const Duration animationDurationLong = Duration(milliseconds: 500);
  
  // ==================== PAGINATION ====================
  static const int productsPerPage = 20;
  static const int categoriesPerPage = 10;
  
  // ==================== UI TEXT ====================
  static const String emptyCartTitle = 'Your cart is empty';
  static const String emptyCartSubtitle = 'Looks like you haven\'t added anything yet';
  static const String emptyCartButton = 'Start Shopping';
  
  static const String emptyWishlistTitle = 'Your wishlist is empty';
  static const String emptyWishlistSubtitle = 'Save items you love for later';
  
  static const String emptyOrdersTitle = 'No orders yet';
  static const String emptyOrdersSubtitle = 'Your order history will appear here';
  
  // ==================== ERROR MESSAGES ====================
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorLoadingProducts = 'Failed to load products';
  static const String errorAddToCart = 'Failed to add item to cart';
  static const String errorPlaceOrder = 'Failed to place order';
  
  // ==================== SUCCESS MESSAGES ====================
  static const String successAddToCart = 'Added to cart';
  static const String successAddToWishlist = '❤️ Added to wishlist';
  static const String successRemoveFromWishlist = 'Removed from wishlist';
  static const String successOrderPlaced = 'Order placed successfully!';
}
