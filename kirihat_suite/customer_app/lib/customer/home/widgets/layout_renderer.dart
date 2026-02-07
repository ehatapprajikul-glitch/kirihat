import 'package:flutter/material.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import 'navigation_helper.dart';
import 'product_row_widget.dart';
import 'hero_section_widget.dart';
import 'category_grid_widget.dart';
import 'banner_section_widget.dart';

/// Enhanced Layout Renderer with error boundaries and better handling
class EnhancedLayoutRenderer extends StatelessWidget {
  final LayoutModel layout;
  final String vendorId;

  const EnhancedLayoutRenderer({
    super.key,
    required this.layout,
    required this.vendorId,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap in error boundary
    return _ErrorBoundary(
      child: _renderLayout(context),
    );
  }

  Widget _renderLayout(BuildContext context) {
    try {
      switch (layout.type) {
        case LayoutType.banner:
          return EnhancedBannerSectionWidget(vendorId: vendorId);
        
        case LayoutType.productRow:
          return EnhancedProductRowWidget(
            layout: layout,
            vendorId: vendorId,
          );
        
        case LayoutType.categoryGrid:
          return EnhancedCategoryGridWidget(
            layout: layout,
            vendorId: vendorId,
          );
        
        case LayoutType.heroSection:
          return EnhancedHeroSectionWidget(layout: layout);
        
        case LayoutType.searchSection:
          // Search is now integrated in CustomerHeader
          return const SizedBox.shrink();
        
        case LayoutType.custom:
          return _buildCustomLayout();
        
        default:
          return _buildUnknownLayout();
      }
    } catch (e) {
      debugPrint('❌ Error rendering layout ${layout.type}: $e');
      return _buildErrorLayout();
    }
  }

  Widget _buildCustomLayout() {
    // Handle custom layout types
    final customType = layout.data['custom_type'] as String?;
    
    if (customType == null) {
      return const SizedBox.shrink();
    }

    // Placeholder for custom layouts
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.extension, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  layout.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Custom: $customType',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownLayout() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unknown layout type: ${layout.type}',
              style: TextStyle(color: Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorLayout() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to render layout: ${layout.title}',
              style: TextStyle(color: Colors.red[900]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error boundary widget to catch and display rendering errors
class _ErrorBoundary extends StatefulWidget {
  final Widget child;

  const _ErrorBoundary({required this.child});

  @override
  State<_ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<_ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 32),
            const SizedBox(height: 8),
            Text(
              'Widget Error',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red[900],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _error.toString(),
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return widget.child;
  }

  @override
  void didUpdateWidget(_ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _error = null;
    }
  }
}