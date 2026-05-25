import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/alarm_service.dart';

class AlarmRingScreen extends StatefulWidget {
  final int alarmId;
  final String title;
  final String body;

  const AlarmRingScreen({
    super.key,
    required this.alarmId,
    required this.title,
    required this.body,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _alarmWindowChannel = MethodChannel(
    'studymate/alarm_window',
  );

  late final AnimationController _pulseController;
  late DateTime _now;
  Timer? _clockTimer;
  bool _isStopping = false;
  double _dragProgress = 0.0;
  final List<_ZzzParticle> _particles = <_ZzzParticle>[];
  int _tickCount = 0;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )
      ..repeat(reverse: true)
      ..addListener(_updateParticles);

    _setAlarmWindowEnabled(true);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _setAlarmWindowEnabled(false);
    _clockTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateParticles() {
    if (!mounted) return;

    if (_dragProgress > 0.8) {
      if (_particles.isNotEmpty) {
        setState(() {
          _particles.clear();
        });
      }
      return;
    }

    setState(() {
      // Update particles
      for (int i = _particles.length - 1; i >= 0; i--) {
        final _ZzzParticle p = _particles[i];
        p.y -= p.speed;
        p.phase += 0.05;
        p.x += math.sin(p.phase) * p.drift;
        p.opacity -= 0.008;

        if (p.opacity <= 0.0) {
          _particles.removeAt(i);
        }
      }

      // Periodically spawn new particles
      _tickCount++;
      if (_tickCount % 40 == 0 && _particles.length < 5) {
        final math.Random random = math.Random();
        _particles.add(
          _ZzzParticle(
            x: (random.nextDouble() - 0.5) * 48,
            y: -20,
            opacity: 0.7 + random.nextDouble() * 0.3,
            scale: 0.7 + random.nextDouble() * 0.7,
            speed: 0.6 + random.nextDouble() * 0.7,
            drift: 0.2 + random.nextDouble() * 0.4,
            phase: random.nextDouble() * math.pi * 2,
          ),
        );
      }
    });
  }

  String _getGreeting() {
    final int hour = _now.hour;
    final String? userDisplayName = FirebaseAuth.instance.currentUser?.displayName?.split(' ').first;
    final String nameSuffix = userDisplayName != null && userDisplayName.trim().isNotEmpty
        ? ', ${userDisplayName.trim()}'
        : '';

    if (hour >= 5 && hour < 12) {
      return 'Good Morning$nameSuffix! ☀️';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon$nameSuffix! ☕';
    } else if (hour >= 17 && hour < 22) {
      return 'Good Evening$nameSuffix! 🌙';
    } else {
      return 'Rest Well$nameSuffix! 🦉';
    }
  }

  Future<void> _setAlarmWindowEnabled(bool enabled) async {
    try {
      await _alarmWindowChannel.invokeMethod<void>('setAlarmWindowEnabled', {
        'enabled': enabled,
      });
    } catch (_) {
      // Non-Android platforms do not need lock-screen window flags.
    }
  }

  Future<void> _stopAlarm() async {
    if (_isStopping) {
      return;
    }
    setState(() {
      _isStopping = true;
    });
    await AlarmService.instance.stopAlarm(widget.alarmId);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primaryText = colorScheme.onSurface;
    final Color secondaryText = colorScheme.onSurface.withValues(alpha: 0.68);
    final Color mutedText = colorScheme.onSurface.withValues(alpha: 0.48);
    final String period = _now.hour >= 12 ? 'PM' : 'AM';
    final bool isDay = _now.hour >= 6 && _now.hour < 18;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const <Color>[
                      Color(0xFF1E1A3A),
                      Color(0xFF141226),
                      Color(0xFF090810),
                    ]
                  : const <Color>[
                      Color(0xFFFFE5EC),
                      Color(0xFFFFECE0),
                      Color(0xFFE8F2FE),
                    ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double horizontalPadding = constraints.maxWidth < 390 ? 20 : 28;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    20,
                  ),
                  child: Column(
                    children: <Widget>[
                      _StatusHeader(now: _now, color: primaryText),
                      const Spacer(),
                      _GreetingHeader(
                        now: _now,
                        greetingText: _getGreeting(),
                        primaryColor: colorScheme.primary,
                        textColor: primaryText,
                      ),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final double pulse = 0.8 + (_pulseController.value * 0.2);
                          return Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: 0.98 + (_pulseController.value * 0.04),
                                child: _CuteWakingCharacter(
                                  dragProgress: _dragProgress,
                                  pulse: pulse,
                                  isDay: isDay,
                                  primaryColor: colorScheme.primary,
                                  secondaryColor: colorScheme.secondary,
                                  surfaceColor: colorScheme.surface,
                                ),
                              ),
                              ..._particles.map((p) {
                                return Positioned(
                                  left: 94 + p.x - (12 * p.scale / 2),
                                  top: 94 + p.y - (12 * p.scale / 2) - 52,
                                  child: Opacity(
                                    opacity: p.opacity.clamp(0.0, 1.0),
                                    child: Transform.scale(
                                      scale: p.scale,
                                      child: Transform.rotate(
                                        angle: p.phase * 0.1,
                                        child: Text(
                                          'Z',
                                          style: TextStyle(
                                            color: colorScheme.primary.withValues(alpha: 0.6),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 38),
                      // Time, Date & Title card
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: isDark ? 0.45 : 0.85),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.12),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.title.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    _formatClockTime(_now),
                                    style: TextStyle(
                                      color: primaryText,
                                      fontSize: 68,
                                      height: 0.95,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    period,
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _dateLabel(_now),
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (widget.body.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Divider(
                                  height: 1,
                                  color: colorScheme.primary.withValues(alpha: 0.08),
                                ),
                              ),
                              Text(
                                widget.body,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(flex: 2),
                      _SlideToStop(
                        enabled: !_isStopping,
                        primaryColor: colorScheme.primary,
                        surfaceColor: colorScheme.surface,
                        textColor: colorScheme.onSurface,
                        onCompleted: _stopAlarm,
                        onProgressChanged: (progress) {
                          setState(() {
                            _dragProgress = progress;
                          });
                        },
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _isStopping ? 'Stopping alarm...' : 'Snooze - 5 min',
                        style: TextStyle(
                          color: mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatClockTime(DateTime dateTime) {
    final int hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _dateLabel(DateTime dateTime) {
    const List<String> weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[dateTime.weekday - 1]}, '
        '${months[dateTime.month - 1]} ${dateTime.day}';
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.now, required this.color});

  final DateTime now;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final int hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final String minute = now.minute.toString().padLeft(2, '0');

    return Row(
      children: <Widget>[
        Text(
          '$hour:$minute',
          style: TextStyle(
            color: color.withValues(alpha: 0.88),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.wifi_rounded,
          color: color.withValues(alpha: 0.58),
          size: 18,
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.battery_full_rounded,
          color: color.withValues(alpha: 0.58),
          size: 20,
        ),
      ],
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  final DateTime now;
  final String greetingText;
  final Color primaryColor;
  final Color textColor;

  const _GreetingHeader({
    required this.now,
    required this.greetingText,
    required this.primaryColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.alarm_rounded,
                size: 14,
                color: primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'STUDYMATE ALARM',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          greetingText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _ZzzParticle {
  double x;
  double y;
  double opacity;
  double scale;
  double speed;
  double drift;
  double phase;

  _ZzzParticle({
    required this.x,
    required this.y,
    required this.opacity,
    required this.scale,
    required this.speed,
    required this.drift,
    required this.phase,
  });
}

class _CuteWakingCharacter extends StatelessWidget {
  const _CuteWakingCharacter({
    required this.dragProgress,
    required this.pulse,
    required this.isDay,
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
  });

  final double dragProgress;
  final double pulse;
  final bool isDay;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 188,
      height: 188,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Soft outer glowing backdrops (Claymorphic depth)
          Container(
            width: 164,
            height: 164,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (isDay ? const Color(0xFFFFB74D) : const Color(0xFF818CF8))
                      .withValues(alpha: 0.32 * pulse),
                  blurRadius: 44,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: secondaryColor.withValues(alpha: 0.22 * pulse),
                  blurRadius: 84,
                  spreadRadius: 18,
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(150, 150),
            painter: _CuteWakingCharacterPainter(
              dragProgress: dragProgress,
              pulse: pulse,
              isDay: isDay,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              surfaceColor: surfaceColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CuteWakingCharacterPainter extends CustomPainter {
  const _CuteWakingCharacterPainter({
    required this.dragProgress,
    required this.pulse,
    required this.isDay,
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
  });

  final double dragProgress;
  final double pulse;
  final bool isDay;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width * 0.38;

    if (isDay) {
      // --- DRAW SUN ---
      // Rays
      final Paint rayPaint = Paint()
        ..color = const Color(0xFFFFB74D)
        ..style = PaintingStyle.fill;
      
      const int numRays = 8;
      for (int i = 0; i < numRays; i++) {
        // Subtle ray rotation + pulse distance scaling
        final double angle = (i * 2 * math.pi / numRays) + (pulse * 0.04);
        final double dist = radius + 12 + (6 * pulse);
        final double rayRadius = 7.0 + (1.5 * pulse);
        final Offset rayCenter = Offset(
          center.dx + math.cos(angle) * dist,
          center.dy + math.sin(angle) * dist,
        );
        canvas.drawCircle(rayCenter, rayRadius, rayPaint);
      }

      // Sun body (golden gradient)
      final Paint sunPaint = Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFFFFF176),
            Color(0xFFFFB74D),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, sunPaint);

      // Sun body outline for premium finished look
      final Paint outlinePaint = Paint()
        ..color = const Color(0xFFF57C00).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius, outlinePaint);

      // Face coordinates
      _drawFace(canvas, center, radius, const Color(0xFF4E342E));
    } else {
      // --- DRAW MOON ---
      // Star sparkles in background
      final Paint starPaint = Paint()
        ..color = const Color(0xFFFFF9C4).withValues(alpha: 0.6 + 0.4 * pulse)
        ..style = PaintingStyle.fill;
      final List<Offset> stars = [
        Offset(center.dx - 48, center.dy - 48),
        Offset(center.dx + 52, center.dy - 36),
        Offset(center.dx + 40, center.dy + 48),
      ];
      for (final star in stars) {
        canvas.drawCircle(star, 3 * pulse, starPaint);
      }

      // Crescent moon shape
      final Paint moonPaint = Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFFFFFDE7),
            Color(0xFFFFF59D),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      final Path moonPath = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        Path()..addOval(Rect.fromCircle(center: Offset(center.dx + 16, center.dy - 4), radius: radius - 4)),
      );
      canvas.drawPath(moonPath, moonPaint);

      // Moon outline
      final Paint outlinePaint = Paint()
        ..color = const Color(0xFFFBC02D).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawPath(moonPath, outlinePaint);

      // Cute nightcap on top of moon
      final Paint hatPaint = Paint()
        ..color = const Color(0xFF818CF8)
        ..style = PaintingStyle.fill;
      final Path hatPath = Path();
      hatPath.moveTo(center.dx - 12, center.dy - radius + 8);
      hatPath.quadraticBezierTo(
        center.dx + 6, center.dy - radius - 26,
        center.dx + 28, center.dy - radius - 16,
      );
      hatPath.quadraticBezierTo(
        center.dx + 12, center.dy - radius + 2,
        center.dx - 4, center.dy - radius + 14,
      );
      hatPath.close();
      canvas.drawPath(hatPath, hatPaint);

      // Nightcap stripes (white)
      final Paint stripePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.save();
      canvas.clipPath(hatPath);
      // Draw horizontal lines across hat bounds
      for (double y = center.dy - radius - 30; y < center.dy - radius + 20; y += 10) {
        canvas.drawLine(
          Offset(center.dx - 30, y),
          Offset(center.dx + 40, y + 10),
          stripePaint,
        );
      }
      canvas.restore();

      // Pom-pom ball
      final Paint pomPomPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(center.dx + 28, center.dy - radius - 16), 6, pomPomPaint);

      // Face shifted leftwards onto crescent moon
      _drawFace(canvas, Offset(center.dx - 10, center.dy + 2), radius, const Color(0xFF37474F));
    }
  }

  void _drawFace(Canvas canvas, Offset center, double radius, Color faceColor) {
    // 1. BLUSH CHEEKS
    final Paint blushPaint = Paint()
      ..color = Colors.pinkAccent.withValues(alpha: 0.35 + (0.35 * dragProgress))
      ..style = PaintingStyle.fill;
    
    // Draw rosy circles
    canvas.drawCircle(Offset(center.dx - 20, center.dy + 8), 6.5, blushPaint);
    canvas.drawCircle(Offset(center.dx + 20, center.dy + 8), 6.5, blushPaint);

    final Paint eyeStrokePaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final Paint eyeFillPaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;

    // 2. EYES
    if (dragProgress < 0.25) {
      // Sleepy eyes (curved arcs facing down)
      final Rect leftEyeRect = Rect.fromCenter(
        center: Offset(center.dx - 18, center.dy - 3),
        width: 12,
        height: 8,
      );
      final Rect rightEyeRect = Rect.fromCenter(
        center: Offset(center.dx + 18, center.dy - 3),
        width: 12,
        height: 8,
      );
      canvas.drawArc(leftEyeRect, 0, math.pi, false, eyeStrokePaint);
      canvas.drawArc(rightEyeRect, 0, math.pi, false, eyeStrokePaint);
    } else if (dragProgress < 0.75) {
      // Waking up eyes (curved line left, oval right or double ovals)
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx - 18, center.dy - 3), width: 9, height: 13),
        eyeFillPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx + 18, center.dy - 3), width: 9, height: 13),
        eyeFillPaint,
      );

      // Shine highlights
      final Paint shinePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(center.dx - 19, center.dy - 5), 2.2, shinePaint);
      canvas.drawCircle(Offset(center.dx + 17, center.dy - 5), 2.2, shinePaint);
    } else {
      // Wide awake happy eyes (curved arcs facing up ^ ^)
      final Rect leftEyeRect = Rect.fromCenter(
        center: Offset(center.dx - 18, center.dy - 1),
        width: 12,
        height: 8,
      );
      final Rect rightEyeRect = Rect.fromCenter(
        center: Offset(center.dx + 18, center.dy - 1),
        width: 12,
        height: 8,
      );
      canvas.drawArc(leftEyeRect, math.pi, math.pi, false, eyeStrokePaint);
      canvas.drawArc(rightEyeRect, math.pi, math.pi, false, eyeStrokePaint);
    }

    // 3. MOUTH
    if (dragProgress < 0.25) {
      // Sleepy mouth (tiny circular o)
      final Paint mouthPaint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(center.dx, center.dy + 10), 3.5, mouthPaint);
    } else if (dragProgress < 0.75) {
      // Waking up mouth (small cute smile arc)
      final Paint mouthPaint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final Rect mouthRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + 7),
        width: 9,
        height: 7,
      );
      canvas.drawArc(mouthRect, 0, math.pi, false, mouthPaint);
    } else {
      // Wide awake happy open mouth with cute tongue
      final Paint mouthPaint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.fill;
      
      final Path mouthPath = Path();
      mouthPath.arcTo(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 7), width: 14, height: 12),
        0,
        math.pi,
        true,
      );
      mouthPath.close();
      canvas.drawPath(mouthPath, mouthPaint);

      // Tongue clip & draw
      final Paint tonguePaint = Paint()..color = const Color(0xFFFF8A80);
      canvas.save();
      canvas.clipPath(mouthPath);
      canvas.drawCircle(Offset(center.dx, center.dy + 12), 5, tonguePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CuteWakingCharacterPainter oldDelegate) {
    return oldDelegate.dragProgress != dragProgress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isDay != isDay ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}

class _SlideToStop extends StatefulWidget {
  const _SlideToStop({
    required this.enabled,
    required this.primaryColor,
    required this.surfaceColor,
    required this.textColor,
    required this.onCompleted,
    required this.onProgressChanged,
  });

  final bool enabled;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textColor;
  final Future<void> Function() onCompleted;
  final ValueChanged<double> onProgressChanged;

  @override
  State<_SlideToStop> createState() => _SlideToStopState();
}

class _SlideToStopState extends State<_SlideToStop>
    with SingleTickerProviderStateMixin {
  double _dragProgress = 0.0;
  bool _completed = false;
  late final AnimationController _resetController;
  Animation<double>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _updateProgress(double val) {
    setState(() {
      _dragProgress = val;
    });
    widget.onProgressChanged(val);
  }

  void _resetProgress() {
    _resetAnimation = Tween<double>(
      begin: _dragProgress,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutBack,
    ))
      ..addListener(() {
        _updateProgress(_resetAnimation!.value);
      });
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double height = 64;
        const double thumbSize = 54;
        final double trackWidth = constraints.maxWidth.clamp(260.0, 360.0);
        final double travel = trackWidth - thumbSize - 10;
        final double thumbLeft = 5 + (travel * _dragProgress);

        return Center(
          child: GestureDetector(
            onHorizontalDragUpdate: widget.enabled && !_completed
                ? (details) {
                    _resetController.stop();
                    _updateProgress(
                      (_dragProgress + details.delta.dx / travel).clamp(0.0, 1.0),
                    );
                  }
                : null,
            onHorizontalDragEnd: widget.enabled && !_completed
                ? (_) async {
                    if (_dragProgress >= 0.8) {
                      setState(() {
                        _completed = true;
                      });
                      _updateProgress(1.0);
                      await widget.onCompleted();
                    } else {
                      _resetProgress();
                    }
                  }
                : null,
            child: Container(
              width: trackWidth,
              height: height,
              decoration: BoxDecoration(
                color: widget.surfaceColor.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(
                  color: widget.primaryColor.withValues(alpha: 0.16),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: widget.primaryColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Growing background gradient fill
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(height / 2),
                      child: FractionallySizedBox(
                        widthFactor: _dragProgress,
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                const Color(0xFFFFB74D).withValues(alpha: 0.55),
                                const Color(0xFFFF4081).withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Centered instruction text (fading out during drag)
                  Opacity(
                    opacity: (1.0 - _dragProgress * 1.5).clamp(0.0, 1.0),
                    child: Text(
                      '>>> SLIDE TO WAKE UP',
                      style: TextStyle(
                        color: widget.textColor.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  if (_completed)
                    Text(
                      'GOOD MORNING!',
                      style: TextStyle(
                        color: widget.textColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                  // Sliding Cute Thumb
                  Positioned(
                    left: thumbLeft,
                    top: 5,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: widget.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: widget.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _completed
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 28,
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    '◡',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 0.8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
