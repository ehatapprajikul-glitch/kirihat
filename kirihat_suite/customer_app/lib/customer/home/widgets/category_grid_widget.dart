import 'package:flutter/material.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import 'package:kirihat_core/services/hero_category_service.dart';
import '../../category/category_products_screen.dart';
import '../../../widgets/skeleton_loader.dart';

/// Category grid widget (refactored from existing code)
class CategoryGridWidget extends StatelessWidget {
  final LayoutModel layout;
  final String vendorId;

  const CategoryGridWidget({
    super.key,
    required this.layout,
    required this.vendorId,
  });

  @override
  Widget build(BuildContext context) {
    final heroCategoryId = layout.data['hero_category_id'] as String?;
    final columns = layout.data['columns'] as int? ?? 3;

    if (heroCategoryId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        if (layout.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              layout.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        
        // Category Grid
        FutureBuilder<Map<String, dynamic>>(
          future: _getHeroCategoryWithInventory(heroCategoryId, vendorId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingSkeleton(columns);
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final heroCategory = snapshot.data!;
            final categoryIds = (heroCategory['category_ids'] as List<dynamic>?)
                    ?.cast<String>() ??
                [];

            if (categoryIds.isEmpty) {
              return const SizedBox.shrink();
            }

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getCategoriesWithInventory(categoryIds, vendorId),
              builder: (context, categoriesSnapshot) {
                if (categoriesSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingSkeleton(columns);
                }

                final categories = categoriesSnapshot.data ?? [];

                if (categories.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      return _buildCategoryCard(context, categories[index]);
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> category) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewCategoryProductsScreen(
              categoryName: category['name'],
              vendorId: vendorId,
            ),
          ),
        );
      },
      child: Column(
        children: [
          // Category Image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                image: category['icon'] != null
                    ? DecorationImage(
                        image: NetworkImage(category['icon']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: category['icon'] == null
                  ? const Center(
                      child: Icon(Icons.category, size: 40, color: Colors.grey),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          // Category Name
          Text(
            category['name'],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(int columns) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const CategoryCardSkeleton(),
      ),
    );
  }

  Future<Map<String, dynamic>> _getHeroCategoryWithInventory(
    String heroCategoryId,
    String vendorId,
  ) async {
    final heroService = HeroCategoryService();
    final heroCategories = await heroService.getAdminHeroCategories();
    
    return heroCategories.firstWhere(
      (cat) => cat['id'] == heroCategoryId,
      orElse: () => {},
    );
  }

  Future<List<Map<String, dynamic>>> _getCategoriesWithInventory(
    List<String> categoryIds,
    String vendorId,
  ) async {
    final heroService = HeroCategoryService();
    return await heroService.getCategoriesWithInventory(
      vendorId: vendorId,
      categoryIds: categoryIds,
    );
  }
}
