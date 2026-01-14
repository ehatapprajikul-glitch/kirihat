import 'package:flutter/material.dart';
import 'package:kirihat_core/models/banner_model.dart';
import 'package:kirihat_core/services/banner_service.dart';
import '../../widgets/banner_slider.dart';
import '../../widgets/shimmer_loading.dart';

class BannerSectionWidget extends StatelessWidget {
  const BannerSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // BannerService is in the core package and handles fetching from 'hero_banners' collection
    final bannerService = BannerService();

    return StreamBuilder<List<BannerModel>>(
      stream: bannerService.getActiveBanners(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BannerShimmer();
        }

        if (snapshot.hasError) {
          print('Error loading banners: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        final banners = snapshot.data ?? [];

        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return BannerSlider(
          banners: banners,
          onBannerTap: (banner) {
            // Handle banner tap based on type
            _handleBannerTap(context, banner);
          },
        );
      },
    );
  }

  void _handleBannerTap(BuildContext context, BannerModel banner) {
    // TODO: Implement navigation based on banner type
    // This logic was previously in the home screen but not fully implemented in the new architecture
    // Ideally this should use a central navigation helper
    print('Tapped banner: ${banner.id} - ${banner.hyperlinkType}');
  }
}
