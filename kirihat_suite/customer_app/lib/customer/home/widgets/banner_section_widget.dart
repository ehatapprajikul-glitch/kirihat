import 'package:flutter/material.dart';
import 'package:kirihat_core/models/banner_model.dart';
import 'package:kirihat_core/services/banner_service.dart';
import '../../widgets/banner_slider.dart';
import '../../widgets/shimmer_loading.dart';
import 'navigation_helper.dart';

/// Enhanced Banner Section Widget with improved error handling and navigation
class EnhancedBannerSectionWidget extends StatefulWidget {
  final String? vendorId;
  
  const EnhancedBannerSectionWidget({
    super.key,
    this.vendorId,
  });

  @override
  State<EnhancedBannerSectionWidget> createState() => _EnhancedBannerSectionWidgetState();
}

class _EnhancedBannerSectionWidgetState extends State<EnhancedBannerSectionWidget>
    with AutomaticKeepAliveClientMixin {
  final BannerService _bannerService = BannerService();
  List<BannerModel>? _cachedBanners;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  @override
  bool get wantKeepAlive => true;

  bool get _isCacheValid {
    if (_cachedBanners == null || _cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // For AutomaticKeepAliveClientMixin

    // Return cached data if valid
    if (_isCacheValid) {
      return _buildBannerSlider(_cachedBanners!);
    }

    return StreamBuilder<List<BannerModel>>(
      stream: _bannerService.getActiveBanners(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting && _cachedBanners == null) {
          return const BannerShimmer();
        }

        // Error state - show cached data if available
        if (snapshot.hasError) {
          debugPrint('❌ Error loading banners: ${snapshot.error}');
          
          if (_cachedBanners != null) {
            return _buildBannerSlider(_cachedBanners!);
          }
          
          return const SizedBox.shrink();
        }

        // Empty state
        final banners = snapshot.data ?? [];
        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        // Update cache
        _cachedBanners = banners;
        _cacheTimestamp = DateTime.now();

        return _buildBannerSlider(banners);
      },
    );
  }

  Widget _buildBannerSlider(List<BannerModel> banners) {
    return BannerSlider(
      banners: banners,
      onBannerTap: (banner) => _handleBannerTap(banner),
    );
  }

  void _handleBannerTap(BannerModel banner) {
    try {
      NavigationHelper.handleBannerNavigation(
        context,
        hyperlinkType: banner.hyperlinkType ?? 'none',
        hyperlinkValue: banner.hyperlinkValue,
      );
      
      // Log banner tap analytics
      _logBannerTap(banner);
    } catch (e) {
      debugPrint('❌ Error handling banner tap: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process banner action'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _logBannerTap(BannerModel banner) {
    // TODO: Implement analytics logging
    debugPrint('📊 Banner tapped: ${banner.id} - ${banner.hyperlinkType}');
  }

  @override
  void dispose() {
    _cachedBanners = null;
    _cacheTimestamp = null;
    super.dispose();
  }
}