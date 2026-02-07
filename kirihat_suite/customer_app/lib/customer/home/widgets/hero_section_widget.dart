import 'package:flutter/material.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'navigation_helper.dart';

/// Enhanced Hero Section Widget with complete navigation and better UX
class EnhancedHeroSectionWidget extends StatelessWidget {
  final LayoutModel layout;

  const EnhancedHeroSectionWidget({
    super.key,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = layout.data['image_url'] as String?;
    final ctaText = layout.data['cta_text'] as String? ?? 'Shop Now';
    final targetType = layout.data['target_type'] as String?;
    final targetId = layout.data['target_id'] as String?;
    final overlayText = layout.data['overlay_text'] as String?;
    final height = (layout.data['height'] as num?)?.toDouble() ?? 200.0;

    final hasValidNavigation = targetType != null && 
                               targetId != null && 
                               targetId.isNotEmpty;

    return GestureDetector(
      onTap: hasValidNavigation 
          ? () => _handleTap(context, targetType, targetId)
          : null,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              _buildBackgroundImage(imageUrl),
              
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overlay Text
                    if (overlayText != null && overlayText.isNotEmpty)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            overlayText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    
                    // CTA Button
                    if (hasValidNavigation)
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => _handleTap(context, targetType, targetId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9759),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ctaText,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 64,
            color: Colors.grey[500],
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF0D9759),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('❌ Hero section image error: $error');
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: Colors.grey[500],
                ),
                const SizedBox(height: 8),
                Text(
                  'Image unavailable',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context, String? type, String? id) {
    if (type == null || id == null) return;

    try {
      NavigationHelper.handleTargetNavigation(
        context,
        targetType: type,
        targetId: id,
      );
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to navigate'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}