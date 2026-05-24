import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/exam.dart';
import '../models/subject.dart';
import '../widgets/mascot_status_card.dart';
import '../widgets/editor_sheets.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({
    super.key,
    required this.exams,
    required this.subjects,
    required this.onAddExam,
    required this.onUpdateExam,
    required this.onDeleteExam,
  });

  final List<Exam> exams;
  final List<Subject> subjects;
  final Future<void> Function(Exam exam) onAddExam;
  final Future<void> Function(Exam exam) onUpdateExam;
  final Future<void> Function(int id) onDeleteExam;

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  Future<void> _openExamSheet([Exam? exam]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ExamEditorSheet(
          subjects: widget.subjects,
          exam: exam,
          onSave: (Exam updated) async {
            if (!mounted) return;
            Navigator.of(context).pop();
            if (exam == null) {
              await widget.onAddExam(updated);
            } else {
              await widget.onUpdateExam(updated);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openExamSheet,
        icon: const Icon(Icons.history_edu_rounded),
        label: const Text('Add Exam'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: <Widget>[
          _buildExamMascotCard(),
          const SizedBox(height: 24),
          if (widget.exams.isEmpty)
            const _EmptyExamsState()
          else
            ...widget.exams.map(
              (exam) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExamCard(
                  exam: exam,
                  onTap: () => _openExamSheet(exam),
                  onDelete: () => widget.onDeleteExam(exam.id!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExamMascotCard() {
    final DateTime now = DateTime.now();
    final List<Exam> upcoming =
        widget.exams.where((e) => e.dateTime.isAfter(now)).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final List<Exam> past = widget.exams
        .where((e) => e.dateTime.isBefore(now))
        .toList();

    String mascotImage;
    String statusTitle;
    String statusMessage;

    if (widget.exams.isEmpty) {
      mascotImage = 'assets/images/mascot_passed.png';
      statusTitle = 'Clear Skies!';
      statusMessage = 'No exams on the horizon. Enjoy the calm!';
    } else if (upcoming.isNotEmpty) {
      final Exam next = upcoming.first;
      final Duration diff = next.dateTime.difference(now);
      if (diff.inHours < 24) {
        mascotImage = 'assets/images/mascot_busy.png';
        statusTitle = 'Exam Tomorrow!';
        statusMessage = '${next.title} is coming up very soon!';
      } else if (diff.inDays <= 3) {
        mascotImage = 'assets/images/thinking.png';
        statusTitle = 'Study Time!';
        statusMessage =
            '${next.title} in ${diff.inDays} day(s). Start reviewing!';
      } else {
        mascotImage = 'assets/images/mascot_happy.png';
        statusTitle = 'Well Planned!';
        statusMessage =
            '${upcoming.length} exam(s) upcoming. You\'re prepared!';
      }
    } else {
      mascotImage = 'assets/images/celebrating.png';
      statusTitle = 'All Exams Done!';
      statusMessage = 'You\'ve completed ${past.length} exam(s). Great job!';
    }

    return MascotStatusCard(
      mascotImage: mascotImage,
      statusTitle: statusTitle,
      statusMessage: statusMessage,
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.onTap,
    required this.onDelete,
  });

  final Exam exam;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(exam.dateTime);
    final timeStr = DateFormat('hh:mm a').format(exam.dateTime);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment_late_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exam.subject} • ${exam.room}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyExamsState extends StatelessWidget {
  const _EmptyExamsState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Image.asset('assets/images/mascot_passed.png', height: 160),
          const SizedBox(height: 24),
          Text(
            'Clear Skies Ahead',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'No upcoming exams found. Track your tests and finals here to stay ahead of the game!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
