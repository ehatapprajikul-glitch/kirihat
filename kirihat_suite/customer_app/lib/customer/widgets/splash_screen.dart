import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart'; // Import main.dart for AuthWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // --- Logo entrance ---
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // --- Pulse rings (repeat) ---
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  // --- Text slide-up reveal ---
  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  // --- Progress bar ---
  late AnimationController _progressController;

  // --- Floating particles ---
  late AnimationController _particleController;
  final List<_Particle> _particles = [];

  static const _accentColor = Color(0xFF4D9EFF);
  static const _bgDark = Color(0xFF080C18);
  static const _bgMid = Color(0xFF121C33);

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));

    _generateParticles();
    _setupAnimations();
    _startSequence();
  }

  void _generateParticles() {
    final rng = Random();
    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: rng.nextDouble() * 2.5 + 0.5,
        driftSpeed: rng.nextDouble() * 0.25 + 0.05,
        baseOpacity: rng.nextDouble() * 0.45 + 0.1,
        twinklePhase: rng.nextDouble(),
      ));
    }
  }

  void _setupAnimations() {
    // Logo: elastic pop-in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    // Pulse rings: repeating expand + fade
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 2.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Text: slide up + fade in
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Progress bar: fills over total splash duration
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    // Particles: slow drift loop
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  void _startSequence() {
    // 1. Logo pops in
    _logoController.forward();

    // 2. After logo peaks, start text + rings + progress
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      _textController.forward();
      _pulseController.repeat();
      _progressController.forward();
    });

    // 3. Navigate when progress bar completes
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) _navigateToNext();
    });
  }

  void _navigateToNext() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const AuthWrapper(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.06, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _progressController.dispose();
    _particleController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          _buildBackground(),
          _buildParticles(size),
          _buildCenterContent(),
          _buildProgressBar(),
        ],
      ),
    );
  }

  // Radial gradient background
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.15),
          radius: 1.3,
          colors: [_bgMid, _bgDark],
          stops: [0.0, 1.0],
        ),
      ),
    );
  }

  // Drifting star-like particles
  Widget _buildParticles(Size size) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (_, __) => CustomPaint(
        size: size,
        painter: _ParticlePainter(
          particles: _particles,
          progress: _particleController.value,
          accentColor: _accentColor,
        ),
      ),
    );
  }

  // Logo + rings + text stacked in center
  Widget _buildCenterContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogoStack(),
          const SizedBox(height: 36),
          _buildTextReveal(),
        ],
      ),
    );
  }

  // Logo surrounded by glow + two offset pulse rings
  Widget _buildLogoStack() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildGlow(),
          _buildRing(phaseOffset: 0.0, color: _accentColor, strokeWidth: 2.0),
          _buildRing(phaseOffset: 0.5, color: const Color(0xFF80C0FF), strokeWidth: 1.2),
          _buildLogo(),
        ],
      ),
    );
  }

  // Soft ambient glow behind the logo
  Widget _buildGlow() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (_, __) => Opacity(
        opacity: _logoOpacity.value,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _accentColor.withOpacity(0.28),
                blurRadius: 80,
                spreadRadius: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Expanding ring — phaseOffset staggers the two rings by 50%
  Widget _buildRing({
    required double phaseOffset,
    required Color color,
    required double strokeWidth,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final t = (_pulseController.value + phaseOffset) % 1.0;
        final scale = 1.0 + t * 1.4;
        final opacity = (1.0 - t).clamp(0.0, 0.65);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 155,
              height: 155,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: strokeWidth),
              ),
            ),
          ),
        );
      },
    );
  }

  // Logo image with elastic scale + fade
  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (_, __) => Opacity(
        opacity: _logoOpacity.value,
        child: Transform.scale(
          scale: _logoScale.value,
          child: Container(
            width: 138,
            height: 138,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(
                color: Colors.white.withOpacity(0.09),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(22),
            child: Image.asset(
              'assets/images/loader.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  // App name + tagline slide-up reveal
  Widget _buildTextReveal() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (_, __) => FadeTransition(
        opacity: _textOpacity,
        child: SlideTransition(
          position: _textSlide,
          child: Column(
            children: [
              // ── Replace with your actual app name ──
              Text(
                'Kirihat',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4.5,
                ),
              ),
              const SizedBox(height: 8),
              // ── Replace with your actual tagline ──
              Text(
                'Ultra fast delivery',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2 px shimmer-style progress bar at the very bottom
  Widget _buildProgressBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (_, __) => ClipRRect(
          child: LinearProgressIndicator(
            value: _progressController.value,
            minHeight: 2.5,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: const AlwaysStoppedAnimation<Color>(_accentColor),
          ),
        ),
      ),
    );
  }
}

// ─── Particle model ──────────────────────────────────────────────────────────

class _Particle {
  final double x;
  final double y;
  final double radius;
  final double driftSpeed;
  final double baseOpacity;
  final double twinklePhase;

  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.driftSpeed,
    required this.baseOpacity,
    required this.twinklePhase,
  });
}

// ─── Particle painter ────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color accentColor;

  const _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Drift upward, wrap around
      final dy = (p.y - progress * p.driftSpeed) % 1.0;
      // Slow twinkle
      final twinkle = (sin((progress * 2 * pi) + p.twinklePhase * 2 * pi) + 1) / 2;
      final opacity = (p.baseOpacity * (0.4 + 0.6 * twinkle)).clamp(0.0, 1.0);

      // Occasionally tint a particle with accent color
      final isAccent = (p.twinklePhase * 100).toInt() % 7 == 0;
      paint.color = (isAccent ? accentColor : Colors.white).withOpacity(opacity);

      canvas.drawCircle(
        Offset(p.x * size.width, dy * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress;
}