import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> with SingleTickerProviderStateMixin {
  static const int _workTime = 25 * 60;
  static const int _breakTime = 5 * 60;

  int _remainingSeconds = _workTime;
  bool _isRunning = false;
  bool _isWorkMode = true;
  Timer? _timer;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _workTime),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      _animationController.stop();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _switchMode();
          }
        });
      });
      _animationController.reverse(from: _remainingSeconds / (_isWorkMode ? _workTime : _breakTime));
    }
    setState(() {
      _isRunning = !_isRunning;
    });
  }

  void _switchMode() {
    _timer?.cancel();
    _isWorkMode = !_isWorkMode;
    _remainingSeconds = _isWorkMode ? _workTime : _breakTime;
    _isRunning = false;
    _animationController.duration = Duration(seconds: _remainingSeconds);
    _animationController.value = 1.0;
    
    // Play a sound or vibrate here in a real app
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isWorkMode ? "Time to focus!" : "Take a break!"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isWorkMode = true;
      _remainingSeconds = _workTime;
      _isRunning = false;
      _animationController.stop();
      _animationController.value = 1.0;
    });
  }

  String _formatTime(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color activeColor = _isWorkMode ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Scaffold(
      appBar: AppBar(title: const Text('Focus Timer')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isWorkMode ? 'FOCUS TIME' : 'BREAK TIME',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: activeColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 40),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: _remainingSeconds / (_isWorkMode ? _workTime : _breakTime),
                    strokeWidth: 12,
                    backgroundColor: activeColor.withValues(alpha: 0.1),
                    color: activeColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: GoogleFonts.inter(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'remaining',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimerButton(
                  onPressed: _resetTimer,
                  icon: Icons.refresh_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  iconColor: colorScheme.onSurface,
                ),
                const SizedBox(width: 32),
                _TimerButton(
                  onPressed: _toggleTimer,
                  icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: activeColor,
                  iconColor: Colors.white,
                  size: 80,
                ),
                const SizedBox(width: 32),
                _TimerButton(
                  onPressed: _switchMode,
                  icon: Icons.skip_next_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  iconColor: colorScheme.onSurface,
                ),
              ],
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _isWorkMode 
                  ? "Put your phone away and concentrate on your tasks."
                  : "Stretch, hydrate, and prepare for the next session.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerButton extends StatelessWidget {
  const _TimerButton({
    required this.onPressed,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.size = 60,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            if (size > 60)
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}
