import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/subject.dart';
import '../widgets/mascot_status_card.dart';
import '../widgets/subject_card.dart';
import '../widgets/editor_sheets.dart';

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
          title: Text(
            'Delete subject?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text('Remove ${subject.name} from your weekly schedule?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
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

  Widget _buildScheduleMascotCard(List<Subject> selectedSubjects) {
    String mascotImage;
    String statusTitle;
    String statusMessage;

    final int hour = DateTime.now().hour;
    final bool isWeekend =
        _selectedDay.weekday == DateTime.saturday ||
        _selectedDay.weekday == DateTime.sunday;

    if (selectedSubjects.isEmpty && isWeekend) {
      mascotImage = 'assets/images/sleeping.png';
      statusTitle = 'Weekend Mode!';
      statusMessage = 'No classes today. Enjoy your break!';
    } else if (selectedSubjects.isEmpty) {
      mascotImage = 'assets/images/mascot_happy.png';
      statusTitle = 'Free Day!';
      statusMessage = 'No classes scheduled. Time to study ahead!';
    } else if (selectedSubjects.length >= 5) {
      mascotImage = 'assets/images/mascout_tired.png';
      statusTitle = 'Packed Day!';
      statusMessage =
          '${selectedSubjects.length} classes! Stay strong, you got this.';
    } else if (selectedSubjects.length >= 3) {
      mascotImage = 'assets/images/mascot_busy.png';
      statusTitle = 'Busy Schedule!';
      statusMessage = '${selectedSubjects.length} classes lined up today.';
    } else if (hour >= 17) {
      mascotImage = 'assets/images/celebrating.png';
      statusTitle = 'Almost Done!';
      statusMessage = 'The day is winding down. Great effort!';
    } else {
      mascotImage = 'assets/images/mascot_happy.png';
      statusTitle = 'Ready to Learn!';
      statusMessage =
          '${selectedSubjects.length} class${selectedSubjects.length == 1 ? '' : 'es'} on your agenda.';
    }

    return MascotStatusCard(
      mascotImage: mascotImage,
      statusTitle: statusTitle,
      statusMessage: statusMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Subject> selectedSubjects = _subjectsForDay(_selectedDay);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSubjectSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Subject'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: <Widget>[
          // Professional Calendar Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TableCalendar<Object?>(
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2035),
              focusedDay: _focusedDay,
              selectedDayPredicate: (DateTime day) =>
                  isSameDay(day, _selectedDay),
              calendarFormat: CalendarFormat.week,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left_rounded,
                  color: theme.colorScheme.primary,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
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
          const SizedBox(height: 32),

          // Dynamic Mascot Status Card
          _buildScheduleMascotCard(selectedSubjects),
          const SizedBox(height: 20),

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
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.edit_rounded),
                                title: const Text('Edit Subject'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _openSubjectSheet(subject);
                                },
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                                title: const Text(
                                  'Delete Subject',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _confirmDelete(subject);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: <Widget>[
          Image.asset('assets/images/mascot_happy.png', height: 120),
          const SizedBox(height: 24),
          Text(
            'Nothing here yet!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your subjects and class hours to build your professional weekly schedule.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Build Schedule'),
          ),
        ],
      ),
    );
  }
}
