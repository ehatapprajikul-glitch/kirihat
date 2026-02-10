import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/phone_auth_screen.dart';
import '../wishlist_screen.dart';
import 'cart_badge.dart';
import 'global_search_bar.dart';
import 'product_search_delegate.dart';
import 'voice_search_screen.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
// Deep forest → vibrant emerald gradient palette
const _kGreenDeep    = Color(0xFF064E3B); // emerald-900
const _kGreenMid     = Color(0xFF065F46); // emerald-800
const _kGreenVibrant = Color(0xFF059669); // emerald-600
const _kGreenLight   = Color(0xFF34D399); // emerald-400
const _kMintAccent   = Color(0xFFA7F3D0); // emerald-200 (for subtle tints)
// ──────────────────────────────────────────────────────────────────────────────

class CustomerHeader extends StatelessWidget {
  final String selectedArea;
  final VoidCallback onLocationTap;
  final VoidCallback onCartTap;
  final List<Map<String, dynamic>> products;
  final String? categoryName;

  const CustomerHeader({
    super.key,
    required this.selectedArea,
    required this.onLocationTap,
    required this.onCartTap,
    this.products = const [],
    this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── 1. Multi-stop Emerald Gradient Background ─────────────────────────
        Container(
          height: 200,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _kGreenDeep,
                _kGreenMid,
                _kGreenVibrant,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),

        // ── 2. Leaf / Arc Decorative Overlay ──────────────────────────────────
        Positioned(
          top: -20,
          right: -30,
          child: _GreenLeafDecoration(),
        ),

        // ── 3. Subtle dot-grid texture overlay ────────────────────────────────
        Positioned.fill(
          child: CustomPaint(
            painter: _DotGridPainter(
              color: Colors.white.withOpacity(0.04),
              spacing: 18,
            ),
          ),
        ),

        // ── 4. Bottom highlight shimmer line ──────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _kGreenLight.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── 5. Main Content ───────────────────────────────────────────────────
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Location & ETA ──────────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: onLocationTap,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Brand name with mint accent dot
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 5, top: 1),
                                  decoration: const BoxDecoration(
                                    color: _kGreenLight,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Text(
                                  'Kirihat.com',
                                  style: TextStyle(
                                    color: _kMintAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),

                            // ETA — large bold number
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  '20',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'mins',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // "Live" delivery badge
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: _LiveBadge(),
                                ),
                              ],
                            ),

                            const SizedBox(height: 5),

                            // Location row with chevron
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: _kGreenLight,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 140),
                                    child: Text(
                                      selectedArea,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ── Right-side Actions ──────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            // Wishlist button
                            _GreenIconButton(
                              icon: Icons.favorite_border_rounded,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WishlistScreen(),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Cart
                            CartBadge(
                              onTap: onCartTap,
                              iconColor: Colors.white,
                            ),

                            const SizedBox(width: 8),

                            // Profile
                            _buildProfileButton(context),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Frosted Glass Search Bar ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _FrostedSearchBar(
                  onTap: () {
                    showSearch(
                      context: context,
                      delegate: ProductSearchDelegate(
                        products: products,
                        categoryName: categoryName,
                      ),
                    );
                  },
                  onMicTap: () async {
                    final result = await Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const VoiceSearchScreen(),
                        transitionsBuilder: (_, a, __, c) =>
                            FadeTransition(opacity: a, child: c),
                      ),
                    );
                    if (result != null &&
                        result is String &&
                        result.isNotEmpty &&
                        context.mounted) {
                      showSearch(
                        context: context,
                        delegate: ProductSearchDelegate(
                          products: products,
                          categoryName: categoryName,
                          initialQuery: result,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return GestureDetector(
      onTap: () {
        if (user == null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PhoneAuthScreen(
                onLoginSuccess: () {
                  Navigator.pop(context);
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile tapped')),
          );
        }
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.10),
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          user == null ? Icons.person_outline_rounded : Icons.person_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ─── Reusable Green Icon Button ───────────────────────────────────────────────
class _GreenIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GreenIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.22),
              Colors.white.withOpacity(0.08),
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.30),
            width: 1.0,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── Live Delivery Badge ──────────────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kGreenLight.withOpacity(0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGreenLight.withOpacity(0.50), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _kGreenLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: _kGreenLight,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Frosted Glass Search Bar ─────────────────────────────────────────────────
class _FrostedSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onMicTap;

  const _FrostedSearchBar({required this.onTap, required this.onMicTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kGreenDeep.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: _kGreenVibrant, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search groceries, essentials…',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            // Divider
            Container(
              width: 1,
              height: 22,
              color: Colors.grey.shade200,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            GestureDetector(
              onTap: onMicTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.mic_rounded,
                  color: _kGreenVibrant,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SVG-free Leaf Decoration ─────────────────────────────────────────────────
class _GreenLeafDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(220, 200),
      painter: _LeafArcPainter(),
    );
  }
}

class _LeafArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Large outer arc — very subtle
    paint.color = Colors.white.withOpacity(0.05);
    final outerPath = Path()
      ..moveTo(size.width, 0)
      ..cubicTo(
        size.width * 0.2, size.height * 0.0,
        size.width * 0.0, size.height * 0.5,
        size.width * 0.4, size.height,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(outerPath, paint);

    // Medium arc — slightly more visible
    paint.color = Colors.white.withOpacity(0.07);
    final midPath = Path()
      ..moveTo(size.width, 0)
      ..cubicTo(
        size.width * 0.5, size.height * 0.1,
        size.width * 0.3, size.height * 0.6,
        size.width * 0.7, size.height,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(midPath, paint);

    // Small leaf circle top-right
    paint.color = Colors.white.withOpacity(0.08);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 45, paint);

    // Tiny bright accent circle
    paint.color = const Color(0xFF34D399).withOpacity(0.15);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.08), 22, paint);
  }

  @override
  bool shouldRepaint(_LeafArcPainter oldDelegate) => false;
}

// ─── Dot Grid Texture Painter ─────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  final Color color;
  final double spacing;

  const _DotGridPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) =>
      old.color != color || old.spacing != spacing;
}