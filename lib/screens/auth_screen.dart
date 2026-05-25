import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../services/auth_service.dart';
import '../utils/app_error_messages.dart';
import '../widgets/app_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;

  late final PageController _pageController;
  int _currentSlide = 0;
  Timer? _carouselTimer;

  late final AnimationController _backgroundController;
  late final AnimationController _entranceController;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  static const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
</svg>
''';

  static const List<_FeatureSlide> _slides = [
    _FeatureSlide(
      lottieAsset: 'assets/lottie/study.json',
      title: 'Elevate Your Learning',
      description: 'Keep your subjects and study items perfectly synced.',
    ),
    _FeatureSlide(
      lottieAsset: 'assets/lottie/notification.json',
      title: 'Stay Ahead of Tasks',
      description: 'Receive smart, timely notifications and custom reminders.',
    ),
    _FeatureSlide(
      lottieAsset: 'assets/lottie/schedule.json',
      title: 'Master Your Schedule',
      description: 'Organize your classes, exams, and grades effortlessly.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _error = widget.initialMessage;

    _pageController = PageController();
    _startCarouselTimer();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _entranceController.forward();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      final int nextSlide = (_currentSlide + 1) % _slides.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextSlide,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentSlide = index;
    });
    _carouselTimer?.cancel();
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _backgroundController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) {
        final routeName = ModalRoute.of(context)?.settings.name;
        if (routeName == '/login') {
          Navigator.of(context).pushReplacementNamed(kIsWeb ? '/app' : '/');
        } else if (routeName == '/admin-login') {
          Navigator.of(context).pushReplacementNamed('/admin');
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Google sign-in failed: $e');
      setState(() {
        _error = friendlyAuthError(e);
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Firebase auth failed: ${e.code} ${e.message}');
      setState(() {
        _error = friendlyAuthError(e);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Authentication failed: $e');
      setState(() {
        _error = friendlyAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Ambient animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _AmbientBackgroundPainter(
                    animationValue: _backgroundController.value,
                    brightness: theme.brightness,
                    primaryColor: theme.colorScheme.primary,
                    secondaryColor: theme.colorScheme.secondary,
                  ),
                );
              },
            ),
          ),

          // 2. Main content container
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // App Carousel Showcase
                          SizedBox(
                            height: 290,
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: _onPageChanged,
                              itemCount: _slides.length,
                              itemBuilder: (context, index) {
                                final slide = _slides[index];
                                return AnimatedOpacity(
                                  duration: const Duration(milliseconds: 350),
                                  opacity: _currentSlide == index ? 1.0 : 0.0,
                                  child: TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 350),
                                    tween: Tween(
                                      begin: 0.95,
                                      end: _currentSlide == index ? 1.0 : 0.95,
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, scale, child) {
                                      return Transform.scale(
                                        scale: scale,
                                        child: child,
                                      );
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Lottie.asset(
                                            slide.lottieAsset,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          slide.title,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color:
                                                    theme.colorScheme.onSurface,
                                                letterSpacing: -0.5,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          slide.description,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                                height: 1.3,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Indicator Dots
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _slides.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                height: 6,
                                width: _currentSlide == index ? 18 : 6,
                                decoration: BoxDecoration(
                                  color: _currentSlide == index
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.primary.withValues(
                                          alpha: 0.25,
                                        ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Glassmorphic Card Container
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(
                                alpha: isDark ? 0.70 : 0.85,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: isDark ? 0.08 : 0.12,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.25 : 0.06,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 16,
                                  sigmaY: 16,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 28,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Center(
                                        child: AppLogo(
                                          size: 80,
                                          isSquare: true,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Welcome to StudyMate',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Sync your classes, tasks, exams, and grades across devices.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.5),
                                            ),
                                      ),

                                      if (_error != null) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.error
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: theme.colorScheme.error
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                              color: theme.colorScheme.error,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 24),

                                      // Premium Google button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _isLoading
                                              ? null
                                              : _signInWithGoogle,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                              horizontal: 20,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _isLoading
                                                  ? theme.colorScheme.onSurface
                                                        .withValues(alpha: 0.05)
                                                  : theme.colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(
                                                      alpha: _isLoading
                                                          ? 0.05
                                                          : 0.12,
                                                    ),
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                if (!_isLoading)
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.04,
                                                        ),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (_isLoading)
                                                  const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                        ),
                                                  )
                                                else ...[
                                                  SvgPicture.string(
                                                    _googleLogoSvg,
                                                    width: 22,
                                                    height: 22,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Continue with Google',
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 15,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface,
                                                        ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.security_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Secured by Firebase Authentication',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureSlide {
  final String lottieAsset;
  final String title;
  final String description;

  const _FeatureSlide({
    required this.lottieAsset,
    required this.title,
    required this.description,
  });
}

class _AmbientBackgroundPainter extends CustomPainter {
  final double animationValue;
  final Brightness brightness;
  final Color primaryColor;
  final Color secondaryColor;

  _AmbientBackgroundPainter({
    required this.animationValue,
    required this.brightness,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = brightness == Brightness.dark;

    // Fill plain background first to prevent artifacts
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF0F110E) : const Color(0xFFF7F9F2);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 85);

    // Circle 1: Mint/Teal
    final double x1 =
        size.width * (0.3 + 0.15 * math.sin(animationValue * 2 * math.pi));
    final double y1 =
        size.height * (0.2 + 0.1 * math.cos(animationValue * 2 * math.pi));
    paint.color = primaryColor.withValues(alpha: isDark ? 0.12 : 0.18);
    canvas.drawCircle(Offset(x1, y1), size.width * 0.55, paint);

    // Circle 2: Sage
    final double x2 =
        size.width *
        (0.75 + 0.15 * math.cos(animationValue * 2 * math.pi + 1.0));
    final double y2 =
        size.height *
        (0.5 + 0.15 * math.sin(animationValue * 2 * math.pi + 1.0));
    paint.color = secondaryColor.withValues(alpha: isDark ? 0.10 : 0.15);
    canvas.drawCircle(Offset(x2, y2), size.width * 0.65, paint);

    // Circle 3: Warm Orange Accent
    final double x3 =
        size.width * (0.4 + 0.2 * math.sin(animationValue * 2 * math.pi + 2.0));
    final double y3 =
        size.height *
        (0.8 + 0.1 * math.cos(animationValue * 2 * math.pi + 2.0));
    paint.color = const Color(
      0xFFF97316,
    ).withValues(alpha: isDark ? 0.05 : 0.08);
    canvas.drawCircle(Offset(x3, y3), size.width * 0.45, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.brightness != brightness ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
