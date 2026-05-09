import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';
import '../models/subject.dart';
import '../widgets/progress_ring.dart';
import '../widgets/subject_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.studentName,
    required this.todaySubjects,
    required this.assignments,
    required this.quote,
  });

  final String studentName;
  final List<Subject> todaySubjects;
  final List<Assignment> assignments;
  final String quote;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _clockRefreshInterval = Duration(seconds: 15);

  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(_clockRefreshInterval, (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  /// Builds the dashboard with today's schedule, tasks, progress, and quote.
  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<Subject> subjectsForToday =
        widget.todaySubjects.where((Subject subject) => subject.occursOn(now)).toList()
          ..sort((Subject a, Subject b) {
            final slotA = a.getSlotsForDay(now.weekday).first;
            final slotB = b.getSlotsForDay(now.weekday).first;
            return slotA.startTime.compareTo(slotB.startTime);
          });

    final List<Assignment> pendingAssignments =
        widget.assignments
            .where((Assignment assignment) => !assignment.isCompleted)
            .toList()
          ..sort(
            (Assignment a, Assignment b) => a.dueDate.compareTo(b.dueDate),
          );

    final List<Assignment> nextAssignments = pendingAssignments
        .take(3)
        .toList();
    final int completedCount = widget.assignments
        .where((Assignment assignment) => assignment.isCompleted)
        .length;
    final int pendingCount = widget.assignments.length - completedCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          // Date Header
          Text(
            DateFormat('EEEE, MMMM d').format(now).toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          // Large Elegant Greeting
          Text(
            'Hello, ${widget.studentName.split(' ').first}!',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          _MascotDashboard(
            assignments: widget.assignments,
            completedCount: completedCount,
            pendingCount: pendingCount,
          ),
          const SizedBox(height: 32),
          // Section Title: Quick Actions
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your day with one tap',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          const _QuickActionsRow(),
          const SizedBox(height: 24),
          _SectionTitle(
            title: "Today's Classes",
            subtitle: subjectsForToday.isEmpty
                ? 'No classes scheduled today.'
                : '${subjectsForToday.length} class${subjectsForToday.length == 1 ? '' : 'es'} lined up today',
          ),
          const SizedBox(height: 12),
          if (subjectsForToday.isEmpty)
            const _EmptyState(
              imagePath: 'assets/images/isko.png',
              title: 'Free day mode',
              message: 'Use the extra time to study ahead or take a breather.',
            )
          else
            ...subjectsForToday
                .take(3)
                .map(
                  (Subject subject) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SubjectCard(
                      subject: subject,
                      displayDay: now.weekday,
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          _SectionTitle(
            title: 'Upcoming Assignments',
            subtitle: nextAssignments.isEmpty
                ? 'No pending deadlines right now.'
                : 'Your next ${nextAssignments.length} deadline${nextAssignments.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 12),
          if (nextAssignments.isEmpty)
            const _EmptyState(
              imagePath: 'assets/images/isko_celebrate.png',
              title: 'All caught up',
              message: 'Great job. Your task list is looking clean.',
            )
          else
            ...nextAssignments.map(
              (Assignment assignment) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AssignmentPreviewCard(assignment: assignment),
              ),
            ),
          const SizedBox(height: 12),
          _SectionTitle(
            title: 'Quote of the Day',
            subtitle: 'A little push for today',
          ),
          const SizedBox(height: 12),
          _QuoteCard(quote: widget.quote),
        ],
      ),
    );
  }
}

class _MascotDashboard extends StatelessWidget {
  const _MascotDashboard({
    required this.assignments,
    required this.completedCount,
    required this.pendingCount,
  });

  final List<Assignment> assignments;
  final int completedCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    int overdueCount = 0;
    int dueTodayCount = 0;

    for (final assignment in assignments) {
      if (!assignment.isCompleted) {
        if (assignment.dueDate.isBefore(now)) {
          overdueCount++;
        } else if (assignment.dueDate.year == now.year &&
            assignment.dueDate.month == now.month &&
            assignment.dueDate.day == now.day) {
          dueTodayCount++;
        }
      }
    }

    String mascotImage = 'assets/images/mascot_happy.png';
    String statusTitle = 'All clear!';
    String statusMessage = 'You have no pending tasks.';
    Color accentColor = const Color(0xFF10B981); // Green

    if (overdueCount > 0) {
      mascotImage = 'assets/images/mascot_sad.png';
      statusTitle = 'Uh oh...';
      statusMessage = 'You have $overdueCount overdue task(s).';
      accentColor = const Color(0xFFEF4444); // Red
    } else if (dueTodayCount > 2 || pendingCount > 5) {
      mascotImage = 'assets/images/mascot_busy.png';
      statusTitle = 'Busy day!';
      statusMessage = 'Focus up! You have tasks to do.';
      accentColor = const Color(0xFFF59E0B); // Amber
    } else if (pendingCount > 0) {
      mascotImage = 'assets/images/mascot_happy.png';
      statusTitle = 'Looking good!';
      statusMessage = 'Keep up the steady pace.';
      accentColor = const Color(0xFF2563EB); // Blue
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Green Banner Background
          Container(
            width: double.infinity,
            height: 100,
            margin: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF3B7A57).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          // Mascot - Positioned to peek out
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
          // Speech Bubble Card
          Positioned(
            left: 120,
            right: 12,
            top: 32,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
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
                      color: const Color(0xFF3B7A57),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    this.icon,
    this.imagePath,
    required this.title,
    required this.message,
  });

  final IconData? icon;
  final String? imagePath;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (imagePath != null)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Image.asset(imagePath!, height: 160, fit: BoxFit.contain),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              ),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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

class _AssignmentPreviewCard extends StatelessWidget {
  const _AssignmentPreviewCard({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: assignment.priorityColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  assignment.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assignment.subject,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'DUE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: assignment.priorityColor.withValues(alpha: 0.6),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                assignment.dueLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: assignment.priorityColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              quote,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        _QuickActionItem(
          icon: Icons.calendar_today_rounded,
          label: 'Class',
        ),
        _QuickActionItem(
          icon: Icons.assignment_add,
          label: 'Task',
        ),
        _QuickActionItem(
          icon: Icons.history_edu_rounded,
          label: 'Exam',
        ),
        _QuickActionItem(
          icon: Icons.add_chart_rounded,
          label: 'Grade',
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.04),
              width: 1,
            ),
          ),
          child: Icon(
            icon, 
            color: primaryColor.withValues(alpha: 0.8),
            size: 28,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
