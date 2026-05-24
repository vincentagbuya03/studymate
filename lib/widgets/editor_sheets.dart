import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/subject.dart';
import '../models/assignment.dart';
import '../models/exam.dart';
import '../models/grade.dart';

DateTime _defaultFutureDateTime() {
  final DateTime now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  ).add(const Duration(minutes: 2));
}

class SubjectEditorSheet extends StatefulWidget {
  const SubjectEditorSheet({super.key, this.subject, required this.onSave});
  final Subject? subject;
  final Function(Subject) onSave;

  @override
  State<SubjectEditorSheet> createState() => _SubjectEditorSheetState();
}

class _SubjectEditorSheetState extends State<SubjectEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _roomController;
  late TextEditingController _unitsController;
  late TextEditingController _notesController;
  late List<ScheduleSlot> _slots;
  late int _colorValue;

  final List<Color> _colors = [
    const Color(0xFF3B7A57),
    const Color(0xFF2563EB),
    const Color(0xFFD97706),
    const Color(0xFFDC2626),
    const Color(0xFF7C3AED),
    const Color(0xFF059669),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subject?.name);
    _roomController = TextEditingController(text: widget.subject?.room);
    _unitsController = TextEditingController(
      text: widget.subject?.units.toString() ?? '3.0',
    );
    _notesController = TextEditingController(text: widget.subject?.notes);
    _slots = List.from(widget.subject?.slots ?? []);
    _colorValue = widget.subject?.colorValue ?? _colors.first.toARGB32();
  }

  void _addSlot() async {
    final List<int>? days = await showDialog<List<int>>(
      context: context,
      builder: (context) => const _DayPickerDialog(initialDays: []),
    );

    if (days != null && days.isNotEmpty) {
      if (!mounted) return;
      final TimeOfDay? start = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 8, minute: 0),
      );
      if (start == null) return;
      if (!mounted) return;
      final TimeOfDay? end = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: start.hour + 1, minute: start.minute),
      );
      if (end == null) return;

      setState(() {
        for (final day in days) {
          _slots.add(
            ScheduleSlot(
              day: day,
              startTime:
                  '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
              endTime:
                  '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
            ),
          );
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave(
      Subject(
        id: widget.subject?.id,
        name: _nameController.text.trim(),
        room: _roomController.text.trim(),
        units: double.tryParse(_unitsController.text) ?? 3.0,
        notes: _notesController.text.trim(),
        colorValue: _colorValue,
        slots: _slots,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Image.asset('assets/images/thinking.png', height: 80),
              const SizedBox(height: 12),
              Text(
                widget.subject == null ? 'New Subject' : 'Edit Subject',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  prefixIcon: Icon(Icons.book_rounded),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        prefixIcon: Icon(Icons.room_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitsController,
                      decoration: const InputDecoration(
                        labelText: 'Units',
                        prefixIcon: Icon(Icons.score_rounded),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Schedule Slots',
                action: TextButton.icon(
                  onPressed: _addSlot,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Slot'),
                ),
              ),
              const SizedBox(height: 8),
              if (_slots.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'No schedule slots added yet.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _slots.length,
                  itemBuilder: (context, index) {
                    final slot = _slots[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          slot.dayLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(slot.timeLabel),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: Colors.redAccent,
                          ),
                          onPressed: () =>
                              setState(() => _slots.removeAt(index)),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Choose Color'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colors
                    .map(
                      (c) => GestureDetector(
                        onTap: () => setState(() => _colorValue = c.toARGB32()),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: _colorValue == c.toARGB32()
                                ? Border.all(
                                    color: theme.colorScheme.onSurface,
                                    width: 3,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Subject',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssignmentEditorSheet extends StatefulWidget {
  const AssignmentEditorSheet({
    super.key,
    required this.subjects,
    this.assignment,
    required this.onSave,
  });
  final List<Subject> subjects;
  final Assignment? assignment;
  final Function(Assignment) onSave;

  @override
  State<AssignmentEditorSheet> createState() => _AssignmentEditorSheetState();
}

class _AssignmentEditorSheetState extends State<AssignmentEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late String _selectedSubject;
  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  late AssignmentPriority _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.assignment?.title);
    _selectedSubject =
        widget.assignment?.subject ??
        (widget.subjects.isNotEmpty ? widget.subjects.first.name : 'General');
    _dueDate = widget.assignment?.dueDate ?? _defaultFutureDateTime();
    _dueTime = TimeOfDay.fromDateTime(_dueDate);
    _priority = widget.assignment?.priority ?? AssignmentPriority.medium;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final finalDate = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );
    widget.onSave(
      Assignment(
        id: widget.assignment?.id,
        title: _titleController.text.trim(),
        subject: _selectedSubject,
        dueDate: finalDate,
        priority: _priority,
        isCompleted: widget.assignment?.isCompleted ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Image.asset('assets/images/thinking.png', height: 80),
              const SizedBox(height: 12),
              Text(
                widget.assignment == null ? 'New Task' : 'Edit Task',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  prefixIcon: Icon(Icons.assignment_rounded),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedSubject,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: Icon(Icons.book_rounded),
                ),
                items: ['General', ...widget.subjects.map((s) => s.name)]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSubject = v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text(
                        DateFormat('MMM d, yyyy').format(_dueDate),
                      ),
                      leading: const Icon(Icons.calendar_today_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Time'),
                      subtitle: Text(_dueTime.format(context)),
                      leading: const Icon(Icons.access_time_rounded),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _dueTime,
                        );
                        if (picked != null) setState(() => _dueTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Priority'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: AssignmentPriority.values
                    .map(
                      (p) => ChoiceChip(
                        label: Text(p.name.toUpperCase()),
                        selected: _priority == p,
                        onSelected: (s) => setState(() => _priority = p),
                        selectedColor: p == AssignmentPriority.low
                            ? Colors.green.withValues(alpha: 0.2)
                            : p == AssignmentPriority.medium
                            ? Colors.orange.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _priority == p
                              ? (p == AssignmentPriority.low
                                    ? Colors.green
                                    : p == AssignmentPriority.medium
                                    ? Colors.orange
                                    : Colors.red)
                              : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Task',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamEditorSheet extends StatefulWidget {
  const ExamEditorSheet({
    super.key,
    required this.subjects,
    this.exam,
    required this.onSave,
  });
  final List<Subject> subjects;
  final Exam? exam;
  final Function(Exam) onSave;

  @override
  State<ExamEditorSheet> createState() => _ExamEditorSheetState();
}

class _ExamEditorSheetState extends State<ExamEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _roomController;
  late TextEditingController _notesController;
  late String _selectedSubject;
  late DateTime _dateTime;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.exam?.title);
    _roomController = TextEditingController(text: widget.exam?.room);
    _notesController = TextEditingController(text: widget.exam?.notes);
    _selectedSubject =
        widget.exam?.subject ??
        (widget.subjects.isNotEmpty ? widget.subjects.first.name : 'General');
    _dateTime = widget.exam?.dateTime ?? _defaultFutureDateTime();
    _time = TimeOfDay.fromDateTime(_dateTime);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final finalDate = DateTime(
      _dateTime.year,
      _dateTime.month,
      _dateTime.day,
      _time.hour,
      _time.minute,
    );
    widget.onSave(
      Exam(
        id: widget.exam?.id,
        title: _titleController.text.trim(),
        subject: _selectedSubject,
        dateTime: finalDate,
        room: _roomController.text.trim(),
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Image.asset('assets/images/thinking.png', height: 80),
              const SizedBox(height: 12),
              Text(
                widget.exam == null ? 'New Exam' : 'Edit Exam',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Exam Title (e.g. Midterms)',
                  prefixIcon: Icon(Icons.history_edu_rounded),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedSubject,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: Icon(Icons.book_rounded),
                ),
                items: ['General', ...widget.subjects.map((s) => s.name)]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSubject = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Room / Venue',
                  prefixIcon: Icon(Icons.room_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Date'),
                      subtitle: Text(
                        DateFormat('MMM d, yyyy').format(_dateTime),
                      ),
                      leading: const Icon(Icons.calendar_today_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dateTime,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (picked != null) setState(() => _dateTime = picked);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Time'),
                      subtitle: Text(_time.format(context)),
                      leading: const Icon(Icons.access_time_rounded),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Exam',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GradeEditorSheet extends StatefulWidget {
  const GradeEditorSheet({
    super.key,
    required this.subjects,
    required this.onSave,
  });
  final List<Subject> subjects;
  final Function(Grade) onSave;

  @override
  State<GradeEditorSheet> createState() => _GradeEditorSheetState();
}

class _GradeEditorSheetState extends State<GradeEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _scoreController;
  late TextEditingController _maxScoreController;
  late String _selectedSubject;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _scoreController = TextEditingController();
    _maxScoreController = TextEditingController(text: '100');
    _selectedSubject = widget.subjects.isNotEmpty
        ? widget.subjects.first.name
        : 'General';
    _selectedCategory = 'Exam';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Image.asset('assets/images/mascot_happy.png', height: 80),
            const SizedBox(height: 12),
            Text(
              'Log Result',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              decoration: const InputDecoration(
                labelText: 'Subject',
                prefixIcon: Icon(Icons.book_rounded),
              ),
              items: [
                'General',
                ...widget.subjects.map((s) => s.name),
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedSubject = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: [
                'Exam',
                'Assignment',
                'Quiz',
                'Project',
                'Other',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _scoreController,
                    decoration: const InputDecoration(labelText: 'Score'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _maxScoreController,
                    decoration: const InputDecoration(labelText: 'Max Score'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  widget.onSave(
                    Grade(
                      subject: _selectedSubject,
                      score: double.tryParse(_scoreController.text) ?? 0,
                      maxScore:
                          double.tryParse(_maxScoreController.text) ?? 100,
                      category: _selectedCategory,
                      date: DateTime.now(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Save Grade',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        ?action,
      ],
    );
  }
}

class _DayPickerDialog extends StatefulWidget {
  const _DayPickerDialog({required this.initialDays});
  final List<int> initialDays;

  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late List<int> _selectedDays;
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _selectedDays = List.from(widget.initialDays);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Days'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(7, (index) {
          final int day = index + 1;
          final bool isSelected = _selectedDays.contains(day);
          return FilterChip(
            label: Text(_days[index]),
            selected: isSelected,
            onSelected: (selected) => setState(
              () =>
                  selected ? _selectedDays.add(day) : _selectedDays.remove(day),
            ),
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedDays),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
