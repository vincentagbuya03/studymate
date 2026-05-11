import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/grade.dart';
import '../models/subject.dart';
import '../widgets/editor_sheets.dart';
import '../widgets/mascot_status_card.dart';

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

  Widget _buildGradesMascotCard() {
    String mascotImage;
    String statusTitle;
    String statusMessage;

    final double avg = _weightedAverage;

    if (widget.grades.isEmpty) {
      mascotImage = 'assets/images/mascot_icandoit.png';
      statusTitle = 'No Records Yet';
      statusMessage = 'Log your first grade to track progress!';
    } else if (avg >= 90) {
      mascotImage = 'assets/images/celebrating.png';
      statusTitle = 'Outstanding!';
      statusMessage = 'You\'re averaging ${avg.toStringAsFixed(1)}%! Keep it up!';
    } else if (avg >= 80) {
      mascotImage = 'assets/images/mascot_happy.png';
      statusTitle = 'Great Work!';
      statusMessage = 'Solid ${avg.toStringAsFixed(1)}% average. You\'re doing well!';
    } else if (avg >= 75) {
      mascotImage = 'assets/images/mascot_passed.png';
      statusTitle = 'On Track!';
      statusMessage = '${avg.toStringAsFixed(1)}% average. A little push goes far!';
    } else if (avg > 0) {
      mascotImage = 'assets/images/mascot_sad.png';
      statusTitle = 'Keep Going!';
      statusMessage = '${avg.toStringAsFixed(1)}% needs attention. You can improve!';
    } else {
      mascotImage = 'assets/images/thinking.png';
      statusTitle = 'Just Started';
      statusMessage = 'Start adding grades to see your progress.';
    }

    return MascotStatusCard(
      mascotImage: mascotImage,
      statusTitle: statusTitle,
      statusMessage: statusMessage,
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
          _buildGradesMascotCard(),
          const SizedBox(height: 24),
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
