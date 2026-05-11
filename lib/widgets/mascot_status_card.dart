import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A reusable mascot status card that displays a dynamic mascot image
/// with a contextual title and message inside a gradient banner.
///
/// Used across multiple screens to provide personality and visual feedback.
class MascotStatusCard extends StatelessWidget {
  const MascotStatusCard({
    super.key,
    required this.mascotImage,
    required this.statusTitle,
    required this.statusMessage,
    this.gradientColors,
  });

  final String mascotImage;
  final String statusTitle;
  final String statusMessage;

  /// Optional custom gradient colors. Defaults to primary color gradient.
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final List<Color> colors = gradientColors ??
        [primaryColor, primaryColor.withValues(alpha: 0.8)];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: 110,
            margin: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Image.asset(
              mascotImage,
              height: 140,
              width: 140,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 120,
            right: 12,
            top: 36,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    statusTitle.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: colors.first,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
