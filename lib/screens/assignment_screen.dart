import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';
import '../models/subject.dart';
import '../widgets/assignment_card.dart';
import '../widgets/mascot_status_card.dart';
import '../widgets/editor_sheets.dart';

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({
    super.key,
    required this.assignments,
    required this.subjects,
    required this.onAddAssignment,
    required this.onUpdateAssignment,
    required this.onToggleStatus,
    required this.onDeleteAssignment,
  });

  final List<Assignment> assignments;
  final List<Subject> subjects;
  final Future<void> Function(Assignment assignment) onAddAssignment;
  final Future<void> Function(Assignment assignment) onUpdateAssignment;
  final Future<void> Function(Assignment assignment) onToggleStatus;
  final Future<void> Function(int id) onDeleteAssignment;

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  static const Duration _clockRefreshInterval = Duration(seconds: 15);

  String _subjectFilter = 'All';
  String _priorityFilter = 'All';
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

  List<Assignment> _filteredAssignments() {
    return widget.assignments.where((Assignment assignment) {
        final bool matchesSubject =
            _subjectFilter == 'All' || assignment.subject == _subjectFilter;
        final bool matchesPriority =
            _priorityFilter == 'All' ||
            assignment.priorityLabel == _priorityFilter;
        return matchesSubject && matchesPriority;
      }).toList()
      ..sort((Assignment a, Assignment b) => a.dueDate.compareTo(b.dueDate));
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _openAssignmentSheet([Assignment? assignment]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return AssignmentEditorSheet(
          subjects: widget.subjects,
          assignment: assignment,
          onSave: (Assignment updated) async {
            Navigator.of(context).pop();
            if (assignment == null) {
              await widget.onAddAssignment(updated);
            } else {
              await widget.onUpdateAssignment(updated);
            }
          },
        );
      },
    );
  }

  Widget _buildMascotCard(
    List<Assignment> filtered,
    List<Assignment> todayAssignments,
    List<Assignment> overdueAssignments,
    List<Assignment> upcomingAssignments,
    List<Assignment> completedAssignments,
  ) {
    String mascotImage;
    String statusTitle;
    String statusMessage;

    final int overdueCount = overdueAssignments.length;
    final int pendingCount = filtered.where((a) => !a.isCompleted).length;
    final int completedCount = completedAssignments.length;
    final bool allDone = pendingCount == 0 && completedCount > 0;

    if (filtered.isEmpty) {
      mascotImage = 'assets/images/mascot_icandoit.png';
      statusTitle = 'Empty Board';
      statusMessage = 'No tasks yet. Add one to get started!';
    } else if (overdueCount > 0) {
      mascotImage = 'assets/images/mascot_sad.png';
      statusTitle = 'Overdue Alert!';
      statusMessage = 'You have $overdueCount overdue task(s). Catch up!';
    } else if (allDone) {
      mascotImage = 'assets/images/celebrating.png';
      statusTitle = 'All Done!';
      statusMessage = 'Every task is complete. You\'re on fire! 🔥';
    } else if (pendingCount > 8) {
      mascotImage = 'assets/images/mascout_tired.png';
      statusTitle = 'Heavy Load!';
      statusMessage = 'That\'s a lot of tasks. Take it step by step.';
    } else if (todayAssignments.isNotEmpty) {
      mascotImage = 'assets/images/mascot_busy.png';
      statusTitle = 'Due Today!';
      statusMessage = '${todayAssignments.length} task(s) due today. Focus up!';
    } else if (upcomingAssignments.isNotEmpty) {
      mascotImage = 'assets/images/mascot_happy.png';
      statusTitle = 'Looking Good!';
      statusMessage = '${upcomingAssignments.length} upcoming. Stay ahead!';
    } else {
      mascotImage = 'assets/images/mascot_happy.png';
      statusTitle = 'Task Board';
      statusMessage = 'You\'re managing ${filtered.length} assignments.';
    }

    return MascotStatusCard(
      mascotImage: mascotImage,
      statusTitle: statusTitle,
      statusMessage: statusMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Assignment> filtered = _filteredAssignments();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    
    final List<Assignment> todayAssignments = filtered.where((a) => !a.isCompleted && _isSameDate(a.dueDate, today) && !a.dueDate.isBefore(now)).toList();
    final List<Assignment> overdueAssignments = filtered.where((a) => !a.isCompleted && a.dueDate.isBefore(now)).toList();
    final List<Assignment> upcomingAssignments = filtered.where((a) => !a.isCompleted && a.dueDate.isAfter(now) && !_isSameDate(a.dueDate, today)).toList();
    final List<Assignment> completedAssignments = filtered.where((a) => a.isCompleted).toList();

    final List<String> subjectOptions = <String>{'All', ...widget.subjects.map((s) => s.name), ...widget.assignments.map((a) => a.subject)}.toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAssignmentSheet,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Task'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: <Widget>[
          // Dynamic Mascot Status Card
          _buildMascotCard(filtered, todayAssignments, overdueAssignments, upcomingAssignments, completedAssignments),
          const SizedBox(height: 24),
          
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Subject: $_subjectFilter',
                  onTap: () async {
                    final String? selected = await _showFilterDialog('Select Subject', subjectOptions, _subjectFilter);
                    if (selected != null) setState(() => _subjectFilter = selected);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Priority: $_priorityFilter',
                  onTap: () async {
                    final String? selected = await _showFilterDialog('Select Priority', ['All', 'Low', 'Medium', 'High'], _priorityFilter);
                    if (selected != null) setState(() => _priorityFilter = selected);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          if (filtered.isEmpty)
            _EmptyTasksState(onAddPressed: _openAssignmentSheet)
          else ...[
            _AssignmentGroup(
              title: 'Today',
              subtitle: 'Deadlines due today',
              assignments: todayAssignments,
              onEdit: _openAssignmentSheet,
              onToggleStatus: widget.onToggleStatus,
              onDelete: widget.onDeleteAssignment,
            ),
            const SizedBox(height: 24),
            _AssignmentGroup(
              title: 'Upcoming',
              subtitle: 'Future deadlines',
              assignments: upcomingAssignments,
              onEdit: _openAssignmentSheet,
              onToggleStatus: widget.onToggleStatus,
              onDelete: widget.onDeleteAssignment,
            ),
            const SizedBox(height: 24),
            _AssignmentGroup(
              title: 'Overdue',
              subtitle: 'Missed deadlines',
              assignments: overdueAssignments,
              onEdit: _openAssignmentSheet,
              onToggleStatus: widget.onToggleStatus,
              onDelete: widget.onDeleteAssignment,
            ),
            const SizedBox(height: 24),
            _AssignmentGroup(
              title: 'Completed',
              subtitle: 'Finished work',
              assignments: completedAssignments,
              onEdit: _openAssignmentSheet,
              onToggleStatus: widget.onToggleStatus,
              onDelete: widget.onDeleteAssignment,
            ),
          ],
        ],
      ),
    );
  }

  Future<String?> _showFilterDialog(String title, List<String> items, String current) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items.map((item) => ListTile(
              title: Text(item),
              trailing: item == current ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () => Navigator.pop(context, item),
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _AssignmentGroup extends StatelessWidget {
  const _AssignmentGroup({
    required this.title,
    required this.subtitle,
    required this.assignments,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final List<Assignment> assignments;
  final ValueChanged<Assignment> onEdit;
  final Future<void> Function(Assignment assignment) onToggleStatus;
  final Future<void> Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        ...assignments.map((assignment) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AssignmentCard(
            assignment: assignment,
            onTap: () => onEdit(assignment),
            onToggleStatus: () => onToggleStatus(assignment),
            onDelete: () => onDelete(assignment.id!),
          ),
        )),
      ],
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState({required this.onAddPressed});
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Image.asset('assets/images/mascot_icandoit.png', height: 160),
          const SizedBox(height: 24),
          Text('Nothing to do!', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your task board is completely empty. Add an assignment to get started!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Add First Task'),
          ),
        ],
      ),
    );
  }
}


