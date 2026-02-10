import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:kirihat_core/models/home_layout_model.dart';
import '../onboarding/change_location_screen.dart';
import '../cart_screen.dart';
import '../widgets/draggable_cart_wrapper.dart';
import '../widgets/customer_header.dart';
import 'widgets/layout_renderer.dart';
import 'widgets/enhanced_home_layout_service.dart';
// Import for search
import '../widgets/product_search_delegate.dart';
import '../widgets/voice_search_screen.dart';

/// Enhanced Customer Home Screen with better error handling, caching, and UX
class EnhancedCustomerHomeScreen extends StatefulWidget {
  const EnhancedCustomerHomeScreen({super.key});

  @override
  State<EnhancedCustomerHomeScreen> createState() => _EnhancedCustomerHomeScreenState();
}

class _EnhancedCustomerHomeScreenState extends State<EnhancedCustomerHomeScreen>
    with AutomaticKeepAliveClientMixin {
  final EnhancedHomeLayoutService _layoutService = EnhancedHomeLayoutService();
  
  String? _vendorId;
  String? _selectedArea;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  
  // Cache the layout list to prevent unnecessary rebuilds on return
  List<LayoutModel>? _cachedLayouts;

  // Scroll logic for sticky header
  late ScrollController _scrollController;
  bool _showStickyHeader = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _layoutService.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final offset = _scrollController.offset;
      // Header height is approx 200. Show sticky when collapsed significantly.
      final show = offset > 160; 
      if (show != _showStickyHeader) {
        setState(() {
          _showStickyHeader = show;
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? vendorId = prefs.getString('assigned_vendor_id');
      String? area = prefs.getString('current_area');

      // If no local session, try loading from Firestore
      if (vendorId == null) {
        debugPrint('📡 No local session, checking Firestore...');
        final user = FirebaseAuth.instance.currentUser;
        
        if (user != null) {
          final sessionService = SessionService();
          final restored = await sessionService.loadSessionFromFirestore(user.uid)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  debugPrint('⏰ Session restore timeout');
                  return false;
                },
              );
          
          if (restored) {
            vendorId = prefs.getString('assigned_vendor_id');
            area = prefs.getString('current_area');
            debugPrint('✅ Session restored from cloud!');
          }
        }
      }

      if (mounted) {
        setState(() {
          _vendorId = vendorId;
          _selectedArea = area ?? 'Your Area';
          _isLoading = false;
        });
      }

      if (vendorId != null) {
        debugPrint('✅ Vendor ID loaded: $vendorId');
      } else {
        debugPrint('❌ No vendor found - showing location prompt');
      }
    } catch (e) {
      debugPrint('❌ Error loading home data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load session data';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // For AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: Colors.white,
      body: DraggableCartWrapper(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF0D9759),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Collapsible AppBar
              SliverAppBar(
                expandedHeight: 230.0, // Adjust based on CustomerHeader height
                pinned: true,
                floating: false,
                backgroundColor: const Color(0xFF064E3B), // Match deep green of header
                elevation: _showStickyHeader ? 2 : 0,
                // Sticky Header Title (Search Bar)
                titleSpacing: 0,
                centerTitle: true,
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showStickyHeader ? 1.0 : 0.0,
                  child: _showStickyHeader 
                      ? _buildStickySearchBar() 
                      : const SizedBox.shrink(),
                ),
                leading: AnimatedOpacity(
                   duration: const Duration(milliseconds: 200),
                   opacity: _showStickyHeader ? 1.0 : 0.0,
                   child: _showStickyHeader
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 18)
                        ),
                      )
                    : const SizedBox.shrink()
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: CustomerHeader(
                    selectedArea: _selectedArea ?? 'Select Location',
                    onLocationTap: _handleLocationTap,
                    onCartTap: _handleCartTap,
                  ),
                ),
              ),

              // Content
              _buildSliverContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickySearchBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: GestureDetector(
        onTap: () {
           showSearch(
             context: context, 
             delegate: ProductSearchDelegate(products: []) // Pass empty or cached
           );
        },
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search...',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ),
             GestureDetector(
               onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VoiceSearchScreen()),
                  );
                  if (result != null && result is String && mounted) {
                     showSearch(
                        context: context,
                        delegate: ProductSearchDelegate(initialQuery: result),
                     );
                  }
               },
               child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.mic, color: Color(0xFF059669), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverContent() {
    // Loading state
    if (_isLoading) {
      return const SliverFillRemaining(child: _LoadingWidget());
    }

    // Error state
    if (_hasError) {
      return SliverFillRemaining(
        child: _ErrorWidget(
          message: _errorMessage, 
          onRetry: _loadData
        )
      );
    }

    // No vendor selected
    if (_vendorId == null) {
      return SliverFillRemaining(
        child: _LocationPromptWidget(onTap: _handleLocationTap)
      );
    }

    // Main content with layouts
    return StreamBuilder<List<LayoutModel>>(
      stream: _layoutService.getMergedLayouts(_vendorId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedLayouts == null) {
           return const SliverFillRemaining(child: _LoadingWidget());
        }

        if (snapshot.hasError && _cachedLayouts == null) {
          debugPrint('❌ Error loading layouts: ${snapshot.error}');
          return SliverFillRemaining(
            child: _LayoutErrorWidget(
              error: snapshot.error.toString(), 
              onRetry: _loadData
            )
          );
        }

        // Use new data if available, otherwise use cached
        final layouts = snapshot.data ?? _cachedLayouts ?? [];
        
        // Cache for next rebuild
        if (snapshot.hasData) {
          _cachedLayouts = snapshot.data;
        }

        if (layouts.isEmpty) {
          return SliverFillRemaining(
            child: _EmptyLayoutWidget(onRefresh: _loadData)
          );
        }

        // Return SliverList
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return EnhancedLayoutRenderer(
                key: ValueKey(layouts[index].id),
                layout: layouts[index],
                vendorId: _vendorId!,
              );
            },
            childCount: layouts.length,
          ),
        );
      },
    );
  }

  Future<void> _handleLocationTap() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChangeLocationScreen()),
      );
      
      if (result == true || result == null) {
        // Location was changed or screen was dismissed
        await _loadData();
      }
    } catch (e) {
      debugPrint('❌ Location selection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to change location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleCartTap() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } catch (e) {
      debugPrint('❌ Cart navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to open cart'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRefresh() async {
    // Clear cache before refresh
    _layoutService.clearVendorCache(_vendorId!);
    await _loadData();
  }
}

// ─── Helper Widgets extracted for Sliver compatibility ─────────────────────

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF0D9759),
          ),
          SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _LocationPromptWidget extends StatelessWidget {
  final VoidCallback onTap;
  const _LocationPromptWidget({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Select Your Location',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Choose your delivery area to see available products',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.location_on),
              label: const Text('Choose Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  const _ErrorWidget({this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
            const SizedBox(height: 16),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Failed to load',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _LayoutErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize_outlined, size: 60, color: Colors.orange[400]),
            const SizedBox(height: 16),
            const Text(
              'Content Unavailable',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load home screen content',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLayoutWidget extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyLayoutWidget({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Home Layout Not Configured',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The admin hasn\'t set up the home screen layout yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D9759),
                side: const BorderSide(color: Color(0xFF0D9759)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}