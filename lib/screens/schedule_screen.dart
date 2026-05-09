import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/subject.dart';
import '../widgets/subject_card.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.subjects,
    required this.onAddSubject,
    required this.onUpdateSubject,
    required this.onDeleteSubject,
  });

  final List<Subject> subjects;
  final Future<void> Function(Subject subject) onAddSubject;
  final Future<void> Function(Subject subject) onUpdateSubject;
  final Future<void> Function(int id) onDeleteSubject;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Subject> _subjectsForDay(DateTime day) {
    final List<Subject> subjects =
        widget.subjects
            .where((Subject subject) => subject.occursOn(day))
            .toList()
          ..sort((Subject a, Subject b) {
            // Sort by the first slot matching this day
            final slotA = a.getSlotsForDay(day.weekday).first;
            final slotB = b.getSlotsForDay(day.weekday).first;
            return slotA.startTime.compareTo(slotB.startTime);
          });
    return subjects;
  }

  Future<void> _openSubjectSheet([Subject? subject]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SubjectEditorSheet(
          subject: subject,
          onSave: (Subject updated) async {
            Navigator.of(context).pop();
            if (subject == null) {
              await widget.onAddSubject(updated);
            } else {
              await widget.onUpdateSubject(updated);
            }
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Subject subject) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete subject?'),
          content: Text('Remove ${subject.name} from your weekly schedule?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && subject.id != null) {
      await widget.onDeleteSubject(subject.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Subject> selectedSubjects = _subjectsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(title: const Text('Class Schedule')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSubjectSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Subject'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: TableCalendar<Object?>(
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2035),
              focusedDay: _focusedDay,
              selectedDayPredicate: (DateTime day) =>
                  isSameDay(day, _selectedDay),
              calendarFormat: CalendarFormat.week,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              eventLoader: _subjectsForDay,
              onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Classes for ${_selectedDay.month}/${_selectedDay.day}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            selectedSubjects.isEmpty
                ? 'No classes scheduled on this day.'
                : '${selectedSubjects.length} class${selectedSubjects.length == 1 ? '' : 'es'} on this day',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 16),
          if (selectedSubjects.isEmpty)
            _EmptyScheduleCard(onAddPressed: _openSubjectSheet)
          else
            ...selectedSubjects.map(
              (Subject subject) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SubjectCard(
                  subject: subject,
                  displayDay: _selectedDay.weekday,
                  onTap: () => _openSubjectSheet(subject),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') {
                        _openSubjectSheet(subject);
                      } else {
                        _confirmDelete(subject);
                      }
                    },
                    itemBuilder: (BuildContext context) => const [
                      PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyScheduleCard extends StatelessWidget {
  const _EmptyScheduleCard({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.menu_book_rounded,
            size: 34,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Build your week',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your subjects, rooms, meeting days, and class hours here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Subject'),
          ),
        ],
      ),
    );
  }
}

class SubjectEditorSheet extends StatefulWidget {
  const SubjectEditorSheet({super.key, this.subject, required this.onSave});

  final Subject? subject;
  final ValueChanged<Subject> onSave;

  @override
  State<SubjectEditorSheet> createState() => _SubjectEditorSheetState();
}

class _SubjectEditorSheetState extends State<SubjectEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _unitsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<ScheduleSlot> _slots = <ScheduleSlot>[];
  late int _colorValue;

  static const List<Color> _colors = <Color>[
    Color(0xFF5B8DEF),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];

  @override
  void initState() {
    super.initState();
    final Subject? subject = widget.subject;
    _nameController.text = subject?.name ?? '';
    _roomController.text = subject?.room ?? '';
    _unitsController.text = (subject?.units ?? 3.0).toString();
    _notesController.text = subject?.notes ?? '';
    _slots.addAll(subject?.slots ?? []);
    _colorValue = subject?.colorValue ?? _colors.first.toARGB32();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _unitsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addSlot() async {
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Select Start Time',
    );
    if (start == null || !mounted) return;

    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 1, minute: start.minute),
      helpText: 'Select End Time',
    );
    if (end == null || !mounted) return;

    final int? day = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Day'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (index) {
            final d = index + 1;
            const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            return ListTile(
              title: Text(labels[index]),
              onTap: () => Navigator.pop(context, d),
            );
          }),
        ),
      ),
    );
    if (day == null) return;

    setState(() {
      _slots.add(ScheduleSlot(
        day: day,
        startTime: Subject.formatTimeOfDay(start),
        endTime: Subject.formatTimeOfDay(end),
      ));
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time slot.')),
      );
      return;
    }

    final Subject updated = Subject(
      id: widget.subject?.id,
      name: _nameController.text.trim(),
      room: _roomController.text.trim(),
      slots: _slots,
      colorValue: _colorValue,
      units: double.tryParse(_unitsController.text) ?? 3.0,
      notes: _notesController.text.trim(),
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

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
                  widget.subject == null ? 'Add Subject' : 'Edit Subject',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Subject name'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _roomController,
                  decoration: const InputDecoration(labelText: 'Room'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter room' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitsController,
                  decoration: const InputDecoration(labelText: 'Units / Credits (e.g. 3.0)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => (value == null || double.tryParse(value) == null) ? 'Enter valid units' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Subject Notes',
                    hintText: 'Professor info, entrance details, etc.',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Schedule Slots',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    TextButton.icon(
                      onPressed: _addSlot,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add Slot'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No slots added yet.', style: TextStyle(fontStyle: FontStyle.italic))),
                  ),
                ..._slots.asMap().entries.map((entry) {
                  final index = entry.key;
                  final slot = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(_colorValue).withValues(alpha: 0.2),
                        child: Text(slot.dayLabel[0], style: TextStyle(color: Color(_colorValue), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      title: Text('${slot.dayLabel}: ${slot.timeLabel}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () => setState(() => _slots.removeAt(index)),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 18),
                Text('Color tag', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: _colors.map((color) {
                    final bool isSelected = color.toARGB32() == _colorValue;
                    return GestureDetector(
                      onTap: () => setState(() => _colorValue = color.toARGB32()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: isSelected ? 42 : 36,
                        height: isSelected ? 42 : 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.subject == null ? 'Save Subject' : 'Update Subject'),
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
