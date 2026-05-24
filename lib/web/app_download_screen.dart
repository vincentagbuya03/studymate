import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/analytics_service.dart';

class AppDownloadScreen extends StatefulWidget {
  const AppDownloadScreen({super.key});

  @override
  State<AppDownloadScreen> createState() => _AppDownloadScreenState();
}

class _AppDownloadScreenState extends State<AppDownloadScreen> {
  AppPublicMetrics _metrics = AppPublicMetrics.fallback;
  List<AppReview> _reviews = const <AppReview>[];
  bool _isLoading = true;
  StreamSubscription<AppPublicMetrics>? _metricsSubscription;
  StreamSubscription<List<AppReview>>? _reviewsSubscription;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _metricsSubscription = AnalyticsService.instance
        .watchPublicMetrics()
        .listen(
          (metrics) {
            if (!mounted) {
              return;
            }
            setState(() {
              _metrics = metrics;
              _isLoading = false;
            });
          },
          onError: (Object error) {
            debugPrint('Could not watch public metrics: $error');
          },
        );
    _reviewsSubscription = AnalyticsService.instance
        .watchPublicReviews()
        .listen(
          (reviews) {
            if (!mounted) {
              return;
            }
            setState(() {
              _reviews = reviews;
            });
          },
          onError: (Object error) {
            debugPrint('Could not watch public reviews: $error');
          },
        );
  }

  @override
  void dispose() {
    _metricsSubscription?.cancel();
    _reviewsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    final metrics = await AnalyticsService.instance.getPublicMetrics();
    if (!mounted) {
      return;
    }
    setState(() {
      _metrics = metrics;
      _isLoading = false;
    });
  }

  Future<void> _handleDownload() async {
    final Uri url = Uri.parse('/StudyMate.apk');
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch download link. Please try again.'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Download started! Thank you for choosing StudyMate.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF000000,
      ), // Pure Black to match picture.png
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;
          return Stack(
            children: [
              // Subtle background glow
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  children: [
                    _buildNavBar(isMobile),
                    _buildHeroSection(isMobile),
                    _buildReviewsSection(isMobile),
                    _buildFeaturesSection(isMobile),
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavBar(bool isMobile) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          color: Colors.white.withValues(alpha: 0.03),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 48,
            vertical: 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'StudyMate',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              if (!isMobile)
                ElevatedButton(
                  onPressed: _handleDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Get App Now',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 48.0,
        vertical: isMobile ? 40.0 : 80.0,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // The main banner image
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      blurRadius: 100,
                      spreadRadius: -20,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/images/picture.png',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 400,
                        width: double.infinity,
                        color: const Color(0xFF1E293B),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 64),
              // Content below the banner
              if (isMobile)
                _buildMobileHeroContent()
              else
                _buildDesktopHeroContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeroContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unlock Your Full Potential.',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Join thousands of students who have already transformed their academic life with StudyMate. Offline-first, secure, and built for success.',
                style: TextStyle(
                  fontSize: 18,
                  color: const Color(0xFF94A3B8),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildCtaAndStats(),
      ],
    );
  }

  Widget _buildMobileHeroContent() {
    return Column(
      children: [
        Text(
          'Unlock Your Potential',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32, // Reduced from 40
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'The all-in-one assistant for modern students.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14, // Reduced from 16
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 32),
        _buildCtaAndStats(isCenter: true),
      ],
    );
  }

  Widget _buildCtaAndStats({bool isCenter = false}) {
    return Column(
      crossAxisAlignment: isCenter
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (!isCenter) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan to Download',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.network(
                      'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://studymates-app.vercel.app/StudyMate.apk',
                      width: 150,
                      height: 150,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _handleDownload,
                icon: const Icon(Icons.download, size: 24),
                label: Text(
                  'Download APK Free',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 20,
                  shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: _handleDownload,
            icon: const Icon(Icons.download, size: 24),
            label: Text(
              'Download APK Free',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 20,
              shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
            ),
          ),
        ],
        const SizedBox(height: 40),
        _isLoading
            ? const CircularProgressIndicator()
            : Column(
                crossAxisAlignment: isCenter
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniStat('${_metrics.studentCount}+', 'Students'),
                      const SizedBox(width: 32),
                      _buildMiniStat(
                        '${_metrics.ratingAverage.toStringAsFixed(1)}/5',
                        _metrics.ratingCount == 0
                            ? 'Rating'
                            : '${_metrics.ratingCount} ratings',
                      ),
                    ],
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(bool isMobile) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0A0A0A), // Near black
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 48.0,
        vertical: 100.0,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'Built for Excellence',
                style: TextStyle(
                  fontSize: isMobile ? 32 : 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 80),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildGlassFeature(
                    icon: Icons.wifi_off_rounded,
                    title: 'Offline First',
                    desc: 'Your data stays with you. No internet required.',
                    color: Colors.greenAccent,
                  ),
                  _buildGlassFeature(
                    icon: Icons.notifications_active_rounded,
                    title: 'Smart Alerts',
                    desc: 'Precise notifications to keep you on schedule.',
                    color: Colors.orangeAccent,
                  ),
                  _buildGlassFeature(
                    icon: Icons.analytics_rounded,
                    title: 'GWA Tracking',
                    desc: 'Real-time grade calculation and analytics.',
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection(bool isMobile) {
    if (_reviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 48.0,
        vertical: 80.0,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Loved by Students',
                style: TextStyle(
                  fontSize: isMobile ? 30 : 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: _reviews.map(_buildReviewCard).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(AppReview review) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < review.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: const Color(0xFFFBBF24),
                size: 20,
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            '"${review.comment}"',
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            review.displayName,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassFeature({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 48),
      child: Column(
        children: [
          const Icon(Icons.school, color: Color(0xFF6366F1), size: 40),
          const SizedBox(height: 24),
          Text(
            'Step into the future of learning.',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 48),
          const Divider(color: Colors.white10),
          const SizedBox(height: 48),
          Text(
            '© ${DateTime.now().year} StudyMate. All rights reserved.',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
