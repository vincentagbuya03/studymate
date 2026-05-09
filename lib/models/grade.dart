class Grade {
  final int? id;
  final String subject;
  final double score;
  final double maxScore;
  final String category; // e.g., "Exam", "Assignment", "Quiz"
  final DateTime date;

  Grade({
    this.id,
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.category,
    required this.date,
  });

  double get percentage => (score / maxScore) * 100;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'score': score,
      'maxScore': maxScore,
      'category': category,
      'date': date.toIso8601String(),
    };
  }

  factory Grade.fromMap(Map<String, dynamic> map) {
    return Grade(
      id: map['id'],
      subject: map['subject'],
      score: map['score'],
      maxScore: map['maxScore'],
      category: map['category'],
      date: DateTime.parse(map['date']),
    );
  }
}
