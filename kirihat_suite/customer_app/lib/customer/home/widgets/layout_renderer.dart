import 'package:flutter/material.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import '../../widgets/product_search_delegate.dart';
import 'product_row_widget.dart';
import 'hero_section_widget.dart';
import 'category_grid_widget.dart';
import 'banner_section_widget.dart';
import '../../widgets/global_search_bar.dart';

/// Widget factory that renders different layout types based on LayoutModel
class LayoutRenderer extends StatelessWidget {
  final LayoutModel layout;
  final String vendorId;

  const LayoutRenderer({
    super.key,
    required this.layout,
    required this.vendorId,
  });

  @override
  Widget build(BuildContext context) {
    // Return appropriate widget based on layout type
    switch (layout.type) {
      case LayoutType.banner:
        return const BannerSectionWidget();
      
      case LayoutType.productRow:
        return ProductRowWidget(
          layout: layout,
          vendorId: vendorId,
        );
      
      case LayoutType.categoryGrid:
        return CategoryGridWidget(
          layout: layout,
          vendorId: vendorId,
        );
      
      case LayoutType.heroSection:
        return HeroSectionWidget(layout: layout);
      
      case LayoutType.searchSection:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GlobalSearchBar(
             onTap: () {
               showSearch(
                 context: context, 
                 delegate: ProductSearchDelegate(),
               );
             },
             onMicTap: () {
               showSearch(
                 context: context,
                 delegate: ProductSearchDelegate(
                   autoStartListening: true,
                 ),
               );
             },
          ),
        );
      
      case LayoutType.custom:
      default:
        // Placeholder for custom/unknown layout types
        return Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Custom layout: ${layout.title}',
            style: const TextStyle(color: Colors.grey),
          ),
        );
    }
  }
}
