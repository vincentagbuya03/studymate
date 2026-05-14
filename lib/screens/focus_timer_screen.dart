import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/mascot_status_card.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

enum FocusMode { timer, stopwatch }

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with SingleTickerProviderStateMixin {
  FocusMode _currentMode = FocusMode.timer;
  int _timerDurationMinutes = 25;
  int _seconds = 25 * 60;
  bool _isRunning = false;
  bool _isWorkMode = true;
  Timer? _timer;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(minutes: _timerDurationMinutes),
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
          if (_currentMode == FocusMode.timer) {
            if (_seconds > 0) {
              _seconds--;
            } else {
              _switchMode();
            }
          } else {
            _seconds++;
          }
        });
      });
      if (_currentMode == FocusMode.timer) {
        _animationController.reverse(
          from: _seconds / (_timerDurationMinutes * 60),
        );
      } else {
        _animationController.repeat();
      }
    }
    setState(() {
      _isRunning = !_isRunning;
    });
  }

  void _switchMode() {
    _timer?.cancel();
    _isWorkMode = !_isWorkMode;
    _seconds = _isWorkMode ? (_timerDurationMinutes * 60) : (5 * 60);
    _isRunning = false;
    _animationController.duration = Duration(seconds: _seconds);
    _animationController.value = 1.0;

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
      _seconds = _currentMode == FocusMode.timer
          ? (_timerDurationMinutes * 60)
          : 0;
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

  Widget _buildTimerMascotCard() {
    String mascotImage;
    String statusTitle;
    String statusMessage;

    if (_currentMode == FocusMode.stopwatch) {
      if (_isRunning) {
        mascotImage = 'assets/images/mascot_busy.png';
        statusTitle = 'Flow State';
        statusMessage = 'Recording your focus time. Keep going!';
      } else if (_seconds == 0) {
        mascotImage = 'assets/images/mascot_happy.png';
        statusTitle = 'Stopwatch';
        statusMessage = 'Ready to track your study session?';
      } else {
        mascotImage = 'assets/images/mascot_icandoit.png';
        statusTitle = 'Session Paused';
        statusMessage = 'You\'ve focused for ${_formatTime(_seconds)} so far!';
      }
    } else {
      final double progress =
          _seconds / (_isWorkMode ? (_timerDurationMinutes * 60) : (5 * 60));

      if (!_isWorkMode) {
        mascotImage = 'assets/images/sleeping.png';
        statusTitle = 'Break Time!';
        statusMessage = 'Relax and recharge. You earned it!';
      } else if (_isRunning && progress > 0.5) {
        mascotImage = 'assets/images/mascot_busy.png';
        statusTitle = 'Stay Focused!';
        statusMessage = 'You\'re doing great. Keep going!';
      } else if (_isRunning && progress <= 0.5 && progress > 0.15) {
        mascotImage = 'assets/images/thinking.png';
        statusTitle = 'Halfway There!';
        statusMessage = 'Push through, the finish line is close!';
      } else if (_isRunning && progress <= 0.15) {
        mascotImage = 'assets/images/celebrating.png';
        statusTitle = 'Almost Done!';
        statusMessage = 'Just a little more! You\'re amazing!';
      } else if (!_isRunning && _seconds == (_timerDurationMinutes * 60)) {
        mascotImage = 'assets/images/mascot_happy.png';
        statusTitle = 'Ready to Focus?';
        statusMessage =
            'Hit play to start your $_timerDurationMinutes-min session!';
      } else {
        mascotImage = 'assets/images/mascot_icandoit.png';
        statusTitle = 'Paused';
        statusMessage = 'Take a moment. Resume when ready!';
      }
    }

    return MascotStatusCard(
      mascotImage: mascotImage,
      statusTitle: statusTitle,
      statusMessage: statusMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color activeColor = _isWorkMode
        ? colorScheme.primary
        : const Color(0xFF10B981);

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimerMascotCard(),
              const SizedBox(height: 16),
              // Mode Selector
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(
                      FocusMode.timer,
                      Icons.timer_outlined,
                      'Timer',
                    ),
                    _buildModeButton(
                      FocusMode.stopwatch,
                      Icons.av_timer,
                      'Stopwatch',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: CircularProgressIndicator(
                      value: _currentMode == FocusMode.timer
                          ? _seconds /
                                (_isWorkMode
                                    ? (_timerDurationMinutes * 60)
                                    : (5 * 60))
                          : null, // Indeterminate for stopwatch
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
                        _formatTime(_seconds),
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _currentMode == FocusMode.stopwatch
                            ? 'elapsed'
                            : (_isWorkMode ? 'session' : 'break'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_currentMode == FocusMode.timer &&
                  !_isRunning &&
                  _isWorkMode) ...[
                Text(
                  'Duration: $_timerDurationMinutes mins',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _timerDurationMinutes.toDouble(),
                  min: 1,
                  max: 120,
                  divisions: 119,
                  label: '$_timerDurationMinutes min',
                  activeColor: activeColor,
                  onChanged: (val) {
                    setState(() {
                      _timerDurationMinutes = val.toInt();
                      _seconds = _timerDurationMinutes * 60;
                    });
                  },
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh_rounded),
                    padding: const EdgeInsets.all(20),
                    iconSize: 28,
                  ),
                  const SizedBox(width: 24),
                  FilledButton(
                    onPressed: _toggleTimer,
                    style: FilledButton.styleFrom(
                      backgroundColor: activeColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Icon(
                      _isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 36,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'Focus sessions help you study better.\nKeep going, Isko is here!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(FocusMode mode, IconData icon, String label) {
    final isSelected = _currentMode == mode;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (_isRunning) return;
        setState(() {
          _currentMode = mode;
          _resetTimer();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
