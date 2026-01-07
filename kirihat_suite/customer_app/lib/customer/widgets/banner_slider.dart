import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kirihat_core/models/banner_model.dart';

class BannerSlider extends StatelessWidget {
  final List<BannerModel> banners;
  final Function(BannerModel) onBannerTap;
  final double height;

  const BannerSlider({
    super.key,
    required this.banners,
    required this.onBannerTap,
    this.height = 400,
  });

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const BouncingScrollPhysics(), // Give it a bouncy scroll feel
        itemCount: banners.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final banner = banners[index];
          // Determine width based on aspect ratio or fixed width.
          // Since it's a "card view", let's give it a reasonable width relative to height
          // or a fixed width. Let's assume a portrait aspect ratio.
          return GestureDetector(
            onTap: () => onBannerTap(banner),
            child: AspectRatio(
              aspectRatio: 2/3, // Portrait aspect ratio (e.g. 266px width for 400px height)
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 1080,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    ),
                  ),
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
