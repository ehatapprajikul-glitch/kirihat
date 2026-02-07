import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import 'package:kirihat_core/services/hero_category_service.dart';
import '../../category/category_products_screen.dart';
import '../../../widgets/skeleton_loader.dart';

/// Enhanced Category Grid Widget with caching and better error handling
class EnhancedCategoryGridWidget extends StatefulWidget {
  final LayoutModel layout;
  final String vendorId;

  const EnhancedCategoryGridWidget({
    super.key,
    required this.layout,
    required this.vendorId,
  });

  @override
  State<EnhancedCategoryGridWidget> createState() => _EnhancedCategoryGridWidgetState();
}

class _EnhancedCategoryGridWidgetState extends State<EnhancedCategoryGridWidget>
    with AutomaticKeepAliveClientMixin {
  final HeroCategoryService _heroService = HeroCategoryService();
  
  List<Map<String, dynamic>>? _cachedCategories;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 10);
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  bool get _isCacheValid {
    if (_cachedCategories == null || _cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }

  Future<void> _loadCategories() async {
    // Use cache if valid
    if (_isCacheValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final heroCategoryId = widget.layout.data['hero_category_id'] as String?;
      
      if (heroCategoryId == null || heroCategoryId.isEmpty) {
        setState(() {
          _isLoading = false;
          _cachedCategories = [];
        });
        return;
      }

      // Get hero category
      final heroCategories = await _heroService.getAdminHeroCategories()
          .timeout(const Duration(seconds: 10));
      
      final heroCategory = heroCategories.firstWhere(
        (cat) => cat['id'] == heroCategoryId,
        orElse: () => <String, dynamic>{},
      );

      if (heroCategory.isEmpty) {
        setState(() {
          _isLoading = false;
          _cachedCategories = [];
        });
        return;
      }

      // Get category IDs
      final categoryIds = (heroCategory['category_ids'] as List<dynamic>?)
              ?.cast<String>() ?? [];

      if (categoryIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _cachedCategories = [];
        });
        return;
      }

      // Get categories with inventory
      final categories = await _heroService.getCategoriesWithInventory(
        vendorId: widget.vendorId,
        categoryIds: categoryIds,
      ).timeout(const Duration(seconds: 15));

      setState(() {
        _cachedCategories = categories;
        _cacheTimestamp = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');
      setState(() {
        _errorMessage = 'Failed to load categories';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // For AutomaticKeepAliveClientMixin

    // Show cached data while loading fresh data
    if (_isLoading && _cachedCategories != null) {
      return _buildCategoryGrid(_cachedCategories!);
    }

    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    if (_errorMessage != null && _cachedCategories == null) {
      return _buildErrorState();
    }

    if (_cachedCategories == null || _cachedCategories!.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildCategoryGrid(_cachedCategories!);
  }

  Widget _buildCategoryGrid(List<Map<String, dynamic>> categories) {
    final columns = widget.layout.data['columns'] as int? ?? 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        if (widget.layout.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.layout.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      _cachedCategories = null;
                      _cacheTimestamp = null;
                      _loadCategories();
                    },
                    tooltip: 'Retry',
                  ),
              ],
            ),
          ),
        
        // Category Grid
        Padding(
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
              return _buildCategoryCard(categories[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final name = category['name'] as String? ?? 'Unknown';
    final icon = category['icon'] as String?;

    return GestureDetector(
      onTap: () => _navigateToCategory(name),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                // shape: BoxShape.rectangle, // Default
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04), // Very subtle shadow
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(12.0), // Padding inside the bubble
                  child: icon != null && icon.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: icon,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Center(child: Icon(Icons.category, color: Colors.grey[300])),
                          errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red[200]),
                        )
                      : Icon(
                          Icons.category_outlined,
                          size: 32,
                          color: Theme.of(context).primaryColor,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final columns = widget.layout.data['columns'] as int? ?? 3;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.layout.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        Padding(
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
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage ?? 'Failed to load categories',
                style: TextStyle(color: Colors.red[900]),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _cachedCategories = null;
                _cacheTimestamp = null;
                _loadCategories();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCategory(String categoryName) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewCategoryProductsScreen(
            categoryName: categoryName,
            vendorId: widget.vendorId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to open category'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cachedCategories = null;
    _cacheTimestamp = null;
    super.dispose();
  }
}