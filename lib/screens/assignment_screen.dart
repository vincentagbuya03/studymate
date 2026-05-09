import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';
import '../models/subject.dart';
import '../widgets/assignment_card.dart';

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

  /// Filters assignments based on the currently selected subject and priority.
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

  /// Opens the add or edit assignment sheet.
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

  @override
  Widget build(BuildContext context) {
    final List<Assignment> filtered = _filteredAssignments();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<Assignment> todayAssignments = filtered
        .where(
          (Assignment assignment) =>
              !assignment.isCompleted &&
              _isSameDate(assignment.dueDate, today) &&
              !assignment.dueDate.isBefore(now),
        )
        .toList();
    final List<Assignment> overdueAssignments = filtered
        .where(
          (Assignment assignment) =>
              !assignment.isCompleted && assignment.dueDate.isBefore(now),
        )
        .toList();
    final List<Assignment> upcomingAssignments = filtered
        .where(
          (Assignment assignment) =>
              !assignment.isCompleted &&
              assignment.dueDate.isAfter(now) &&
              !_isSameDate(assignment.dueDate, today),
        )
        .toList();
    final List<Assignment> completedAssignments = filtered
        .where((Assignment assignment) => assignment.isCompleted)
        .toList();

    final List<String> subjectOptions = <String>{
      'All',
      ...widget.subjects.map((Subject subject) => subject.name),
      ...widget.assignments.map((Assignment assignment) => assignment.subject),
    }.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Assignments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAssignmentSheet,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Task'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _FilterDropdown(
                label: 'Subject',
                initialValue: _subjectFilter,
                items: subjectOptions,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _subjectFilter = value);
                  }
                },
              ),
              _FilterDropdown(
                label: 'Priority',
                initialValue: _priorityFilter,
                items: const <String>['All', 'Low', 'Medium', 'High'],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _priorityFilter = value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          _AssignmentGroup(
            title: 'Today',
            subtitle: 'Deadlines due today',
            assignments: todayAssignments,
            onEdit: _openAssignmentSheet,
            onToggleStatus: widget.onToggleStatus,
            onDelete: widget.onDeleteAssignment,
          ),
          const SizedBox(height: 18),
          _AssignmentGroup(
            title: 'Upcoming',
            subtitle: 'Future deadlines',
            assignments: upcomingAssignments,
            onEdit: _openAssignmentSheet,
            onToggleStatus: widget.onToggleStatus,
            onDelete: widget.onDeleteAssignment,
          ),
          const SizedBox(height: 18),
          _AssignmentGroup(
            title: 'Overdue',
            subtitle: 'Missed deadlines',
            assignments: overdueAssignments,
            onEdit: _openAssignmentSheet,
            onToggleStatus: widget.onToggleStatus,
            onDelete: widget.onDeleteAssignment,
          ),
          const SizedBox(height: 18),
          _AssignmentGroup(
            title: 'Completed',
            subtitle: 'Finished work',
            assignments: completedAssignments,
            onEdit: _openAssignmentSheet,
            onToggleStatus: widget.onToggleStatus,
            onDelete: widget.onDeleteAssignment,
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.initialValue,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String initialValue;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        initialValue: initialValue,
        decoration: InputDecoration(labelText: label),
        items: items
            .map(
              (String item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: onChanged,
      ),
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
        const SizedBox(height: 12),
        if (assignments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'No assignments in this section.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...assignments.map(
            (Assignment assignment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AssignmentCard(
                assignment: assignment,
                onTap: () => onEdit(assignment),
                onToggleStatus: () => onToggleStatus(assignment),
                onDelete: () => onDelete(assignment.id!),
              ),
            ),
          ),
      ],
    );
  }
}

class AssignmentEditorSheet extends StatefulWidget {
  const AssignmentEditorSheet({
    super.key,
    required this.subjects,
    required this.onSave,
    this.assignment,
  });

  final List<Subject> subjects;
  final ValueChanged<Assignment> onSave;
  final Assignment? assignment;

  @override
  State<AssignmentEditorSheet> createState() => _AssignmentEditorSheetState();
}

class _AssignmentEditorSheetState extends State<AssignmentEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  static const Duration _minimumLeadTime = Duration(minutes: 1);
  late DateTime _dueDate;
  AssignmentPriority _priority = AssignmentPriority.medium;

  @override
  void initState() {
    super.initState();
    final Assignment? assignment = widget.assignment;
    _titleController.text = assignment?.title ?? '';
    _subjectController.text = assignment?.subject ?? '';
    _dueDate =
        assignment?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    _priority = assignment?.priority ?? AssignmentPriority.medium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  /// Lets the user choose both due date and due time for a task.
  Future<void> _pickDueDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: _dueDate,
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _dueDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  /// Validates and returns the final assignment back to the parent screen.
  void _submit() {
    debugPrint('[AssignmentEditor] Attempting to save...');
    if (!_formKey.currentState!.validate()) {
      debugPrint('[AssignmentEditor] Validation failed.');
      return;
    }

    debugPrint(
      '[AssignmentEditor] Validation passed. Title: ${_titleController.text}',
    );

    final DateTime now = DateTime.now();
    if (!_dueDate.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Note: Reminder skipped because the due time has already passed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final Assignment assignment = Assignment(
      id: widget.assignment?.id,
      title: _titleController.text.trim(),
      subject: _subjectController.text.trim(),
      dueDate: _dueDate,
      priority: _priority,
      isCompleted: widget.assignment?.isCompleted ?? false,
      completedAt: widget.assignment?.completedAt,
    );
    widget.onSave(assignment);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final List<String> subjectSuggestions = <String>{
      ...widget.subjects.map((Subject subject) => subject.name),
      if (_subjectController.text.isNotEmpty) _subjectController.text,
    }.toList()..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.assignment == null
                      ? 'Add Assignment'
                      : 'Edit Assignment',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a title.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value:
                      widget.subjects.any(
                        (s) => s.name == _subjectController.text,
                      )
                      ? _subjectController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    prefixIcon: Icon(Icons.book_rounded),
                  ),
                  items: [
                    ...widget.subjects.map(
                      (s) =>
                          DropdownMenuItem(value: s.name, child: Text(s.name)),
                    ),
                    if (_subjectController.text.isNotEmpty &&
                        !widget.subjects.any(
                          (s) => s.name == _subjectController.text,
                        ))
                      DropdownMenuItem(
                        value: _subjectController.text,
                        child: Text(_subjectController.text),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _subjectController.text = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  onChanged: (value) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Subject Name',
                    helperText: 'Type a new subject or select from above',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Subject is required'
                      : null,
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: _pickDueDateTime,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Due: ${DateFormat('MMM d, yyyy - hh:mm a').format(_dueDate)}',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Priority',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<AssignmentPriority>(
                  segments: const <ButtonSegment<AssignmentPriority>>[
                    ButtonSegment<AssignmentPriority>(
                      value: AssignmentPriority.low,
                      label: Text('Low'),
                    ),
                    ButtonSegment<AssignmentPriority>(
                      value: AssignmentPriority.medium,
                      label: Text('Medium'),
                    ),
                    ButtonSegment<AssignmentPriority>(
                      value: AssignmentPriority.high,
                      label: Text('High'),
                    ),
                  ],
                  selected: <AssignmentPriority>{_priority},
                  onSelectionChanged: (Set<AssignmentPriority> selection) {
                    setState(() {
                      _priority = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      widget.assignment == null
                          ? 'Save Assignment'
                          : 'Update Assignment',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
