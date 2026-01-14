import 'package:flutter/material.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import '../../category/category_products_screen.dart';
import '../../product/enhanced_product_detail.dart';

/// Large promotional hero section with image + CTA
class HeroSectionWidget extends StatelessWidget {
  final LayoutModel layout;

  const HeroSectionWidget({
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

    return GestureDetector(
      onTap: () => _handleTap(context, targetType, targetId),
      child: Container(
        height: (layout.data['height'] as num?)?.toDouble() ?? 200.0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: imageUrl != null && imageUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                )
              : null,
          color: imageUrl == null ? Colors.grey[200] : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Overlay text (optional)
              if (overlayText != null && overlayText.isNotEmpty)
                Positioned(
                  left: 16,
                  top: 16,
                  child: Text(
                    overlayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              
              // CTA Button
              Positioned(
                right: 16,
                bottom: 16,
                child: ElevatedButton(
                  onPressed: () => _handleTap(context, targetType, targetId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9759),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(ctaText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, String? type, String? id) {
    if (type == null || id == null) return;

    // TODO: Handle navigation based on target type
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to $type: $id')),
    );
  }
}
