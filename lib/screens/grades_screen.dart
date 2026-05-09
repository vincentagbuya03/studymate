import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/grade.dart';
import '../models/subject.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({
    super.key,
    required this.grades,
    required this.subjects,
    required this.onAddGrade,
    required this.onDeleteGrade,
  });

  final List<Grade> grades;
  final List<Subject> subjects;
  final Future<void> Function(Grade grade) onAddGrade;
  final Future<void> Function(int id) onDeleteGrade;

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  double get _weightedAverage {
    if (widget.grades.isEmpty) return 0;
    
    double totalWeightedPoints = 0;
    double totalUnits = 0;

    for (final grade in widget.grades) {
      // Find matching subject to get units
      final subject = widget.subjects.firstWhere(
        (s) => s.name.toLowerCase() == grade.subject.toLowerCase(),
        orElse: () => Subject(name: '', room: '', slots: [], colorValue: 0, units: 1.0),
      );
      
      totalWeightedPoints += (grade.percentage * subject.units);
      totalUnits += subject.units;
    }

    return totalUnits > 0 ? totalWeightedPoints / totalUnits : 0;
  }

  String get _gwaLabel {
    final avg = _weightedAverage;
    if (avg >= 97) return '1.00';
    if (avg >= 94) return '1.25';
    if (avg >= 91) return '1.50';
    if (avg >= 88) return '1.75';
    if (avg >= 85) return '2.00';
    if (avg >= 82) return '2.25';
    if (avg >= 79) return '2.50';
    if (avg >= 76) return '2.75';
    if (avg >= 75) return '3.00';
    return '5.00';
  }

  void _openGradeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GradeEditorSheet(
        subjects: widget.subjects,
        onSave: (grade) {
          Navigator.pop(context);
          widget.onAddGrade(grade);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Academic Performance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGradeSheet,
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Log Result'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _GpaCard(percentage: _weightedAverage, gwa: _gwaLabel),
          const SizedBox(height: 32),
          Text('Recent Grades', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          if (widget.grades.isEmpty)
            const _EmptyGradesState()
          else
            ...widget.grades.map((grade) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GradeItem(
                grade: grade,
                onDelete: () => widget.onDeleteGrade(grade.id!),
              ),
            )),
        ],
      ),
    );
  }
}

class _GpaCard extends StatelessWidget {
  const _GpaCard({required this.percentage, required this.gwa});
  final double percentage;
  final String gwa;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weighted Average',
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'GWA: $gwa',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${percentage.toStringAsFixed(2)}%',
            style: GoogleFonts.inter(fontSize: 54, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            percentage >= 75 ? 'Academic Excellence' : 'Keep Studying!',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GradeItem extends StatelessWidget {
  const _GradeItem({required this.grade, required this.onDelete});
  final Grade grade;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: (grade.percentage >= 75 ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${grade.percentage.toInt()}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: grade.percentage >= 75 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(grade.subject, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  Text(grade.category, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${grade.score}/${grade.maxScore}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: Text(
                    'Remove',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GradeEditorSheet extends StatefulWidget {
  const GradeEditorSheet({super.key, required this.subjects, required this.onSave});
  final List<Subject> subjects;
  final ValueChanged<Grade> onSave;

  @override
  State<GradeEditorSheet> createState() => _GradeEditorSheetState();
}

class _GradeEditorSheetState extends State<GradeEditorSheet> {
  late String _selectedSubject;
  final _scoreController = TextEditingController();
  final _maxController = TextEditingController();
  String _category = 'Exam';

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.subjects.isNotEmpty ? widget.subjects.first.name : 'General';
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Record Achievement', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            if (widget.subjects.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedSubject,
                items: widget.subjects.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => _selectedSubject = v!),
                decoration: const InputDecoration(labelText: 'Subject'),
              )
            else
              TextFormField(
                initialValue: _selectedSubject,
                onChanged: (v) => _selectedSubject = v,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _scoreController, decoration: const InputDecoration(labelText: 'Score'), keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: _maxController, decoration: const InputDecoration(labelText: 'Max Score'), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: ['Exam', 'Quiz', 'Assignment', 'Project', 'Participation'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () {
                if (_scoreController.text.isEmpty || _maxController.text.isEmpty) return;
                widget.onSave(Grade(
                  subject: _selectedSubject,
                  score: double.parse(_scoreController.text),
                  maxScore: double.parse(_maxController.text),
                  category: _category,
                  date: DateTime.now(),
                ));
              },
              child: const Text('Add to Records'),
            )),
          ],
        ),
      ),
    );
  }
}

class _EmptyGradesState extends StatelessWidget {
  const _EmptyGradesState();
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Text('No grades recorded yet. Start tracking your progress!', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey)),
    ));
  }
}
