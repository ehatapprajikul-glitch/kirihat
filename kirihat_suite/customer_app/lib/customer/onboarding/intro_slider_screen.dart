import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'pincode_gate.dart';

class IntroSliderScreen extends StatefulWidget {
  static const String _introSeenKey = 'intro_slider_seen';
  
  const IntroSliderScreen({super.key});

  /// Check if user has seen the intro slider
  static Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introSeenKey) ?? false;
  }

  /// Mark intro as seen
  static Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introSeenKey, true);
    debugPrint('✅ Intro slider marked as seen');
  }

  /// Reset intro seen flag (for testing)
  static Future<void> resetIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_introSeenKey);
    debugPrint('🔄 Intro slider reset');
  }

  @override
  State<IntroSliderScreen> createState() => _IntroSliderScreenState();
}

class _IntroSliderScreenState extends State<IntroSliderScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<Map<String, dynamic>> _slides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSlides();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSlides() async {
    try {
      debugPrint('🔄 Fetching onboarding slides from Firestore...');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('onboarding_slides')
          .get();
      
      debugPrint('📥 Got ${snapshot.docs.length} total slides from Firestore');

      if (mounted) {
        List<Map<String, dynamic>> loadedSlides = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        
        // Client-side filter for active slides
        loadedSlides = loadedSlides.where((s) => s['is_active'] == true).toList();
        
        // Client-side sort by sort_order
        loadedSlides.sort((a, b) => 
          (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
        
        debugPrint('📊 ${loadedSlides.length} active slides after filtering');
        for (var slide in loadedSlides) {
          debugPrint('  📄 Title: ${slide['title']}, Image: ${slide['image_url']}');
        }
        
        // If no slides in Firestore, use default slides
        if (loadedSlides.isEmpty) {
          loadedSlides = _getDefaultSlides();
          debugPrint('📱 Using default onboarding slides');
        }
        
        setState(() {
          _slides = loadedSlides;
          _isLoading = false;
        });
      }
      
      // Only skip if we have no slides at all (including defaults)
      if (_slides.isEmpty && mounted) {
        _navigateToPincodeGate();
      }
    } catch (e, stack) {
      debugPrint('❌ Error loading intro slides: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        // Use default slides even on error
        setState(() {
          _slides = _getDefaultSlides();
          _isLoading = false;
        });
      }
    }
  }
  
  List<Map<String, dynamic>> _getDefaultSlides() {
    return [
      {
        'title': 'Welcome to Kirihat',
        'description': 'Shop fresh groceries, daily essentials, and more from local vendors near you.',
        'image_url': '',
      },
      {
        'title': 'Fast Delivery',
        'description': 'Get your orders delivered quickly to your doorstep. Track your delivery in real-time.',
        'image_url': '',
      },
      {
        'title': 'Support Local Vendors',
        'description': 'Discover and shop from trusted local shops and vendors in your neighborhood.',
        'image_url': '',
      },
      {
        'title': 'Easy Payments',
        'description': 'Pay securely with multiple payment options. Cash on delivery available.',
        'image_url': '',
      },
    ];
  }

  void _navigateToPincodeGate() {
    IntroSliderScreen.markIntroSeen();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PincodeGateScreen()),
    );
  }

  void _onNextPressed() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToPincodeGate();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF0D9759),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen PageView with enhanced images
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return _buildEnhancedSlide(slide);
            },
          ),

          // Gradient overlay at bottom for text readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),

          // Skip Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: TextButton(
              onPressed: _navigateToPincodeGate,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Bottom content: Title, Description, Indicators, Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      _slides[_currentPage]['title'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    Text(
                      _slides[_currentPage]['description'] ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? const Color(0xFF0D9759)
                                : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Next/Get Started Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _onNextPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9759),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Enhanced slide widget with better image handling
  Widget _buildEnhancedSlide(Map<String, dynamic> slide) {
    final imageUrl = slide['image_url'] ?? '';

    if (imageUrl.isEmpty) {
      return _buildPlaceholderImage();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 500),
      fadeOutDuration: const Duration(milliseconds: 200),
      
      // Shimmer loading placeholder
      placeholder: (context, url) => _buildShimmerPlaceholder(),
      
      // Enhanced error widget with retry
      errorWidget: (context, url, error) => _buildErrorWidget(url),
      
      // Memory cache configuration
      memCacheWidth: (MediaQuery.of(context).size.width * 
          MediaQuery.of(context).devicePixelRatio).round(),
      memCacheHeight: (MediaQuery.of(context).size.height * 
          MediaQuery.of(context).devicePixelRatio).round(),
    );
  }

  /// Placeholder for empty images
  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D9759).withOpacity(0.3),
            const Color(0xFF0D9759).withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 120,
              color: const Color(0xFF0D9759).withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Kirihat',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D9759).withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shimmer loading effect
  Widget _buildShimmerPlaceholder() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Animated shimmer effect
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[900]!,
                      Colors.grey[800]!,
                      Colors.grey[700]!,
                      Colors.grey[800]!,
                      Colors.grey[900]!,
                    ],
                    stops: [
                      0.0,
                      value * 0.3,
                      value * 0.5,
                      value * 0.7,
                      1.0,
                    ],
                  ).createShader(bounds);
                },
                child: Container(
                  color: Colors.white,
                ),
              );
            },
            onEnd: () {
              if (mounted) {
                setState(() {});
              }
            },
          ),
          
          // Loading indicator
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF0D9759),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading image...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Enhanced error widget with retry capability
  Widget _buildErrorWidget(String url) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[900]!,
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Image failed to load',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            
            // Retry button
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  // Force rebuild to retry loading
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tap to retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D9759),
                side: const BorderSide(color: Color(0xFF0D9759)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}