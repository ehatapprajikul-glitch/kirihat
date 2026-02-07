import 'package:flutter/material.dart';
import '../../category/category_products_screen.dart';
import '../../product/enhanced_product_detail.dart';


/// Centralized navigation helper to avoid code duplication and ensure consistency
class NavigationHelper {
  /// Navigate based on banner hyperlink type
  static void handleBannerNavigation(
    BuildContext context, {
    required String hyperlinkType,
    required String? hyperlinkValue,
  }) {
    if (hyperlinkValue == null || hyperlinkValue.isEmpty) {
      _showError(context, 'No navigation target specified');
      return;
    }

    switch (hyperlinkType.toLowerCase()) {
      case 'product':
        _navigateToProduct(context, hyperlinkValue);
        break;
      
      case 'category':
        _navigateToCategory(context, hyperlinkValue);
        break;
      
      case 'collection':
        _navigateToCollection(context, hyperlinkValue);
        break;
      
      case 'url':
      case 'external':
        _openExternalUrl(context, hyperlinkValue);
        break;
      
      case 'search':
        _navigateToSearch(context, hyperlinkValue);
        break;
      
      case 'none':
      case '':
        // No action
        break;
      
      default:
        _showError(context, 'Unknown navigation type: $hyperlinkType');
    }
  }

  /// Navigate based on target type (for hero sections, etc.)
  static void handleTargetNavigation(
    BuildContext context, {
    required String? targetType,
    required String? targetId,
  }) {
    if (targetType == null || targetId == null) return;

    switch (targetType.toLowerCase()) {
      case 'product':
        _navigateToProduct(context, targetId);
        break;
      
      case 'category':
        _navigateToCategory(context, targetId);
        break;
      
      case 'collection':
        _navigateToCollection(context, targetId);
        break;
      
      case 'url':
        _openExternalUrl(context, targetId);
        break;
      
      default:
        _showError(context, 'Unknown target type: $targetType');
    }
  }

  // Private navigation methods

  static void _navigateToProduct(BuildContext context, String productId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedProductDetailScreen(
          productId: productId,
          productData: {'id': productId},
        ),
      ),
    );
  }

  static void _navigateToCategory(BuildContext context, String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewCategoryProductsScreen(
          categoryName: categoryName,
          vendorId: '', // Will be fetched from session
        ),
      ),
    );
  }

  static void _navigateToCollection(BuildContext context, String collectionId) {
    // TODO: Implement collection screen navigation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to collection: $collectionId'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  static void _navigateToSearch(BuildContext context, String? query) {
    // TODO: Implement search navigation
    showSearch(
      context: context,
      delegate: ProductSearchDelegate(
        initialQuery: query,
      ),
    );
  }

  static void _openExternalUrl(BuildContext context, String url) {
    // TODO: Implement external URL opening
    // For now, show message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open URL: $url'),
        action: SnackBarAction(
          label: 'OPEN',
          onPressed: () {
            // Use url_launcher package here
            // launchUrl(Uri.parse(url));
          },
        ),
      ),
    );
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Product search delegate with initial query support
class ProductSearchDelegate extends SearchDelegate<String> {
  final String? initialQuery;

  ProductSearchDelegate({this.initialQuery, bool autoStartListening = false});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // TODO: Implement search results
    return Center(
      child: Text('Search results for: $query'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // TODO: Implement search suggestions
    return Center(
      child: Text('Search suggestions for: $query'),
    );
  }
}