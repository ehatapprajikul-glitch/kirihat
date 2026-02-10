import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import '../cart_screen.dart';

// ─── Design Tokens (matches green CustomerHeader) ────────────────────────────
const _kGreenDeep    = Color(0xFF064E3B);
const _kGreenMid     = Color(0xFF065F46);
const _kGreenVibrant = Color(0xFF059669);
const _kGreenLight   = Color(0xFF34D399);
const _kGreenGlow    = Color(0xFF10B981);
// ─────────────────────────────────────────────────────────────────────────────

class DraggableCartWrapper extends StatefulWidget {
  final Widget child;
  const DraggableCartWrapper({super.key, required this.child});

  @override
  State<DraggableCartWrapper> createState() => _DraggableCartWrapperState();
}

class _DraggableCartWrapperState extends State<DraggableCartWrapper> {
  final ValueNotifier<int> _refreshTrigger = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    CartHelper.cartCountNotifier.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    CartHelper.cartCountNotifier.removeListener(_onCartChanged);
    _refreshTrigger.dispose();
    super.dispose();
  }

  void _onCartChanged() => _refreshTrigger.value++;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: user == null
              ? _buildGuestCartBar()
              : _buildUserCartBar(user.uid),
        ),
      ],
    );
  }

  Widget _buildGuestCartBar() {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, _, __) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _calculateGuestCartTotals(),
          builder: (context, snapshot) {
            final data = snapshot.data ?? {'count': 0, 'total': 0.0};
            return _AnimatedCartBar(
              itemCount: data['count'] as int,
              totalPrice: data['total'] as double,
            );
          },
        );
      },
    );
  }

  Widget _buildUserCartBar(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        double total = 0.0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final int qty = (data['quantity'] as int?) ?? 1;
            final double price = (data['price'] as num?)?.toDouble() ?? 0.0;
            count += qty;
            total += price * qty;
          }
        }

        return _AnimatedCartBar(itemCount: count, totalPrice: total);
      },
    );
  }

  Future<Map<String, dynamic>> _calculateGuestCartTotals() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('guest_cart');
    if (cartJson == null) return {'count': 0, 'total': 0.0};

    try {
      final List<dynamic> decoded = json.decode(cartJson);
      int count = 0;
      double total = 0.0;
      for (var item in decoded) {
        final qty = (item['quantity'] as int?) ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        count += qty;
        total += price * qty;
      }
      return {'count': count, 'total': total};
    } catch (_) {
      return {'count': 0, 'total': 0.0};
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AnimatedCartBar — Blinkit boldness × Zepto sleekness
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedCartBar extends StatefulWidget {
  final int itemCount;
  final double totalPrice;

  const _AnimatedCartBar({
    required this.itemCount,
    required this.totalPrice,
  });

  @override
  State<_AnimatedCartBar> createState() => _AnimatedCartBarState();
}

class _AnimatedCartBarState extends State<_AnimatedCartBar>
    with TickerProviderStateMixin {
  // ── Shimmer sweep ──────────────────────────────────────────────────────────
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  // ── Entry spring ──────────────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final Animation<Offset> _entrySlide;
  late final Animation<double> _entryFade;

  // ── Count bounce ──────────────────────────────────────────────────────────
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceScale;

  // ── Pulse ring on cart icon ────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseRadius;
  late final Animation<double> _pulseOpacity;

  int _prevCount = 0;

  @override
  void initState() {
    super.initState();

    // Shimmer — repeating sweep every 3 s
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _shimmerCtrl.repeat(period: const Duration(seconds: 4));
    });

    // Entry slide-up spring
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    // Count bounce
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));

    // Pulse ring
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseRadius = Tween<double>(begin: 0, end: 28).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    _prevCount = widget.itemCount;

    if (widget.itemCount > 0) {
      _entryCtrl.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedCartBar old) {
    super.didUpdateWidget(old);

    // Cart became visible
    if (old.itemCount == 0 && widget.itemCount > 0) {
      _entryCtrl.forward(from: 0);
    }

    // Item count changed
    if (widget.itemCount != _prevCount && widget.itemCount > 0) {
      _bounceCtrl.forward(from: 0);
      _pulseCtrl.forward(from: 0);
    }

    _prevCount = widget.itemCount;
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _entryCtrl.dispose();
    _bounceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = widget.itemCount > 0;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 1.6),
      duration: const Duration(milliseconds: 420),
      curve: isVisible ? Curves.elasticOut : Curves.easeIn,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 280),
        child: SlideTransition(
          position: _entrySlide,
          child: FadeTransition(
            opacity: _entryFade,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPad + 14),
              child: _buildBar(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        _cartRoute(),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_shimmerAnim, _bounceCtrl]),
        builder: (context, child) {
          return Container(
            height: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kGreenDeep, _kGreenMid, _kGreenVibrant],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.45, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _kGreenGlow.withOpacity(0.45),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: _kGreenDeep.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // ── Subtle dot-grid texture ──────────────────────────────
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MicroDotPainter(
                        color: Colors.white.withOpacity(0.035),
                        spacing: 14,
                      ),
                    ),
                  ),

                  // ── Shimmer sweep ────────────────────────────────────────
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ShimmerSweepPainter(
                        progress: _shimmerAnim.value,
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                  ),

                  // ── Content Row ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        // Left: badge + price
                        _buildLeftSection(),

                        const Spacer(),

                        // Right: View Cart + icon
                        _buildRightSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Left: item count badge + price ────────────────────────────────────────
  Widget _buildLeftSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Count badge with bounce
        ScaleTransition(
          scale: _bounceScale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.30),
                width: 0.8,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.8),
                  end: Offset.zero,
                ).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '${widget.itemCount}',
                key: ValueKey(widget.itemCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Item label + price column
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.itemCount} ITEM${widget.itemCount != 1 ? 'S' : ''}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            // Animated price roll
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.6),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '₹${widget.totalPrice.toStringAsFixed(0)}',
                key: ValueKey(widget.totalPrice.toStringAsFixed(0)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Right: "View Cart" + animated bag icon ────────────────────────────────
  Widget _buildRightSection() {
    return Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'VIEW CART',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 1),
            Row(
              children: [
                Text(
                  'Fast delivery',
                  style: TextStyle(
                    color: _kGreenLight.withOpacity(0.90),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.bolt_rounded,
                  color: _kGreenLight,
                  size: 11,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 10),

        // Cart icon with pulse ring
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Opacity(
                  opacity: _pulseOpacity.value,
                  child: Container(
                    width: _pulseRadius.value * 2,
                    height: _pulseRadius.value * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _kGreenLight,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Icon container
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.0,
                  ),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Route<void> _cartRoute() {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => const CartScreen(),
      transitionsBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 380),
    );
  }
}

// ─── Shimmer Sweep Painter ────────────────────────────────────────────────────
class _ShimmerSweepPainter extends CustomPainter {
  final double progress; // -1.5 to 2.0
  final Color color;

  const _ShimmerSweepPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width * ((progress + 1.5) / 3.5);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color,
          color,
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.55, 1.0],
      ).createShader(
        Rect.fromLTWH(center - 60, 0, 120, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(center - 60, 0, 120, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ShimmerSweepPainter old) => old.progress != progress;
}

// ─── Micro Dot Grid Painter ───────────────────────────────────────────────────
class _MicroDotPainter extends CustomPainter {
  final Color color;
  final double spacing;

  const _MicroDotPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MicroDotPainter old) =>
      old.color != color || old.spacing != spacing;
}