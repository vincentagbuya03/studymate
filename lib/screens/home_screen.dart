import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';
import '../models/subject.dart';
import '../widgets/mascot_status_card.dart';
import '../widgets/subject_card.dart';

class HomeScreen extends StatefulWidget {
  final String studentName;
  final List<Subject> todaySubjects;
  final List<Assignment> assignments;
  final String quote;
  final VoidCallback? onAddClass;
  final VoidCallback? onAddTask;
  final VoidCallback? onAddExam;
  final VoidCallback? onAddGrade;

  const HomeScreen({
    super.key,
    required this.studentName,
    required this.todaySubjects,
    required this.assignments,
    required this.quote,
    this.onAddClass,
    this.onAddTask,
    this.onAddExam,
    this.onAddGrade,
  });

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

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<Subject> subjectsForToday =
        widget.todaySubjects
            .where((Subject subject) => subject.occursOn(now))
            .toList()
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
          Text(
            DateFormat('EEEE, MMMM d').format(now).toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
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
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          _QuickActionsRow(
            onAddClass: widget.onAddClass,
            onAddTask: widget.onAddTask,
            onAddExam: widget.onAddExam,
            onAddGrade: widget.onAddGrade,
          ),
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
              imagePath: 'assets/images/mascot_happy.png',
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
              imagePath: 'assets/images/celebrating.png',
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

    final int hour = now.hour;
    final bool isLate = hour >= 22 || hour <= 4;
    final bool allDone = pendingCount == 0 && completedCount > 0;

    if (overdueCount > 0) {
      mascotImage = 'assets/images/mascot_sad.png';
      statusTitle = 'Uh oh...';
      statusMessage = 'You have $overdueCount overdue task(s).';
    } else if (allDone) {
      mascotImage = 'assets/images/celebrating.png';
      statusTitle = 'Amazing!';
      statusMessage = 'You\'ve finished all your tasks for now.';
    } else if (isLate && pendingCount == 0) {
      mascotImage = 'assets/images/sleeping.png';
      statusTitle = 'Zzz...';
      statusMessage = 'Nothing left to do. Get some rest!';
    } else if (pendingCount > 8) {
      mascotImage = 'assets/images/mascout_tired.png';
      statusTitle = 'Whew!';
      statusMessage = 'A lot on your plate. Take it one by one.';
    } else if (dueTodayCount > 0 || pendingCount > 3) {
      mascotImage = 'assets/images/mascot_busy.png';
      statusTitle = 'Busy day!';
      statusMessage = 'Focus up! You have tasks to do.';
    } else if (pendingCount == 0) {
      mascotImage = 'assets/images/mascot_happy.png';
      statusTitle = 'Free time!';
      statusMessage = 'Enjoy your day, Isko is here!';
    } else {
      mascotImage = 'assets/images/mascot_happy.png';
      statusTitle = 'Looking good!';
      statusMessage = 'Keep up the steady pace.';
    }

    return MascotStatusCard(
      mascotImage: mascotImage,
      statusTitle: statusTitle,
      statusMessage: statusMessage,
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
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    this.imagePath,
    required this.title,
    required this.message,
  });

  final String? imagePath;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          if (imagePath != null) Image.asset(imagePath!, height: 100),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentPreviewCard extends StatelessWidget {
  const _AssignmentPreviewCard({required this.assignment});
  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: assignment.priorityColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_rounded,
                color: assignment.priorityColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    assignment.subject,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              assignment.dueLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: assignment.priorityColor,
              ),
            ),
          ],
        ),
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
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
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
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    this.onAddClass,
    this.onAddTask,
    this.onAddExam,
    this.onAddGrade,
  });

  final VoidCallback? onAddClass;
  final VoidCallback? onAddTask;
  final VoidCallback? onAddExam;
  final VoidCallback? onAddGrade;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _QuickActionItem(
          icon: Icons.calendar_today_rounded,
          label: 'Class',
          onTap: onAddClass,
        ),
        _QuickActionItem(
          icon: Icons.assignment_add,
          label: 'Task',
          onTap: onAddTask,
        ),
        _QuickActionItem(
          icon: Icons.history_edu_rounded,
          label: 'Exam',
          onTap: onAddExam,
        ),
        _QuickActionItem(
          icon: Icons.add_chart_rounded,
          label: 'Grade',
          onTap: onAddGrade,
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Icon(icon, color: primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
