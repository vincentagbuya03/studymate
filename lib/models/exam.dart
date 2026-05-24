class Exam {
  final int? id;
  final String? remoteId;
  final String title;
  final String subject;
  final DateTime dateTime;
  final String room;
  final String notes;

  Exam({
    this.id,
    this.remoteId,
    required this.title,
    required this.subject,
    required this.dateTime,
    required this.room,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remoteId': remoteId,
      'title': title,
      'subject': subject,
      'dateTime': dateTime.toIso8601String(),
      'room': room,
      'notes': notes,
    };
  }

  factory Exam.fromMap(Map<String, dynamic> map) {
    return Exam(
      id: map['id'],
      remoteId: map['remoteId'],
      title: map['title'],
      subject: map['subject'],
      dateTime: DateTime.parse(map['dateTime']),
      room: map['room'],
      notes: map['notes'] ?? '',
    );
  }

  Exam copyWith({
    int? id,
    String? remoteId,
    String? title,
    String? subject,
    DateTime? dateTime,
    String? room,
    String? notes,
  }) {
    return Exam(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      dateTime: dateTime ?? this.dateTime,
      room: room ?? this.room,
      notes: notes ?? this.notes,
    );
  }
}
