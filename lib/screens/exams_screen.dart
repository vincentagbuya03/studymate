import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/exam.dart';
import '../models/subject.dart';

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
      appBar: AppBar(title: const Text('Exams & Tests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openExamSheet,
        icon: const Icon(Icons.history_edu_rounded),
        label: const Text('Add Exam'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        itemCount: widget.exams.isEmpty ? 1 : widget.exams.length,
        itemBuilder: (context, index) {
          if (widget.exams.isEmpty) {
            return const _EmptyExamsState();
          }
          final exam = widget.exams[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ExamCard(
              exam: exam,
              onTap: () => _openExamSheet(exam),
              onDelete: () => widget.onDeleteExam(exam.id!),
            ),
          );
        },
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onTap, required this.onDelete});

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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exam.subject} • ${exam.room}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamEditorSheet extends StatefulWidget {
  const ExamEditorSheet({super.key, required this.subjects, required this.onSave, this.exam});

  final List<Subject> subjects;
  final ValueChanged<Exam> onSave;
  final Exam? exam;

  @override
  State<ExamEditorSheet> createState() => _ExamEditorSheetState();
}

class _ExamEditorSheetState extends State<ExamEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _roomController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _dateTime;

  @override
  void initState() {
    super.initState();
    final exam = widget.exam;
    _titleController.text = exam?.title ?? '';
    _subjectController.text = exam?.subject ?? '';
    _roomController.text = exam?.room ?? '';
    _notesController.text = exam?.notes ?? '';
    _dateTime = exam?.dateTime ?? DateTime.now().add(const Duration(days: 7));
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: _dateTime,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _dateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave(Exam(
      id: widget.exam?.id,
      title: _titleController.text.trim(),
      subject: _subjectController.text.trim(),
      room: _roomController.text.trim(),
      notes: _notesController.text.trim(),
      dateTime: _dateTime,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.exam == null ? 'Schedule Exam' : 'Edit Exam', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Exam Title')),
              const SizedBox(height: 12),
              TextFormField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 12),
              TextFormField(controller: _roomController, decoration: const InputDecoration(labelText: 'Room/Location')),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date & Time', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormat('MMM d, yyyy • hh:mm a').format(_dateTime)),
                trailing: IconButton(icon: const Icon(Icons.calendar_month_rounded), onPressed: _pickDateTime),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _submit, child: const Text('Save Exam')),
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
          Icon(Icons.auto_stories_rounded, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text('No Exams Yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Stay ahead of your schedule by tracking your tests and finals.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
